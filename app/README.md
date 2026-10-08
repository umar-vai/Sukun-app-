# Sukun Life Flutter App

The Android/iOS client for the standalone Sukun Life patient-care platform.
The app supports guest, patient, and server-verified Super Admin experiences.

See the repository-level `AGENTS.md`, `CODEX_START_HERE.md`, and
`IMPLEMENTATION_CHECKLIST.md` before making changes.

## Local run

```bash
flutter pub get
flutter run \
  --dart-define=SUPABASE_URL=https://YOUR_PROJECT.supabase.co \
  --dart-define=SUPABASE_ANON_KEY=YOUR_CLIENT_SAFE_PUBLISHABLE_KEY \
  --dart-define=FIREBASE_PROJECT_ID=YOUR_FIREBASE_PROJECT_ID
```

Only client-safe values belong in `dart-define`. Gemini credentials, Supabase
service-role keys, and Firebase server credentials are server-only.

## Verification

```bash
dart format --output=none --set-exit-if-changed lib test
flutter analyze
flutter test
flutter build apk --debug
```

Offline completion events use Android Keystore/iOS Keychain-backed secure
storage. Android's minimum supported version is Android 6.0 (API 23).


## Web preview

The `web-preview` branch is the browser-based development review target.
Each push runs analyze/tests, builds Flutter Web, and publishes the generated
static site to the `gh-pages` branch.

The web preview intentionally preserves the Android/iOS product architecture.
Mobile-only background audio, exact local reminder behavior, device compass,
and other OS-specific integrations still require native-device QA.
