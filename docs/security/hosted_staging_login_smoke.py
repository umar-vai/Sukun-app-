#!/usr/bin/env python3
"""Read-only credential tests for the EXISTING Sukun staging Edge Function.

Makes only three HTTP requests with unique, invented patient identifiers.
This never reads, provisions, or changes Patient records. The staging
rate-limit counter increments for synthetically invalid login requests.
Use only with an explicitly public browser publishable key. Refuse all
other Supabase projects, including production.
"""
import json
import os
import sys
import uuid
import urllib.error
import urllib.request

STAGING_REF = "qacklgqvxvjjzsimjoip"
STAGING_URL = (
    "https://" + STAGING_REF + ".supabase.co/functions/v1/patient-sign-in"
)


def call(payload, key, fake_proxy_ip=None):
    headers = {
        "apikey": key,
        "Content-Type": "application/json",
    }
    if fake_proxy_ip:
        # Deliberate client-forged header on the verified staging project only.
        # A 401 alone does NOT prove the hosted proxy sanitized this header.
        headers["cf-connecting-ip"] = fake_proxy_ip
    request = urllib.request.Request(
        STAGING_URL,
        data=json.dumps(payload).encode("utf-8"),
        headers=headers,
        method="POST",
    )
    try:
        with urllib.request.urlopen(request, timeout=25) as response:
            code, raw = response.status, response.read(4096)
    except urllib.error.HTTPError as exc:
        code, raw = exc.code, exc.read(4096)
    except urllib.error.URLError as exc:
        raise RuntimeError("Hosted staging endpoint unreachable") from exc
    try:
        body = json.loads(raw)
    except (ValueError, UnicodeDecodeError) as exc:
        raise RuntimeError("Staging returned non-JSON response") from exc
    return code, body


def require(actual, expected_status, expected_code, name):
    code, body = actual
    if code != expected_status or body.get("code") != expected_code:
        reason = body.get("code") or body.get("error_code") or "no_code"
        # No identifiers, credentials, API key or response body are printed.
        raise RuntimeError(
            name + ": unexpected HTTP " + str(code) + " (" +
            str(reason)[:60] + ")"
        )
    print("PASS staging " + name + ": HTTP " + str(code))


def main():
    key = os.getenv("SUKUN_STAGING_PUBLIC_KEY", "")
    if not key.startswith("sb_publishable_") or len(key) > 200:
        raise RuntimeError("Staging publishable key missing or invalid")
    if os.getenv("SUKUN_TARGET_PROJECT_REF") != STAGING_REF:
        raise RuntimeError("Refusing unknown staging project; production prohibited")
    nonce = uuid.uuid4().hex[:10].upper()
    fake_login = {
        "identifier": "QA-NOT-REAL-" + nonce,
        "password": "Wrong-Synthetic-Password",
    }
    require(
        call({**fake_login, "pad": "X" * 5000}, key),
        413, "request_too_large", "oversized-body",
    )
    require(
        call(fake_login, key),
        401, "invalid_credentials", "unknown-identity",
    )
    require(
        call(
            {"identifier": "QA-NOT-REAL2-" + nonce, "password": "Wrong-Synthetic-Password"},
            key,
            fake_proxy_ip="203.0.113.44",
        ),
        401, "invalid_credentials", "forged-header-handling",
    )
    print("Hosted staging response gate passed; IP sanitization requires")
    print("independent gateway/bucket evidence before production approval")


if __name__ == "__main__":
    try:
        main()
    except Exception as error:
        sys.stderr.write("STAGING GATE FAILED: " + str(error) + "\n")
        sys.exit(1)
