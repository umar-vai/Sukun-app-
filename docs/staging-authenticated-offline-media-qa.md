# Manual authenticated Web offline MP3 acceptance

This **does not** run automatically on pushes, pull requests or deployments.
It tests one real, already-published and strictly allowed public recording in
the isolated Sukun **staging Supabase** project, through the existing
`https://app.sukunlife.com` Flutter Pages preview.

## Requirements

1. Confirm written authority for **offline download/caching** of the chosen
   publisher audio. The existing 2026-10-12 Sukun owner attestation of
   *in-app playback and use* does **not**, by itself, establish the
   third-party's explicit permission for offline copying. Never treat public
   streaming as permission to copy.
2. Use a **dedicated synthetic General Member**, not an existing patient,
   employee, production user, administrator or personal account, in staging
   Supabase `qacklgqvxvjjzsimjoip`. Login must succeed with email/password.
3. Put that synthetic account's email and password into **GitHub Actions
   secrets** `SUKUN_STAGING_MEDIA_TEST_EMAIL` and
   `SUKUN_STAGING_MEDIA_TEST_PASSWORD`; never commit credentials.
4. Following verified offline rights approval, set GitHub Actions repository
   variable `SUKUN_APPROVED_MP3_OFFLINE_RIGHTS=true`. Keep unset until the
   evidence is documented. This is a release gate, not a legal determination.
5. Run **Actions → Staging Authorized MP3 Offline Acceptance (Manual) →
   Run workflow** on `main`.

## What is exercised

- Credentialed Supabase staging login without printing the token.
- Published, public, pinned owner-attested MP3 selection (never patient media).
- Live Pages revision is exactly current trusted `main` and uses staging.
- One bounded real MP3 transfer via Sukun's logged-in Edge download gateway.
- Actual Chrome CORS fetch, complete-byte check and IndexedDB write.
- Reopen same IndexedDB with all network requests blocked and open MP3 blob
  through the browser media decoder; remove test data.

The test refuses transfers larger than 25 MiB. An oversized catalog file
causes a **fail-closed** result: choose a legally authorized smaller
publication through the normal reviewed CMS workflow, not a bypass.

The workflow cannot run to completion until its rights approval and staging
fixture prerequisites are supplied. Ordinary PR tests use synthetic bytes and
test the request routing separately; those are **not** evidence of live
authenticated media delivery. A successful staging run is **not** production
Supabase deployment, native-device validation or third-party rights proof.

Do not add service-role keys to GitHub. Do not publish patient content, expand
the gateway allowlist, mirror publisher MP3 files or change `sukunlife.com`.
