#!/usr/bin/env bash
set -euo pipefail

# Verify public Firebase Android client identifiers without printing their values.
# These are NOT a Firebase service-account JSON or a Supabase service-role key.
project="${PRODUCTION_FIREBASE_PROJECT_ID:-}"
sender="${PRODUCTION_FIREBASE_SENDER_ID:-}"
api_key="${PRODUCTION_FIREBASE_ANDROID_API_KEY:-}"
android_app_id="${PRODUCTION_FIREBASE_ANDROID_APP_ID:-}"

if [[ ! "$project" =~ ^[a-z0-9][a-z0-9-]{4,29}$ ]]; then
  echo '::error::Production Firebase project ID missing or malformed.' >&2
  exit 1
fi
if [[ ! "$sender" =~ ^[0-9]{6,}$ ]]; then
  echo '::error::Production Firebase sender ID missing or malformed.' >&2
  exit 1
fi
if [[ ! "$api_key" =~ ^[A-Za-z0-9_-]{25,}$ ]]; then
  echo '::error::Production Firebase Android API key missing or malformed.' >&2
  exit 1
fi
if [[ ! "$android_app_id" =~ ^1:[0-9]+:android:[a-fA-F0-9]+$ ]] ||
   [[ "$android_app_id" != "1:${sender}:android:"* ]]; then
  echo '::error::Production Firebase Android App ID does not match sender ID.' >&2
  exit 1
fi
echo 'Production Firebase Android client configuration is complete (identifiers withheld).'
echo 'Physical-device FCM and staging/production audience isolation remain separate release checks.'
