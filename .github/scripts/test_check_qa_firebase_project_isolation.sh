#!/usr/bin/env bash
set -euo pipefail
root="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
script="$root/check_qa_firebase_project_isolation.sh"
pass_count=0

check() {
  local name="$1" expected="$2" target="$3" qa="$4" prod="$5" output status
  if output="$(QA_FIREBASE_TARGET="$target" QA_FIREBASE_PROJECT_ID="$qa" PRODUCTION_FIREBASE_PROJECT_ID="$prod" bash "$script" 2>&1)"; then
    status=0
  else
    status=$?
  fi
  if [[ "$expected" == success && "$status" -eq 0 ]] || [[ "$expected" == failure && "$status" -ne 0 ]]; then
    echo "PASS: $name"
    pass_count=$((pass_count + 1))
  else
    echo "FAIL: $name (exit $status)" >&2
    exit 1
  fi
}

check 'staging projects distinct' success staging 'sukun-staging-example' 'sukun-production-example'
check 'staging shared project blocked' failure staging 'sukun-production-example' 'sukun-production-example'
check 'staging missing Production ID blocked' failure staging 'sukun-staging-example' ''
check 'staging missing QA ID blocked' failure staging '' 'sukun-production-example'
check 'whitespace cannot bypass shared-project check' failure staging $'sukun-production-example\n' ' sukun-production-example '
check 'production target matching project' success production 'sukun-production-example' 'sukun-production-example'
check 'production target mismatched project blocked' failure production 'sukun-staging-example' 'sukun-production-example'
check 'production missing verified ID blocked' failure production 'sukun-production-example' ''
check 'unrecognized target blocked' failure local 'sukun-staging-example' 'sukun-production-example'
check 'missing target blocked' failure '' 'sukun-staging-example' 'sukun-production-example'

# Ensure the workflow guards ALL Firebase-configured QA builds, not only
# rich_notice_pilot=true. This check doesn't use secrets or build an APK.
workflow="$root/../workflows/qa-connected-android.yml"
if grep -Fq 'QA_FIREBASE_TARGET="$environment" bash ../.github/scripts/check_qa_firebase_project_isolation.sh' "$workflow"; then
  echo 'PASS: Android Firebase QA workflow invokes environment guard'
  pass_count=$((pass_count + 1))
else
  echo 'FAIL: Android Firebase QA workflow is missing the guard' >&2
  exit 1
fi

printf '%s isolation tests passed\n' "$pass_count"
