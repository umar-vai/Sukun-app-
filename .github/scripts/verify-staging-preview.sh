#!/usr/bin/env bash
# Anonymous Data API smoke gate for the role-aware public Flutter Web build.
# This is a release safeguard, not a substitute for authenticated cross-patient
# pgTAP/E2E tests. Never print an API key or a private response body.
set -euo pipefail

: "${SUPABASE_URL:?Supabase URL required}"
: "${SUPABASE_PUBLISHABLE_KEY:?public publishable key required}"
: "${APP_ENVIRONMENT:?environment required}"
case "$APP_ENVIRONMENT" in
  production)
    [[ "$SUPABASE_URL" == "https://vydfafumxptanpkmtrpr.supabase.co" ]] || {
      echo "Wrong approved Production Supabase project." >&2
      exit 1
    }
    ;;
  staging)
    [[ "$SUPABASE_URL" == https://*.supabase.co &&
       "$SUPABASE_URL" != "https://vydfafumxptanpkmtrpr.supabase.co" ]] || {
      echo "Staging must use an isolated Supabase project." >&2
      exit 1
    }
    ;;
  *)
    echo "Real backend isolation gate requires staging or production." >&2
    exit 1
    ;;
esac
[[ "$SUPABASE_PUBLISHABLE_KEY" == sb_publishable_* ]] || {
  echo "Only a public Supabase publishable key may be bundled." >&2
  exit 1
}

tmp="$(mktemp)"
trap 'rm -f "$tmp"' EXIT

get_public_status() {
  local table="$1"
  local column="${2:-id}"
  curl --silent --show-error --max-time 20 \
    --header "apikey: $SUPABASE_PUBLISHABLE_KEY" \
    --header 'Accept: application/json' \
    --output "$tmp" \
    --write-out '%{http_code}' \
    "$SUPABASE_URL/rest/v1/$table?select=$column&limit=1"
}

# The public Resources API should be reachable with a browser publishable key.
code="$(get_public_status content_items)"
if [[ "$code" != "200" ]] || ! jq -e 'type == "array"' "$tmp" >/dev/null; then
  echo "Public resources API unavailable (HTTP $code)." >&2
  exit 1
fi
echo "PASS: public resources API available."

# An anonymous preview must not return clinical, role or notification rows.
# Explicit HTTP 401/403 is also a valid fail-closed state for private tables.
for spec in patients:id prescriptions:id care_plans:id profiles:id user_roles:user_id notification_events:id; do
  IFS=: read -r table column <<< "$spec"
  code="$(get_public_status "$table" "$column")"
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
      echo "Privacy gate returned unexpected HTTP $code for $table." >&2
      exit 1
      ;;
  esac
  echo "PASS: $table anonymous access is empty or denied."
done

# A visible Google sign-in button must never ship against a disabled provider.
# GoTrue exposes provider readiness through public /auth/v1/settings.
if [[ "${ENABLE_GOOGLE_OAUTH:-false}" == "true" ]]; then
  google_code="$(curl --silent --show-error --max-time 20 \
    --header "apikey: $SUPABASE_PUBLISHABLE_KEY" \
    --header 'Accept: application/json' \
    --output "$tmp" --write-out '%{http_code}' \
    "$SUPABASE_URL/auth/v1/settings")"
  if [[ "$google_code" != "200" ]] ||
     ! jq -e '.external.google == true' "$tmp" >/dev/null; then
    echo "Google OAuth provider is disabled on this Supabase project." >&2
    exit 1
  fi
  echo "PASS: Google OAuth provider is enabled."
fi

echo "Anonymous privacy gate passed. Run authenticated RLS/E2E separately."
