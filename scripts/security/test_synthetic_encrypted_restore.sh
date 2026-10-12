#!/usr/bin/env bash
# CI-only backup/restore exercise: entirely fake records in ephemeral Docker.
# No Supabase project URL, patient data, production connection, or real secrets.
set -Eeuo pipefail
umask 077
[[ -n "${CI:-}" && -n "${GITHUB_ACTIONS:-}" ]] ||
  { echo 'This exact rehearsal is CI-only; no live DB connections.' >&2; exit 1; }
command -v docker >/dev/null
command -v age >/dev/null
command -v age-keygen >/dev/null
command -v sha256sum >/dev/null

work="$(mktemp -d)"
name="sukun-synthetic-restore-${GITHUB_RUN_ID:-0}"
cleanup() { docker rm -f "$name" >/dev/null 2>&1 || :; rm -rf "$work"; }
trap cleanup EXIT HUP INT TERM
docker run --rm -d --name "$name" \
  -e POSTGRES_PASSWORD='synthetic-local-fixture-only' postgres:17-alpine >/dev/null
for n in $(seq 1 45); do
  if docker exec -u postgres "$name" pg_isready -U postgres >/dev/null 2>&1; then
    break
  fi
  sleep 2
done
docker exec -u postgres "$name" pg_isready -U postgres >/dev/null
docker exec -u postgres "$name" psql -v ON_ERROR_STOP=1 -U postgres \
  -c 'CREATE ROLE qa_reader NOLOGIN' >/dev/null
docker exec -u postgres "$name" createdb -U postgres sukun_fixture_source
docker exec -u postgres "$name" createdb -U postgres sukun_fixture_restored
docker exec -i -u postgres "$name" psql -v ON_ERROR_STOP=1 -U postgres \
  -d sukun_fixture_source >/dev/null <<'SQL'
CREATE SCHEMA auth;
CREATE SCHEMA private;
CREATE SCHEMA storage;
CREATE TABLE auth.synthetic_accounts(id text primary key, user_note text);
INSERT INTO auth.synthetic_accounts VALUES ('QA-USER-1', 'FAKE-NOT-REAL');
CREATE TABLE private.synthetic_log(id integer primary key, event_kind text);
INSERT INTO private.synthetic_log VALUES (1, 'synthetic-only');
CREATE TABLE storage.synthetic_objects(id text primary key, object_hint text);
INSERT INTO storage.synthetic_objects VALUES ('fake1','not-an-actual-file');
CREATE TABLE public.synthetic_tasks (
 id integer primary key, owner_code text not null, title text not null
);
INSERT INTO public.synthetic_tasks VALUES
 (1, 'qa_a', 'TEST_ONLY_ALPHA'),
 (2, 'qa_b', 'TEST_ONLY_BETA');
ALTER TABLE public.synthetic_tasks ENABLE ROW LEVEL SECURITY;
CREATE POLICY synthetic_tenant_guard ON public.synthetic_tasks
 FOR SELECT TO qa_reader
 USING (owner_code = current_setting('qa.owner_code', true));
GRANT USAGE ON SCHEMA public TO qa_reader;
GRANT SELECT ON public.synthetic_tasks TO qa_reader;
SQL

age-keygen -o "$work/identity" >/dev/null 2>&1
age-keygen -o "$work/wrong-identity" >/dev/null 2>&1
recipient="$(age-keygen -y "$work/identity")"
archive="$work/synthetic-only.pgcustom.age"
# The same encrypted streaming method and 4-schema scope as the operator script.
docker exec -u postgres "$name" pg_dump -U postgres -d sukun_fixture_source \
  --format=custom --no-owner \
  --schema=auth --schema=private --schema=public --schema=storage |
  age -r "$recipient" -o "$archive"
[[ -s "$archive" ]]
sha256sum "$archive" > "$archive.sha256"
( cd "$work" && sha256sum -c "$(basename "$archive.sha256")" ) >/dev/null
# Decrypting with an unrelated key must fail (no plaintext written).
if age -d -i "$work/wrong-identity" -o /dev/null "$archive" 2>/dev/null; then
  echo 'FAIL: wrong private key unexpectedly decrypted archive' >&2
  exit 1
fi
# Plaintext travels only across a pipe into a fresh, isolated local database.
age -d -i "$work/identity" "$archive" |
  docker exec -i -u postgres "$name" pg_restore -U postgres \
    -d sukun_fixture_restored --clean --if-exists --no-owner --single-transaction --exit-on-error

q() {
  docker exec -u postgres "$name" psql -U postgres -At \
    -d sukun_fixture_restored -c "$1" | tr -d '\r'
}
[[ "$(q "select count(*) from pg_namespace where nspname in ('auth','private','storage','public')")" == '4' ]]
[[ "$(q "select (select count(*) from public.synthetic_tasks)::text || ':' || (select count(*) from auth.synthetic_accounts)::text || ':' || (select count(*) from private.synthetic_log)::text || ':' || (select count(*) from storage.synthetic_objects)::text")" == '2:1:1:1' ]]
[[ "$(q "select relrowsecurity from pg_class where oid='public.synthetic_tasks'::regclass")" == 't' ]]
[[ "$(q "select has_table_privilege('qa_reader','public.synthetic_tasks','SELECT')")" == 't' ]]
[[ "$(q "set role qa_reader; set qa.owner_code='qa_a'; select count(*) from public.synthetic_tasks")" == '1' ]]
[[ "$(q "set role qa_reader; set qa.owner_code='qa_b'; select count(*) from public.synthetic_tasks")" == '1' ]]
[[ "$(q "set role qa_reader; set qa.owner_code='qa_c'; select count(*) from public.synthetic_tasks")" == '0' ]]
echo 'PASS: fake-data age encryption, checksum, wrong-key refusal, isolated pg_restore, four schemas, grants, RLS cross-user isolation.'
echo 'LIMITATION: this verifies an isolated synthetic fixture, NOT a production export or recoverability of managed Supabase services.'
