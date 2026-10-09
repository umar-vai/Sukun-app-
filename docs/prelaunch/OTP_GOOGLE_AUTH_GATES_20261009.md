# OTP / Google sign-in rollout gate (9 October 2026)

Depends on PR #19 (general member account and RLS isolation). No live
Supabase, Play Console, patient record or Firebase setting has been changed.

### Present code
- Existing-account email OTP and phone SMS OTP using Supabase Auth
  `shouldCreateUser: false`. No account creation or patient linking.
- Google OAuth browser flow; successful browser launch is NOT successful login.
- `ENABLE_EMAIL_OTP`, `ENABLE_PHONE_OTP`, `ENABLE_GOOGLE_OAUTH` default false.
- Mobile redirect URL: `com.sukunlife.app://login-callback`, registered
  on Android & iOS and must be allowlisted in Supabase Auth.
- Shared E.164/OTP validation; generic provider errors; 60-second client
  resend cooldown. This is a UX measure, NOT sufficient rate limiting.

### Must finish before turning on in staging, then production
1. Confirm Supabase provider status, SMTP sender, the email OTP template
   contains `{{ .Token }}`, and testing email deliverability.
2. SMS gateway billing, abuse alerts, per-recipient/IP rate limits,
   delivery for Bangladesh and secure server-side CAPTCHA/rate checks.
3. Google Cloud OAuth consent/credentials, Supabase Google provider,
   native deep-link callback allowlist and web authorized origins.
4. Verify OTP invalid/expired/reused attempts and account enumeration.
5. Check members cannot see clinical data under RLS and no automatic
   linking to a patient record by matching email/phone.
6. Account linking and recovery require a separate verified/admin-reviewed
   workflow. Do not automatically merge patient, staff, or member accounts.
7. E2E signup and login tests on Android/iOS, password reset,
   deletion and security sign-off.
8. Review Android release INTERNET permission in separate release PR #17
   before any signed production AAB.
