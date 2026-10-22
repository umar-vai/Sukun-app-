#!/usr/bin/env bash
set -euo pipefail
# Credential-free, read-only acceptance against SYNTHETIC staging gateway.
# Never send JWT, service-role keys, patient metadata or publisher URLs.
endpoint="https://qacklgqvxvjjzsimjoip.supabase.co/functions/v1/approved-audio-download?id=00000000-0000-0000-0000-000000000000"
origin="https://app.sukunlife.com"
headers="$(mktemp)"
body="$(mktemp)"
trap 'rm -f "$headers" "$body"' EXIT

status="$(curl --silent --show-error --max-time 25 -D "$headers" -o "$body" -w '%{http_code}' \
  -X OPTIONS -H "Origin: $origin" -H "Access-Control-Request-Method: GET" "$endpoint")"
[[ "$status" == "204" ]] || { echo "FAIL: expected CORS preflight 204"; exit 1; }
grep -qi "^access-control-allow-origin: $origin" "$headers" || {
  echo "FAIL: production Pages CORS header not supplied"; exit 1;
}
echo "PASS: exact approved Pages origin CORS preflight"

status="$(curl --silent --show-error --max-time 25 -D "$headers" -o "$body" -w '%{http_code}' \
  -H "Origin: $origin" "$endpoint")"
[[ "$status" == "401" ]] || { echo "FAIL: unauthenticated download was not blocked"; exit 1; }
echo "PASS: no member JWT gives 401 before upstream request"

status="$(curl --silent --show-error --max-time 25 -D "$headers" -o "$body" -w '%{http_code}' \
  -H 'Origin: https://malicious.example' "$endpoint")"
[[ "$status" == "403" ]] || { echo "FAIL: untrusted origin was not blocked"; exit 1; }
if grep -qi '^access-control-allow-origin:' "$headers"; then
  echo "FAIL: untrusted origin received a CORS allow header"; exit 1;
fi
echo "PASS: untrusted origins blocked without CORS permission"
