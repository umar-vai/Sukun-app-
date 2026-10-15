#!/usr/bin/env bash
# Verify REAL Production Quran reader after a CI-successful main commit.
# Remote Quran content is public. Never log private keys, patients or raw API.
set -euo pipefail
: "${SUPABASE_URL:?Production Supabase URL is required}"
: "${SUPABASE_PUBLISHABLE_KEY:?Browser publishable key required}"
[[ "$APP_ENVIRONMENT" == production ]] || exit 1
[[ "$SUPABASE_URL" == "https://vydfafumxptanpkmtrpr.supabase.co" ]] || exit 1
[[ "$SUPABASE_PUBLISHABLE_KEY" == sb_publishable_* ]] || exit 1
tmp="$(mktemp)"
trap 'rm -f "$tmp"' EXIT
call_quran() {
  local body="$1"
  curl --fail-with-body --silent --show-error --retry 2 --retry-delay 2 \
    --max-time 45 \
    --header "apikey: $SUPABASE_PUBLISHABLE_KEY" \
    --header 'Content-Type: application/json' \
    --data "$body" "$SUPABASE_URL/functions/v1/quran-content" > "$tmp"
}
call_quran '{"action":"chapters"}'
jq -e '.provider == "Al Quran Cloud" and
       (.chapters | length) == 114 and
       .chapters[0].id == 1 and
       .chapters[113].id == 114' "$tmp" > /dev/null
echo "PASS: 114 surahs and attributed provider"
sleep 2
call_quran '{"action":"verses","chapter":1,"page":1}'
jq -e '(.verses | length) == 7 and
       .verses[0].verse_key == "1:1" and
       .verses[6].verse_key == "1:7" and
       .verses[0].text_uthmani != "" and
       .verses[0].translations[0].text != "" and
       (.verses[0].audio.url | startswith("https://"))' "$tmp" > /dev/null
echo "PASS: Al-Fatihah Arabic, Bengali and recitation"
sleep 2
call_quran '{"action":"verses","chapter":114,"page":1}'
jq -e '(.verses | length) == 6 and
       .verses[0].verse_key == "114:1" and
       .verses[5].verse_key == "114:6" and
       .verses[0].translations[0].text != ""' "$tmp" > /dev/null
echo "PASS: An-Nas six verses"
