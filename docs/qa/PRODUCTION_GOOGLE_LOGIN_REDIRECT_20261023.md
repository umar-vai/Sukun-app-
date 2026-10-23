# Production Google Login: Google 400 redirect_uri_mismatch (2026-10-23)

## Verified evidence
- User's Google error screenshot: `Error 400: redirect_uri_mismatch` at Google's consent entry. This means the OAuth web client's allowlisted redirect URI does not equal the redirect_uri sent to Google.
- The actual Flutter Pages app is served at `https://app.sukunlife.com/`, but latest trusted main Pages deployment on commit `aa5228daaadb6d786cf10d0f7466b3b020d6fbe7` ran with **Staging backend**: build log explicitly says `Staging Google OAuth enabled`. This does not mean that a separate mock app is in use. It is the same Flutter source with a staging backend flag.
- Production Supabase project: `vydfafumxptanpkmtrpr`. The Oct 23 PR check of Production public `/auth/v1/settings` confirms Google provider **enabled**. This does not verify Google Cloud redirect registration or completed login.
- PR #186 contains safe error messaging and public-only handoff preflight, now scoped to **Production** in the PR workflow. No staging backend modifications.

## Exact Production OAuth setup required

In the Google Cloud project which owns the **same OAuth Web Client ID** configured in **Production** Supabase Auth > Providers > Google:

1. Google Auth Platform > Clients > select the matching **Web application** client (not Android/iOS client).
2. Under Authorized redirect URIs register **exactly**:
   `https://vydfafumxptanpkmtrpr.supabase.co/auth/v1/callback`
   Note: this is the **Google -> Supabase** return endpoint. Do not substitute `https://app.sukunlife.com/` here. Do not add a trailing slash to `/callback`.
3. Authorized JavaScript origins: `https://app.sukunlife.com` (origin only, no path). Relevant when using browser Google sign-in.
4. Google Auth Platform > Audience: ensure the account is an authorized test user if the OAuth consent screen is in Testing status. Verify scopes `openid`, email, profile.
5. Supabase **Production** Auth > URL Configuration: allow `https://app.sukunlife.com/` (this is the **Supabase -> Flutter** redirect URL). Site URL may be that same approved app URL; do not replace the public marketing website's routes.
6. Do NOT share Google client secret, refresh token, session JWT, patient email, or a Google OAuth URL containing state/token with chat or public source. Update client secret only inside Supabase dashboard if the configured client itself was changed.

## Deploy the existing main app against Production (not Staging)

The existing GitHub Actions workflow reads repo variable `SUKUN_PREVIEW_USE_STAGING`. If it remains `true`, **every approved main Pages deployment connects to Staging regardless of Google Cloud Production setup**.

After explicit operator production-backend approval and privacy tests:
1. In `umar-vai/Sukun-app-` > Settings > Secrets and variables > Actions > **Variables**, set `SUKUN_PREVIEW_USE_STAGING=false`. Also verify emergency-only `SUKUN_PREVIEW_FORCE_GUEST_ONLY=false` or unset.
2. Approve CI-green main deployment. Changing an Actions variable does **not** update deployed JavaScript until new CI-successful main build and Pages deploy.
3. Verify live `https://app.sukunlife.com/preview-build.json` has `backend_mode=production`, exact main SHA, `auth_features.google_oauth=true`. Ensure Deploy Pages HTTP SHA gate passes.
4. Run a dedicated **non-patient** Google Member sign-in in real Chrome; verify the sign-in reaches Google consent and **returns** to the Flutter app with a Supabase session and only `member` role. Check sign-out, refresh and Guest/Member forbidden clinical access.
5. Production Google OAuth configuration remains **external** to code. This PR cannot repair an unregistered Google Cloud callback or change GitHub repository variables through code.

## Release guardrails

- Do not touch `sukunlife.com` or legacy admin dashboard; do not create any new site or native package.
- No staging SQL, function, Auth or data writes; no real patient test account.
- No Production Auth / user mutation is authorized by this documentation.
- Public client contains only published Supabase publishable key, never OAuth client secret/service role.
- A 302 from Supabase to Google is *not* evidence of successful sign-in; browser return and RLS must be separately verified.
- Keep PR draft until checks pass and production OAuth configuration + real browser QA are confirmed.
