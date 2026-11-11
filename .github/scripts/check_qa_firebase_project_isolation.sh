#!/usr/bin/env bash
set -euo pipefail

# Fail closed for all Firebase-configured Android QA builds, not only the
# rich-notice pilot. Firebase topics are scoped by Firebase project, not
# by the Supabase backend URL.
# Project IDs are public identifiers; never print tokens or credentials.
qa_project="$(printf '%s' "${QA_FIREBASE_PROJECT_ID:-}" | tr -d '[:space:]')"
prod_project="$(printf '%s' "${PRODUCTION_FIREBASE_PROJECT_ID:-}" | tr -d '[:space:]')"
target="${QA_FIREBASE_TARGET:-}"

if [[ -z "$qa_project" ]]; then
  echo '::error::QA Firebase project ID is missing; Firebase QA build blocked.' >&2
  exit 1
fi
if [[ -z "$prod_project" ]]; then
  echo '::error::Set verified SUKUN_PRODUCTION_FIREBASE_PROJECT_ID Actions variable; Firebase QA build blocked.' >&2
  exit 1
fi

case "$target" in
  staging)
    if [[ "$qa_project" == "$prod_project" ]]; then
      echo '::error::Staging Firebase project matches Production. A shared FCM topic would cross the audience boundary; QA build blocked.' >&2
      exit 1
    fi
    echo 'Staging and Production Firebase project IDs differ; independently verify the Staging Edge service account before topic broadcast.'
    ;;
  production)
    if [[ "$qa_project" != "$prod_project" ]]; then
      echo '::error::Production-targeted Android QA Firebase project differs from verified Production project; QA build blocked.' >&2
      exit 1
    fi
    echo 'Production QA Firebase project matches verified Production project; explicit native QA permission and topic release gates still apply.'
    ;;
  *)
    echo '::error::Unrecognized Firebase QA target. Expected staging or production; QA build blocked.' >&2
    exit 1
    ;;
esac
