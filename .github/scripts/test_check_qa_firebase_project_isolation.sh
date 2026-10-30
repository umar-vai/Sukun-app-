#!/usr/bin/env bash
set -euo pipefail
root="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
script="$root/check_qa_firebase_project_isolation.sh"
pass_count=0
check() {
  local name="$1" expected="$2" qa="$3" prod="$4" output status
  if output="$(QA_FIREBASE_PROJECT_ID="$qa" PRODUCTION_FIREBASE_PROJECT_ID="$prod" bash "$script" 2>&1)"; then
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
  if [[ "$output" == *"real-fcm-device-token"* ]]; then
    echo 'FAIL: diagnostic exposed a token' >&2
    exit 1
  fi
}
check 'distinct projects' success 'sukun-staging-example' 'sukun-production-example'
check 'same project blocked' failure 'sukun-production-example' 'sukun-production-example'
check 'missing production ID blocked' failure 'sukun-staging-example' ''
check 'missing QA ID blocked' failure '' 'sukun-production-example'
check 'pasted whitespace normalized' failure $'sukun-production-example\n' ' sukun-production-example '
printf '%s isolation tests passed\n' "$pass_count"
