#!/usr/bin/env python3
"""HTTP smoke tests against ONLY the disposable GitHub Actions Supabase stack.

Do not run against production or a remotely hosted URL. Creates synthetic users
and validates the patient sign-in Edge Function + persistent Postgres limiter.
No external Python packages, patient data or committed credentials.
"""
import json
import secrets
import subprocess
import sys
import urllib.error
import urllib.parse
import urllib.request
import uuid


def stop(message):
    raise SystemExit("LOCAL STAGING FAILURE: " + message)


def local_status():
    raw = subprocess.check_output(
        ["supabase", "status", "-o", "json"], text=True, timeout=30
    )
    data = json.loads(raw)
    url = data.get("API_URL", "").rstrip("/")
    if url not in ("http://127.0.0.1:54321", "http://localhost:54321"):
        stop("Supabase API_URL is not the expected local-only endpoint")
    anon = data.get("ANON_KEY")
    service = data.get("SERVICE_ROLE_KEY")
    if not anon or not service:
        stop("local Supabase keys were not returned")
    return url, anon, service


def request_json(url, path, payload, key, ip=None):
    data = json.dumps(payload).encode("utf-8")
    headers = {
        "Content-Type": "application/json",
        "apikey": key,
        "Authorization": "Bearer " + key,
    }
    if ip:
        # Synthetic client IP for disposable LOCAL proxy only.
        # This does not establish production gateway header trust.
        headers["cf-connecting-ip"] = ip
    req = urllib.request.Request(
        url + path, data=data, headers=headers, method="POST"
    )
    try:
        with urllib.request.urlopen(req, timeout=20) as result:
            status = result.status
            raw = result.read(8192)
    except urllib.error.HTTPError as exc:
        status = exc.code
        raw = exc.read(8192)
    except urllib.error.URLError as exc:
        stop("local HTTP endpoint unavailable (" + type(exc).__name__ + ")")
    try:
        body = json.loads(raw)
    except (ValueError, UnicodeDecodeError):
        stop("non-JSON HTTP response (status " + str(status) + ")")
    return status, body


def expected(url, path, payload, key, ip, status, code=None):
    observed, body = request_json(url, path, payload, key, ip)
    if observed != status:
        stop(
            "expected HTTP " + str(status) + " but got " + str(observed)
            + " for " + (code or "success")
        )
    if code and body.get("code") != code:
        stop("unexpected error code for HTTP " + str(status))
    return body


def main():
    url, anon_key, service_key = local_status()
    # Local-only API - no secret or account identifiers are printed.
    suffix = uuid.uuid4().hex[:12]
    patient_code = "SL-QA-" + suffix.upper()
    password = "LocalQa-" + secrets.token_urlsafe(18)
    email = "patient-" + suffix + "@sukun-local.invalid"

    status, auth = request_json(
        url, "/auth/v1/admin/users",
        {"email": email, "password": password, "email_confirm": True},
        service_key,
    )
    if status not in (200, 201) or not auth.get("id"):
        stop("unable to seed synthetic Auth user")
    patient_user_id = auth["id"]

    status, patient = request_json(
        url, "/rest/v1/patients",
        {
            "user_id": patient_user_id,
            "patient_code": patient_code,
            "full_name": "Synthetic QA Patient",
            "created_by": patient_user_id,
        },
        service_key,
    )
    if status not in (200, 201):
        stop("unable to seed synthetic patient record")

    path = "/functions/v1/patient-sign-in"
    good = {"identifier": patient_code, "password": password}
    bad = {"identifier": patient_code, "password": "DifferentPassword123"}
    unknown = {"identifier": "SL-NOT-FOUND-" + suffix.upper(), "password": password}

    body = expected(url, path, good, anon_key, "192.0.2.11", 200)
    if not body.get("refresh_token") or not body.get("expires_at"):
        stop("synthetic successful login response is missing expected fields")
    print("PASS: synthetic patient sign-in returns HTTP 200")

    bad_response = expected(
        url, path, bad, anon_key, "192.0.2.12",
        401, "invalid_credentials"
    )
    unknown_response = expected(
        url, path, unknown, anon_key, "192.0.2.13",
        401, "invalid_credentials"
    )
    if bad_response != unknown_response:
        stop("credential error may reveal patient account existence")
    print("PASS: invalid password and unknown patient return identical HTTP 401")

    oversized = {
        "identifier": patient_code, "password": password,
        "padding": "x" * 5000,
    }
    expected(
        url, path, oversized, anon_key, "192.0.2.14",
        413, "request_too_large"
    )
    print("PASS: oversized login request returns HTTP 413")

    # Distinct identifier and synthetic IP isolate this test from other probes.
    rate_identity = {
        "identifier": "SL-RATE-" + suffix.upper(),
        "password": "SyntheticWrongPass123",
    }
    for _ in range(8):
        expected(
            url, path, rate_identity, anon_key, "198.51.100.25",
            401, "invalid_credentials"
        )
    expected(
        url, path, rate_identity, anon_key, "198.51.100.25",
        429, "too_many_attempts"
    )
    expected(
        url, path, rate_identity, anon_key, "198.51.100.26",
        429, "too_many_attempts"
    )
    print("PASS: ninth attempt is blocked by persistent identity limit (HTTP 429)")

    # 30 unique identifiers at one IP, then the 31st must be blocked.
    # No real account is accessed and no Supabase Auth password check occurs.
    for index in range(30):
        candidate = {
            "identifier": "SL-IP-QA-" + str(index) + suffix[:4].upper(),
            "password": "SyntheticWrongPass123",
        }
        expected(
            url, path, candidate, anon_key, "203.0.113.42",
            401, "invalid_credentials"
        )
    expected(
        url, path,
        {
            "identifier": "SL-IP-QA-STOP" + suffix[:4].upper(),
            "password": "SyntheticWrongPass123",
        },
        anon_key, "203.0.113.42", 429, "too_many_attempts"
    )
    print("PASS: 31st attempt from one synthetic IP returns HTTP 429")
    print("LOCAL STAGING HTTP GATE PASSED; production gateway trust NOT verified")


if __name__ == "__main__":
    main()
