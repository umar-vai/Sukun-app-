#!/usr/bin/env bash
set -euo pipefail

# Fail closed for the opt-in rich-notice Android staging pilot. Firebase topics
# are isolated by Firebase project, NOT by the configured Supabase project.
# Project IDs are public identifiers; never emit credentials or FCM tokens.
qa_project="$(printf '%s' "${QA_FIREBASE_PROJECT_ID:-}" | tr -d '[:space:]')"
prod_project="$(printf '%s' "${PRODUCTION_FIREBASE_PROJECT_ID:-}" | tr -d '[:space:]')"

if [[ -z "$qa_project" ]]; then
  echo '::error::Staging Firebase project ID is missing; do not build a rich-notice QA APK.' >&2
  exit 1
fi
if [[ -z "$prod_project" ]]; then
  echo '::error::Set SUKUN_PRODUCTION_FIREBASE_PROJECT_ID GitHub Actions variable after independent Firebase Console verification. Rich-notice APK build blocked.' >&2
  exit 1
fi
if [[ "$qa_project" == "$prod_project" ]]; then
  echo '::error::Staging and Production Firebase project IDs match. Shared FCM topic would cross the audience boundary; rich-notice APK build blocked.' >&2
  exit 1
fi

echo 'Staging and Production Firebase project IDs are distinct; verify the staging Edge sender service account independently before allowing topic delivery.'
