#!/usr/bin/env bash
# Operator-controlled READ-ONLY production backup. Never run in CI.
# Needs pg_dump 17, age, private .pgpass file and trusted TLS CA.
set -Eeuo pipefail
umask 077

fail() { printf 'BACKUP STOPPED: %s\n' "$*" >&2; exit 1; }
ref='vydfafumxptanpkmtrpr'
[[ "${SUKUN_LOCAL_BACKUP_APPROVED:-}" == "YES_READ_ONLY_BACKUP" ]] ||
  fail 'Set explicit SUKUN_LOCAL_BACKUP_APPROVED=YES_READ_ONLY_BACKUP.'
[[ -z "${CI:-}" && -z "${GITHUB_ACTIONS:-}" ]] ||
  fail 'Refusing production backup inside CI.'
[[ -z "${PGPASSWORD:-}" && -z "${DATABASE_URL:-}" ]] ||
  fail 'Never use inline connection strings/passwords; provide PGPASSFILE.'
[[ "${PGDATABASE:-}" == 'postgres' && "${PGPORT:-}" == '5432' ]] ||
  fail 'Expected postgres database, port 5432.'
[[ "${PGSSLMODE:-}" == 'verify-full' ]] ||
  fail 'Require PGSSLMODE=verify-full for certificate + hostname verification.'
[[ -n "${PGSSLROOTCERT:-}" ]] ||
  fail 'Set PGSSLROOTCERT=system or a verified CA certificate path.'
[[ -n "${PGPASSFILE:-}" && -f "${PGPASSFILE:-/nonexistent}" ]] ||
  fail 'Require a local credential file.'
[[ -O "$PGPASSFILE" && ! -L "$PGPASSFILE" ]] ||
  fail 'PGPASSFILE must be operator-owned and must not be a symlink.'
[[ "$(stat -c %a "$PGPASSFILE")" == '600' ]] ||
  fail 'PGPASSFILE must have mode 0600 on a Linux filesystem.'
if [[ "${PGHOST:-}" == "db.${ref}.supabase.co" ]]; then
  [[ "${PGUSER:-}" == 'postgres' ]] ||
    fail 'Expected production postgres user.'
elif [[ "${PGHOST:-}" == *.pooler.supabase.com ]]; then
  [[ "${PGUSER:-}" == "postgres.${ref}" ]] ||
    fail 'Session-pooler username must include approved production ref.'
else
  fail 'Refusing non-production/non-Supabase host.'
fi

command -v age >/dev/null || fail 'Install age encryption CLI.'
command -v pg_dump >/dev/null || fail 'Install PostgreSQL 17 client.'
command -v sha256sum >/dev/null || fail 'Missing sha256sum.'
pg_dump --version | grep -Eq 'pg_dump \(PostgreSQL\) 17\.' ||
  fail 'PostgreSQL 17 pg_dump required.'

recipient="${SUKUN_AGE_RECIPIENT:-}"
[[ "$recipient" =~ ^age1[0-9a-z]{30,}$ ]] ||
  fail 'Generate and specify an age PUBLIC recipient. Keep private identity offline.'

out="${SUKUN_BACKUP_DIR:-}"
[[ "$out" == /* && "$out" != '/' && "$out" != /tmp* && "$out" != /var/tmp* ]] ||
  fail 'Use an absolute private Linux directory outside /tmp.'
[[ ! -L "$out" ]] || fail 'Refusing symlink output directory.'
mkdir -p -m 700 -- "$out"
[[ -O "$out" && "$(stat -c %a "$out")" == '700' ]] ||
  fail 'Backup directory must be operator-owned, mode 0700.'
if command -v git >/dev/null; then
  root="$(git rev-parse --show-toplevel 2>/dev/null || true)"
  if [[ -n "$root" ]]; then
    case "$(realpath "$out")/" in
      "$(realpath "$root")/"*) fail 'Refusing backup output inside Git repository.' ;;
    esac
  fi
fi

now="$(date -u +%Y%m%dT%H%M%SZ)"
target="${out%/}/sukun-production-${now}.pgcustom.age"
[[ ! -e "$target" ]] || fail 'Refusing overwrite.'
partial="$(mktemp "${out%/}/.sukun-encrypt.XXXXXXXX")"
cleanup() { rm -f -- "$partial"; }
trap cleanup EXIT HUP INT TERM

# Custom-format logical dump streams directly into age; no plaintext archive
# gets written to disk by this script. Read-only transaction defense in depth.
export PGOPTIONS='-c default_transaction_read_only=on'
export PGCONNECT_TIMEOUT=15
printf '%s\n' 'Starting encrypted READ-ONLY export; no patient rows printed.'
pg_dump \
  --host="$PGHOST" --port="$PGPORT" --username="$PGUSER" --dbname="$PGDATABASE" \
  --format=custom --no-owner \
  --schema=auth --schema=private --schema=public --schema=storage |
  age --recipient "$recipient" --output "$partial"
[[ -s "$partial" ]] || fail 'Encrypted file is empty.'
chmod 600 "$partial"
mv -n -- "$partial" "$target"
sha256sum "$target" > "${target}.sha256"
chmod 600 "${target}.sha256"
printf 'Encrypted export complete (RESTORE STILL UNVERIFIED).\nArchive: %s\nChecksum: %s\n' \
  "$target" "${target}.sha256"
printf '%s\n' 'Keep private age key offline. Copy ciphertext offsite. Verify restore only on isolated infrastructure.'
