# FCM audience isolation and opt-out acceptance — 30 October 2026

## Known physical evidence (not a blanket release)

On **one connected staging Guest Android QA handset**, the owner confirmed:
- An authentic Staging Admin publication generated an Android OS push.
- Tapping it opened the exact published notice, not Home.
- Turning public-notice Push OFF persisted across app restart.
- The previously published public notice remained manually readable with Push OFF.

Isolated staging outbox reported a provider-accepted `sent` job and a successful
HTTP 200 dispatcher invocation. This proves **one subscribed handset's observed
delivery**, not topic delivery to everyone or Firebase opt-out delivery suppression.

## Critical audience boundary

Both the Android app and Edge sender use topic
`sukun_public_notices_v1`. Topics are scoped to a **Firebase project**, not
a Supabase database. An isolated Supabase staging URL does not isolate FCM
subscribers when staging and production use the same Firebase project.

The connected Android pilot workflow now requires **two independently checked
project IDs** before another **explicitly authorized** rich-notice debug APK
may build:

- Existing Actions Secret `SUKUN_QA_FIREBASE_PROJECT_ID`: the isolated
  staging Firebase Android client project ID.
- New Actions **Variable** `SUKUN_PRODUCTION_FIREBASE_PROJECT_ID`: the
  verified production Firebase project ID from **Firebase Console → Project
  settings → General**. Firebase project IDs are public metadata, not
  Firebase service-account credentials.

The guard fails closed if either is absent or if they match, without
printing IDs, secrets or tokens. It only runs for
`rich_notice_pilot=true`; routine Web-first CI runs five offline synthetic
guard regression tests without building an APK.

**Scope limitation:** This guards **future QA APK builds only**. It does not
change the Firebase project used by the already-installed APK or the live
Staging Edge sender, does not verify the server service account, does not
unsubscribe existing clients, and does not approve any topic broadcast.
Do not enable or repeat Staging broadcasts while the existing sender's Firebase
project separation from Production is still unverified.

## Required operator-only verification (no secret values in GitHub/ChatGPT)

1. Open the separate Staging and Production Firebase Console project settings
   and establish the two actual **project IDs** differ. If Production has no
   separate project yet, keep topic broadcast gated; do **not** invent an ID.
2. Confirm that the **installed staging APK** was built with the staging
   Firebase project; the QA build secret matches that project.
3. Privately verify the **Staging Supabase Edge Function** server values
   `FIREBASE_PROJECT_ID` and `FIREBASE_SERVICE_ACCOUNT_JSON` refer to the
   **same isolated staging Firebase project**, never Production. Never copy
   the service-account JSON into source, Actions logs, tickets, or chat.
4. Review whether any earlier staging-topic broadcast could have reached
   production-installed clients before declaring audience separation.
5. If staging and production share a Firebase project, **stop topic sends** and
   plan a separately authorized staging Firebase migration with coordinated
   server configuration and one-shot device QA. Do not silently change topic
   names on only one side; existing clients would stop matching the sender.

## Follow-up real opt-out delivery acceptance — not yet performed

Only after Firebase project separation is independently proven:

1. With two **explicitly consented staging-only** phones, label one Push ON,
   the other Push OFF. Use synthetic public notice copy; never patient data.
2. Confirm the OFF device stays OFF after restart and the inbox remains usable
   (already owner-observed on one phone).
3. For **one approved limited staging Firebase audience**, send a fresh
   non-sensitive public notice. Do not use the production project, production
   Firebase topic or any shared/unbounded topic.
4. Record ON receipt and exact UUID tap; verify OFF device gets no topic push,
   without relying on a Firebase **single-token** test (single-token sends
   bypass topic opt-in/out). Repeat after re-enabling ON with fresh consent.
5. Record Android OS/version, foreground/background and cold-start outcomes;
   archive synthetic notice, check outbox idempotency and avoid duplicate sends.

A negative observation on one handset does not prove subscriber-wide absence.
Do not scale to 10, 100 or 15k–20k devices before release gates and explicit
operator approval. No native packaging or production deployment is authorized
by this document.
