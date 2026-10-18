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
# Browser preflight must allow the real app subdomain. A successful
# server-to-server curl without Origin is not a substitute for Web CORS.
preflight_headers="$(mktemp)"
trap 'rm -f "$tmp" "$preflight_headers"' EXIT
preflight_status="$(curl --silent --show-error --max-time 25 \
  --output /dev/null --dump-header "$preflight_headers" \
  --request OPTIONS \
  --header 'Origin: https://app.sukunlife.com' \
  --header 'Access-Control-Request-Method: POST' \
  --header 'Access-Control-Request-Headers: authorization,apikey,content-type,x-client-info' \
  "$SUPABASE_URL/functions/v1/quran-content" \
  --write-out '%{http_code}')"
[[ "$preflight_status" == "204" ]] || {
  echo "FAIL: Quran API custom-domain preflight status $preflight_status"
  exit 1
}
grep -qi 
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
^access-control-allow-origin: https://app\\.sukunlife\\.com\\r?
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
 "$preflight_headers" || {
  echo "FAIL: Quran API does not authorize app.sukunlife.com browser origin"
  exit 1
}
echo "PASS: Quran and Ruqyah audio API browser preflight CORS"

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
