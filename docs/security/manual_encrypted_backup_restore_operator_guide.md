# Sukun Life — Manual encrypted backup and isolated restore SOP

**Phase 1 / Issue #62 / Draft PR #63.** Production Supabase project: **vydfafumxptanpkmtrpr**. Production Free Plan has **no automatic backups** and no PITR. **No production export or actual patient-data restore has been performed by this PR.**

## Recovery scope and limitations

The read-only operator script at **scripts/security/production_encrypted_backup.sh** creates a PostgreSQL 17 **custom-format logical archive**, streaming directly to age recipient encryption without saving plaintext. It selects schemas **auth, private, public, storage** and preserves available schema objects, data, privileges and RLS policies. The authorized database user's grants determine what it can read; verify completeness rather than assuming success.

**Not a full Supabase platform backup:** PostgreSQL global roles/passwords, extensions outside those schemas, Supabase Storage **objects** (not metadata), deployed Edge Functions, service secrets, OAuth providers, external media and platform settings require independent recovery coverage. A successful encrypted dump and checksum are insufficient to declare recovery readiness.

## Secure operator workstation (Windows)

1. Use a trusted, patched Windows computer with BitLocker and **WSL2 Ubuntu**. Keep backups under the Linux home folder, **not** a shared/public drive.
2. Install PostgreSQL **17 client**, age, sha256sum, git. Review their version and usage help.
3. Generate a private age identity **only on the operator's trusted WSL filesystem**:

~~~bash
umask 077
mkdir -p -m 700 ~/.config/sukun-recovery
age-keygen -o ~/.config/sukun-recovery/offline-identity.txt
chmod 600 ~/.config/sukun-recovery/offline-identity.txt
age-keygen -y ~/.config/sukun-recovery/offline-identity.txt
~~~

The last command prints a **public** age1... recipient. Never upload or paste the **private** key into this chat, GitHub, Drive, CI or a Flutter client. Preserve another secure offline copy of the private key so that backups remain decryptable in an emergency.

4. In the production Supabase Dashboard choose **Connect**. Use the verified session-pooler hostname on IPv4 networks (user **postgres.vydfafumxptanpkmtrpr**) or direct connection if IPv6 is supported (user **postgres**). Verify actual hostname, port, SSL CA and credentials on your device.
5. In a private editor create the Linux file **~/.config/sukun-recovery/production.pgpass** containing a single PostgreSQL password-file entry in the format: **hostname:5432:postgres:username:password**. Escape special colon/backslash characters as required by PostgreSQL. Apply **chmod 600**. Do not paste the password into shell commands, screenshots or chat.
6. Configure TLS hostname verification; do not downgrade to unverified SSL. If system CA resolution fails, stop and use the correct reviewed certificate.

## Run the READ-ONLY export on the operator's WSL computer

Review the script in PR #63. Use the approved repository checkout. Replace the placeholders below locally; no credentials belong in GitHub.

~~~bash
export PGHOST='VERIFIED_SUPABASE_PRODUCTION_HOST'
export PGPORT='5432'
export PGDATABASE='postgres'
export PGUSER='VERIFIED_PRODUCTION_USERNAME'
export PGPASSFILE="$HOME/.config/sukun-recovery/production.pgpass"
export PGSSLMODE='verify-full'
export PGSSLROOTCERT='system'  # or operator-verified CA path
export SUKUN_AGE_RECIPIENT='age1REPLACE_WITH_PUBLIC_RECIPIENT'
export SUKUN_BACKUP_DIR="$HOME/sukun-encrypted-backups"
export SUKUN_LOCAL_BACKUP_APPROVED='YES_READ_ONLY_BACKUP'
bash scripts/security/production_encrypted_backup.sh
~~~

The script refuses CI, a wrong project host/username, plaintext password environment variables, insecure password file/output permissions, insufficient TLS mode and incompatible pg_dump versions. It streams directly from **read-only pg_dump** to age ciphertext; no plaintext backup archive is written by the script. Output: timestamped encrypted .pgcustom.age and .sha256 checksum. Confirm encryption output, but **do not declare recovery ready**.

## Verify the actual ciphertext locally, not in ChatGPT or CI

- Copy the encrypted archive and checksum to restricted **offsite** storage separately from the private age key. Verify remote copy digest after transfer.
- In the archive directory run **sha256sum -c ARCHIVE.pgcustom.age.sha256**.
- Confirm decryptability and logical format **without creating plaintext on disk**:

~~~bash
set -o pipefail
age -d -i "$HOME/.config/sukun-recovery/offline-identity.txt" \
  "$HOME/sukun-encrypted-backups/ARCHIVE.pgcustom.age" |
  pg_restore --list > /dev/null
~~~

- This list command is a format check, **not a restore drill**. Do not publish TOC or patient data. Verify permissions/schema/objects in a confidential operator review.
- **Real isolated restore:** in a dedicated operator-controlled encrypted workstation or protected, isolated PostgreSQL environment, restore the archive to a freshly created **non-Supabase, non-production**, restricted local database (no externally published ports). Recreate required roles/extensions after expert review. Confirm restored aggregate counts, permissions, RLS, synthetic post-restore isolation and recovery timing. Avoid printing/collecting real patient rows and wipe the isolated environment according to approved data-handling practices. NEVER target production or the existing staging project. A container's deletion is not guaranteed to securely erase an unencrypted disk.
- Store the operator's PASS/FAIL attestation (date/time, ciphertext digest, offsite copy, schema checks and restore timing only) without identifiers, passwords or confidential data.

## CI test and go/no-go gate

**scripts/security/test_synthetic_encrypted_restore.sh** exercises encryption, SHA integrity, incorrect-key refusal, isolated PostgreSQL 17 restore, four schemas, grants and per-user RLS using **fabricated data only**. GitHub Actions may execute this fake fixture; **never give production credentials or patient backups to GitHub Actions**.

Initial operational recommendation: private encrypted **daily** exports plus pre-migration exports, approved access-restricted offsite retention and regular restore rehearsals. Daily backup still has up to approximately a day of potential data loss. Define recovery time/data-loss objectives with the organization.

**RELEASE BLOCKER remains until a real encrypted export, offsite copy, decryption check, isolated recovery drill and operator approval have been independently recorded.** No actual backup or restore was performed by ChatGPT.

Supabase references: https://supabase.com/docs/guides/platform/backups and https://supabase.com/docs/guides/platform/migrating-within-supabase/backup-restore .
