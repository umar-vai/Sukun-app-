#!/usr/bin/env bash
# Run SQL tests (pgTAP syntax) against the local DB using the shim.
# Usage: scripts/local_db/run_tests.sh [dbname] [test files...]
set -uo pipefail
cd "$(dirname "$0")/../.."
DB="${1:-sk}"; shift || true
FILES=("$@"); [ ${#FILES[@]} -eq 0 ] && FILES=(supabase/tests/*.sql)
psql -d "$DB" -q -f scripts/local_db/pgtap_shim.sql >/dev/null 2>&1
fail=0
for f in "${FILES[@]}"; do
  # Tests do `create extension pgtap` and finish with rollback; drop that line.
  out=$(sed '/create extension if not exists pgtap/d' "$f" | PGOPTIONS="-c search_path=public,extensions" psql -d "$DB" -v ON_ERROR_STOP=1 -X 2>&1)
  if echo "$out" | grep -q "^not ok\|ERROR\|TAP FAILED"; then echo "FAIL $f"; echo "$out" | grep -E "^not ok|ERROR|TAP FAILED|got|want" | head -8; fail=1; else echo "pass $f ($(echo "$out" | grep -c '^ok') checks)"; fi
done
exit $fail
