# Sukun Life — Live Isolated Staging Backend Gate (10 October 2026)

This operational snapshot updates the *historical* staging setup notes in
[STAGING_PREVIEW_ACTIVATION_2026_10_10.md](STAGING_PREVIEW_ACTIVATION_2026_10_10.md).

## Verified environment

- **Production (DO NOT CHANGE):** `vydfafumxptanpkmtrpr`
- **Staging:** `qacklgqvxvjjzsimjoip` — "Sukun Life Staging", Sukun Life Org, ap-southeast-2.
- **Creation cost returned by Supabase:** USD **$0/month** (subject to future plan/usage limits). Supabase Branching cost returned **$0.01344/hour** and was **not** selected.
- **Live schema:** all 20 migrations from the repository's `supabase/migrations` plus reviewed `docs/security/patient_sign_in_rate_limit_staging.sql` applied successfully to staging.
- **RLS:** 25 public tables, 25 RLS-enabled. Member enum present with Patient and Super Admin roles.
- **Data isolation:** staging `auth.users`, patients, roles, and content items are **all empty**. No production patient records or credentials have been copied.
- **Patient sign-in limiter permissions on staging:** `anon` and `authenticated` cannot execute the privileged RPC; `service_role` can.
- **Deployed staging-only Edge Functions:** `admin-create-patient` v1, `send-notification` v1, `prescription-to-actions` v1, `prescription-document-to-actions` v1 are ACTIVE. Deploy alone does not prove browser E2E.
- **Not yet active:** `patient-sign-in` needs the staging-only `SIGN_IN_RATE_LIMIT_SECRET` and matching security verification. `patient-change-password` deployment was blocked by a tool security check; never weaken/bypass that gate. Do not claim either function working.
- **Secrets:** production Gemini/Firebase keys have NOT been copied to staging. AI/manual and notification/no-sender fallback must be verified with synthetic users.
- **Authentication:** no staging Auth users, Super Admin or Patient users have been provisioned. Member Signup / Email OTP / Phone OTP / Google OAuth switches remain **false** unless separately approved and configured.

## Public-only staging bootstrap for the existing Pages site

For the first isolated browser smoke round, the existing Web Actions pipeline now
includes a **verified staging-only public publishable key** as a fallback when
**all three** connection variables are absent. This key is intended for
anonymous browser use, is not a service role / password / Gemini or Firebase
secret, and would appear in built public Flutter JS in any staging-connected
configuration. It is deliberately pinned to staging ref
`qacklgqvxvjjzsimjoip`, never production. The build rejects a key/ref/URL
mismatch and refuses to deploy when its anonymous patient-data API gate fails.

The fallback keeps **member registration, email OTP, phone OTP and Google OAuth
all disabled**, regardless of any isolated feature flag attempts. To safely
enable a provider feature later, configure the complete verified staging
connection variable triplet below and verify the applicable Auth/E2E gate.

For emergency rollback to backend-free guest-only preview, set repository
Actions variable `SUKUN_PREVIEW_FORCE_GUEST_ONLY=true`, then run a fresh approved
main CI-successful deployment. The setting alone does **not** update an
already-built Flutter JavaScript artifact. Alternatively, revert this
staging-only bootstrap in a reviewed main PR.

This is an **API-connectivity smoke milestone**, NOT a claim of authenticated
Patient/Admin/Member end-to-end success; no synthetic users or published audio
are present yet.

## Required operator activation (no server secrets in GitHub)

For explicitly managed provider and auth QA (after bootstrap), the existing Flutter Web preview workflow reads these **GitHub Actions repository variables** from the *existing* `umar-vai/Sukun-app-` repository. Repository variable administration is not exposed by the connected GitHub integration.

| Variable | Value |
|---|---|
| `SUKUN_PREVIEW_SUPABASE_PROJECT_REF` | `qacklgqvxvjjzsimjoip` |
| `SUKUN_PREVIEW_SUPABASE_URL` | `https://qacklgqvxvjjzsimjoip.supabase.co` |
| `SUKUN_PREVIEW_SUPABASE_PUBLISHABLE_KEY` | Copy the **enabled public** `sb_publishable_...` key from the **staging** Supabase project's API Keys page |

Location: GitHub repository → Settings → Secrets and variables → Actions → **Variables**.
Never use a `service_role` key, `sb_secret_` key, production anon key, patient password,
Gemini key, Firebase service account, or any sensitive content in a public Pages bundle.
Supabase publishable keys are designed for public/browser use; **RLS remains the actual boundary**.

Keep `SUKUN_PREVIEW_ENABLE_MEMBER_SIGNUP`, `...EMAIL_OTP`,
`...PHONE_OTP`, and `...GOOGLE_OAUTH` **false** until each provider,
redirect, role provisioning and abuse-protection gate passes.

After the complete staging triplet is saved, use an **approved `main` CI-successful
push** to automatically rebuild and deploy to the **same existing** Pages URL,
not a new site. Changing a variable alone does not rebuild an already published
Flutter JavaScript bundle.

## CI safety gate

`.github/scripts/verify-staging-preview.sh` checks, at build time and **only
in a configured staging release**:

- public resource Data API responds with a valid list;
- the anonymous publishable-key caller sees no rows from `patients`,
  `prescriptions`, `care_plans`, `profiles`, `user_roles`,
  `notification_events` (HTTP 401/403 is also fail-closed);
- malformed keys, non-staging configuration or unexpected API errors block the
  new Pages deployment without printing sensitive API responses.

**Important limitation:** because the staging dataset starts empty, this is
not proof of correct cross-user RLS. Run authenticated Patient A vs Patient B
negative tests **after creating isolated synthetic accounts**, before claiming
Patient/Admin preview sign-off.

## Synthetic user and audio acceptance checklist

1. Use the **Supabase Staging dashboard's Auth user provisioning workflow** to
   create confirmed synthetic test identities. Never use production logins.
   A server-authorized operator must grant the test Super Admin role using the
   existing database-verified role process; never trust `user_metadata`.
2. Set staging-only patient login limiter secret using Supabase's **Edge Function
   Secrets** controls, then deploy and test compatible sign-in/password functions.
   Do not enter a password or a secret into a GitHub commit.
3. Use the existing **Admin CMS** to create a clearly labeled sample audio item
   with a rights-verifiable external source, follow review/publish controls, and
   verify listing/search/audio playback on desktop Chrome and mobile Safari.
   A candidate **test-only public-domain** 2-second beep is documented at
   https://commons.wikimedia.org/wiki/File:Beep_example.ogg; it is not Ruqyah.
4. A direct attempt to insert test audio under a made-up creator UUID was
   **rejected by the existing auth-user FK**, as desired. No constraint was
   weakened, no dummy `auth.users` rows were inserted, and staging is still empty.
5. Test Admin → synthetic Patient creation → approved prescription/care plan →
   publish → Patient A task actions → progress → offline replay. Ensure Patient B
   cannot inspect or mutate Patient A's data even using direct API IDs.
6. Verify auth provider redirects, confirmation, password rotation, account
   takeover protection, rate limits, public Audio rights, and real browser runtime.
7. Record the tested main SHA, GitHub CI status, Pages HTTP commit marker, staging
   function versions, desktop/mobile browser evidence, and any blocker separately.

## Non-negotiable boundaries

No APK/AAB/IPA in the daily cycle. Do not change `sukunlife.com`, the existing
internal dashboard, or production Supabase. Never label a green migration as
a deployed Edge Function, nor a Pages build as authenticated Patient QA.
