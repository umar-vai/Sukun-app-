#!/usr/bin/env bash
# Rebuild a throwaway local database from the stub plus every migration.
# Usage: PGHOST=/var/tmp/pgsukun PGPORT=54329 PGUSER=postgres scripts/local_db/reset.sh [dbname]
set -euo pipefail
cd "$(dirname "$0")/../.."
DB="${1:-sk}"
psql -d postgres -qc "drop database if exists $DB" -c "create database $DB" 2>/dev/null
P="psql -d $DB -q -v ON_ERROR_STOP=1"
$P -f scripts/local_db/supabase_stub.sql
for f in supabase/migrations/*.sql; do $P -f "$f" >/dev/null 2>/tmp/reset_err.txt || { echo "FAIL $f"; head -5 /tmp/reset_err.txt; exit 1; }; done
echo "migrations applied to $DB"
