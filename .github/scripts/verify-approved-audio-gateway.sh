#!/usr/bin/env bash
set -euo pipefail
# Credential-free, read-only denial/CORS acceptance against the LIVE Production gateway.
# Never send JWT, service-role keys, patient metadata or publisher URLs.
endpoint="https://vydfafumxptanpkmtrpr.supabase.co/functions/v1/approved-audio-download?id=00000000-0000-0000-0000-000000000000"
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

# Run additional request rejections without JWT or any media transfer.
# These checks use a non-existent UUID: never fetch publisher media.
status="$(curl --silent --show-error --max-time 25 -D "$headers" -o "$body" -w '%{http_code}' \
  -X POST -H "Origin: $origin" "$endpoint")"
[[ "$status" == "405" ]] || { echo "FAIL: non-GET requests were not denied"; exit 1; }
echo "PASS: unsupported method rejected"

status="$(curl --silent --show-error --max-time 25 -D "$headers" -o "$body" -w '%{http_code}' \
  -H "Origin: $origin" -H 'Range: bytes=0-1' "$endpoint")"
[[ "$status" == "416" ]] || { echo "FAIL: request-controlled Range was not denied"; exit 1; }
echo "PASS: request-controlled Range rejected"

status="$(curl --silent --show-error --max-time 25 -D "$headers" -o "$body" -w '%{http_code}' \
  -H "Origin: $origin" \
  "https://vydfafumxptanpkmtrpr.supabase.co/functions/v1/approved-audio-download?id=not-an-approved-cms-id")"
[[ "$status" == "400" ]] || { echo "FAIL: malformed CMS ID was not denied"; exit 1; }
echo "PASS: malformed resource ID rejected"

status="$(curl --silent --show-error --max-time 25 -D "$headers" -o "$body" -w '%{http_code}' \
  -X OPTIONS -H 'Origin: https://malicious.example' \
  -H 'Access-Control-Request-Method: GET' "$endpoint")"
[[ "$status" == "403" ]] || { echo "FAIL: untrusted preflight origin was not denied"; exit 1; }
if grep -qi '^access-control-allow-origin:' "$headers"; then
  echo "FAIL: untrusted preflight origin received CORS allowance"; exit 1;
fi
echo "PASS: untrusted preflight denied without CORS"

status="$(curl --silent --show-error --max-time 25 -D "$headers" -o "$body" -w '%{http_code}' \
  -H "Origin: $origin" -H 'Authorization: Bearer invalid-test-token' "$endpoint")"
[[ "$status" == "401" ]] || { echo "FAIL: forged bearer token was not rejected"; exit 1; }
echo "PASS: forged bearer rejected by GoTrue"

