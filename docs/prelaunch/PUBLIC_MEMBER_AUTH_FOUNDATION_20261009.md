# Public membership foundation — 9 October 2026

**Status: isolated draft. No production Supabase migration or public signup enabled.**

## Why
Sukun Life needs free general user accounts without giving them access to
patient prescriptions, other people's clinical details, staff functions, or
super-admin CMS. Older patient IDs/passwords and approved plans remain intact.

## Database steps
- First migration commits a new `member` ENUM role.
- Second migration creates an Auth insert trigger that assigns ONLY the member
  role and a Bangla profile. It never accepts a client-supplied role.
- Existing explicit `patient` and `super_admin` roles take priority over
  `member`; patient account provisioning remains server-controlled.
- pgTAP assertions cover metadata role escalation, RLS isolation, restricted
  trigger execution, and legacy role coexistence.
- Migration files must first be reconciled with the LIVE migration history
  and applied to STAGING. Do not reset production.

## Flutter steps
- New `/register` route and simple email/password registration screen.
- Authenticated members use public resources only; they can sign out.
- The existing patient/admin login route is retained.
- Registration is disabled by default via `ENABLE_MEMBER_SIGNUP=false`.
  It may be enabled in a deliberately built staging or production binary only
  after SQL migrations and email verification have passed independent QA.

## Work still needed before enabling signup
- Set up SMTP sender, email verification templates and allowed callback URLs.
- Verify two devices, email-confirm-required and email-confirm-disabled modes.
- Rate limit + anti-bot strategy (CAPTCHA/turnstile), password reset,
  user deletion, phone number re-use and account linking.
- SMS OTP: provider, sender identity, user abuse limits, test delivery.
- Google OAuth: Supabase provider, redirect/deep-link URIs, Android/iOS
  certificate fingerprints, provider approval and collision/account linking.
- Staff/raqi permissions require separate assignment tables/RLS, NOT member
  metadata claims. They are explicitly excluded from this first increment.
- Full QA on old patients; verify cross-role RLS and sign-in continuity.

## Operational safety
This branch never edits existing patient data, does not grant public clients
membership assignment privileges, and does not enable public registrations on
the current web preview. Do not treat unit tests as production security signoff.
