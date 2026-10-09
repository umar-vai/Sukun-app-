# Sukun Life — Browser Preview

## Current status
The production project is a standalone **Flutter Android/iOS app**, not the existing Sukun Life website. Changes pushed to GitHub are **not** automatically published to `sukunlife.com`, the production Supabase Edge Functions, or Google Play.

## New preview CI
`.github/workflows/guest-web-preview.yml` attempts to compile the real Flutter UI for the browser. The preview target is `app/lib/main_web_preview.dart`. It intentionally refuses Supabase configuration and uses the app's GuestAuthRepository. All server-side credentials, patient data, admin login, notifications and push integrations are absent.

Build outputs, if compilation succeeds, are published as the **GitHub Actions artifact** `sukun-guest-web-preview` for seven days. A build artifact is **not a live website URL**. This workflow does not deploy anything to GitHub Pages or change the existing public site.

## What the guest preview can show
- Real Flutter guest/public layout, brand, navigation, and screens that work without backend data.
- UI code changes on future pushes after the pipeline is merged.
- Device-width responsive layout in a browser, subject to browser-specific plugin behavior.

## What it cannot verify
- Patient ID sign-in, OTP, Google Sign-in, super-admin, patient-specific plan, or production notifications.
- Live Supabase security changes, Edge Function deployment state, or iOS-native behavior.
- Browser UX until a web build **and** browser smoke test pass.

## Next gates before enabling a public preview domain
1. Pass the web compilation job with no secrets or backend connection.
2. Validate a browser smoke test: guest home renders; navigation and responsive widths work; unsupported mobile plugins don't crash bootstrap.
3. Enable a **separate** GitHub Pages deployment (or independent hosting) that never targets the existing public website or internal dashboard. Confirm URL and access policy.
4. Add a clearly labeled mock/demo-only Admin/Patient walkthrough using synthetic data if requested. Never expose real patient data or run production Auth from a public UI showcase.
5. For an authenticated staging web app, provision a separate Supabase staging project, test CORS/OAuth redirect allowlists, and require approved access controls.

Until step 3 is verified, there is **no browser URL** that reflects all app updates. A website should not be advertised as live based only on a GitHub commit.
