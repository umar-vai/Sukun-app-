#!/usr/bin/env python3
"""Low-volume, no-credential staging-only pre-auth sign-in release gate.

No production calls, no real identifiers, no passwords/tokens in logs.
A 401 on a fresh nonexistent synthetic Patient ID proves the handler can run;
it does not prove a real patient's success path or end-to-end browser auth.
"""
import json
import os
import sys
import urllib.error
import urllib.request
import uuid

STAGING_REF = "qacklgqvxvjjzsimjoip"
URL = f"https://{STAGING_REF}.supabase.co/functions/v1/patient-sign-in"
KEY = os.environ.get("STAGING_PUBLISHABLE_KEY", "").strip()
if not KEY.startswith("sb_publishable_"):
    sys.exit("BLOCKED: staging publishable key missing or wrong type")

HEADERS = {
    "apikey": KEY,
    "Content-Type": "application/json",
    "User-Agent": "Sukun-Staging-Signin-Synthetic-Security-Gate/1.0",
}

def probe(label: str, method: str, data=None, headers=None):
    request = urllib.request.Request(
        URL,
        data=data,
        method=method,
        headers={**HEADERS, **(headers or {})},
    )
    try:
        with urllib.request.urlopen(request, timeout=25) as response:
            status = response.status
            payload = response.read(4096)
    except urllib.error.HTTPError as error:
        status = error.code
        payload = error.read(4096)
    except Exception as error:
        sys.exit(f"BLOCKED: {label} network failure: {type(error).__name__}")
    try:
        code = json.loads(payload).get("code")
    except (ValueError, AttributeError):
        code = None
    print(f"{label}: HTTP {status} / {code or 'no-json-code'}")
    return status, code

def expect(label, status, code, method, data=None, headers=None):
    actual = probe(label, method, data, headers)
    if actual != (status, code):
        sys.exit(f"BLOCKED: {label} returned {actual}; wanted {(status, code)}")

synthetic_id = "QA-" + uuid.uuid4().hex[:16].upper()
body = json.dumps({
    "identifier": synthetic_id,
    "password": "synthetic-never-a-patient-pass",
}).encode()

expect("GET blocked", 405, "method_not_allowed", "GET")
expect("Invalid body", 400, "invalid_input", "POST", b'{}')
expect(
    "Oversize body",
    413,
    "request_too_large",
    "POST",
    json.dumps({"identifier": synthetic_id, "password": "X" * 4100}).encode(),
)
expect("Synthetic invalid credentials", 401, "invalid_credentials", "POST", body)

# This is the key trusted-ingress negative test: if a caller can inject
# cf-connecting-ip, the handler rejects it with 503 instead of processing
# credentials. A 401 is required to show upstream sanitizes/overwrites the
# forged value. A 503 is an unsafe-or-unavailable ingress, not a success.
expect(
    "Forged invalid CF IP must be overwritten",
    401,
    "invalid_credentials",
    "POST",
    body,
    {"cf-connecting-ip": "forged-not-an-ip"},
)
expect(
    "Untrusted X-Forwarded-For must not affect login",
    401,
    "invalid_credentials",
    "POST",
    body,
    {"x-forwarded-for": "forged-not-an-ip"},
)
print("PASS: limited staging-only pre-auth and ingress HTTP gate")
