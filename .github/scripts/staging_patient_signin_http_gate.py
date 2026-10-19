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
# The gateway may reject a forged malformed header outright (403) or
# replace it with its own trusted value (401 from the application). In either
# case the malformed caller value must never arrive at trustedClientIp.
label = "Forged malformed CF IP rejected or overwritten"
status, code = probe(
    label, "POST", body, {"cf-connecting-ip": "forged-not-an-ip"}
)
if not ((status, code) == (401, "invalid_credentials") or status == 403):
    sys.exit(f"BLOCKED: {label} returned HTTP {status}/{code}")

# Valid syntax is a stronger attacker test: a 401 could mean the gateway
# silently FORWARDED the forged address, so require an explicit 403 reject.
# If this fails, stop the production rollout pending definitive proxy proof.
expect(
    "Forged syntactically valid CF IP must be rejected",
    403,
    None,
    "POST",
    body,
    {"cf-connecting-ip": "203.0.113.77"},
)
expect(
    "Untrusted X-Forwarded-For must not affect login",
    401,
    "invalid_credentials",
    "POST",
    body,
    {"x-forwarded-for": "forged-not-an-ip"},
)
# Limit-test ONE new synthetic identifier in isolated staging only. The
# earlier ordinary and XFF probes each consumed one failed attempt; the
# malformed/valid CF-header probes were blocked or overwritten by the gateway.
# To avoid relying on exact proxy policy, use a fresh ID for the threshold test.
# Never do this against production or with any existing Patient account.
limit_id = "QA-LIMIT-" + uuid.uuid4().hex[:12].upper()
limit_body = json.dumps({
    "identifier": limit_id,
    "password": "synthetic-never-a-patient-pass",
}).encode()
for attempt in range(1, 9):
    expect(
        f"Separate synthetic identity attempt {attempt}/8",
        401,
        "invalid_credentials",
        "POST",
        limit_body,
    )
expect(
    "Separate synthetic identity ninth attempt blocked",
    429,
    "too_many_attempts",
    "POST",
    limit_body,
)
print("PASS: staging-only pre-auth, ingress, and 429 HTTP gates")
