#!/usr/bin/env bash
# Anonymous Data API smoke gate for the isolated, public Flutter Web staging build.
# This is a release safeguard, not a substitute for authenticated cross-patient
# pgTAP/E2E tests. Never print an API key or a private response body.
set -euo pipefail

: "${SUPABASE_URL:?staging URL required}"
: "${SUPABASE_PUBLISHABLE_KEY:?public staging publishable key required}"
: "${APP_ENVIRONMENT:?environment required}"
[[ "$APP_ENVIRONMENT" == "staging" ]] || {
  echo "This check only runs against an isolated staging environment." >&2
  exit 1
}
[[ "$SUPABASE_URL" == https://*.supabase.co ]] || {
  echo "Invalid staging Supabase host." >&2
  exit 1
}
[[ "$SUPABASE_URL" != "https://vydfafumxptanpkmtrpr.supabase.co" ]] || {
  echo "Production Supabase is forbidden for Pages QA." >&2
  exit 1
}
[[ "$SUPABASE_PUBLISHABLE_KEY" == sb_publishable_* ]] || {
  echo "Only the public staging publishable key may be used." >&2
  exit 1
}

tmp="$(mktemp)"
trap 'rm -f "$tmp"' EXIT

get_public_status() {
  local table="$1"
  curl --silent --show-error --max-time 20 \
    --header "apikey: $SUPABASE_PUBLISHABLE_KEY" \
    --header 'Accept: application/json' \
    --output "$tmp" \
    --write-out '%{http_code}' \
    "$SUPABASE_URL/rest/v1/$table?select=id&limit=1"
}

# The public Resources API should be reachable with a browser publishable key.
code="$(get_public_status content_items)"
if [[ "$code" != "200" ]] || ! jq -e 'type == "array"' "$tmp" >/dev/null; then
  echo "Staging public resources API is not available (HTTP $code)." >&2
  exit 1
fi
echo "PASS: public resources API available."

# An anonymous preview must not return clinical, role or notification rows.
# Explicit HTTP 401/403 is also a valid fail-closed state for private tables.
for table in patients prescriptions care_plans profiles user_roles notification_events; do
  code="$(get_public_status "$table")"
  case "$code" in
    200)
      if ! jq -e 'type == "array" and length == 0' "$tmp" >/dev/null; then
        echo "SECURITY BLOCK: anonymous preview can read $table." >&2
        exit 1
      fi
      ;;
    401|403)
      ;;
    *)
      echo "Staging privacy gate returned unexpected HTTP $code for $table." >&2
      exit 1
      ;;
  esac
  echo "PASS: $table anonymous access is empty or denied."
done

echo "Anonymous staging smoke gate passed. Run authenticated RLS/E2E tests separately."
