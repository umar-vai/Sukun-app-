# Sukun Life — Single-device public FCM acceptance gate (25 October 2026)

## Evidence and scope

- The owner confirmed a **generic Firebase Console "Send test message" arrived on the authorized Android QA handset**. This verifies only that single-token background FCM delivery can work. It does **not** prove the topic broadcast, image, chronometer, rich payload parsing or notice tap behavior.
- The owner installed the **staging-only debug APK** built in one-shot pilot [run #40190480795](https://github.com/umar-vai/Sukun-app-/actions/runs/40190480795); do not repeat native builds automatically.
- Isolated staging synthetic Super Admin REST/JWT → image upload → Draft → Publish → Guest Chrome → Archive → Storage cleanup gate passed [run #40194685033](https://github.com/umar-vai/Sukun-app-/actions/runs/40194685033). That test did **not** click through the signed-in Flutter Admin UI.
- This patch repairs discovered static gaps: Guest foreground FCM coordinator initialization, single-consumer validated universal tap delivery (background and cold start), and image host validation for the actually configured staging **or** production Supabase project.

## Safe single-token acceptance (pending a separately approved native QA build)

1. Use **Firebase Console → Send test message**, with exactly the private single-device FCM registration token from the owner's local PC clipboard. Do not post, commit, email or log the token.
2. **Never use topic, audience, segment, campaign Publish, or the `sukun_public_notices_v1` topic** in QA. Production topic dispatch release gate stays OFF. Firebase project selection must match the Android client's configured project.
3. Rich notice payload needs a genuine **published synthetic staging notice UUID**, non-sensitive public title/body, **public HTTPS staging image path** in `sukun-announcement-images/notices/`, and a deadline in the next 30 days. Firebase custom data keys: `type=universal_announcement`, `announcement_id=<real staging UUID>`, `image_url=<approved staging public URL>`, `countdown_ends_at=<ISO8601 UTC timestamp>`. *Do not use live patient data or fabricated IDs to claim a successful link test.* FCM notification title/body and image are separate notification fields; Firebase Console UI support for custom data and image must be verified before use.
4. Test with app foreground, background, locked, and process cold start. Foreground Android should use the native `sukun_public_notices` channel and show a bounded public image/countdown when supported. Background Android may show a static FCM notification and does not promise a live countdown.
5. Tap the delivered public notice; the app must open `/announcements/<validated UUID>`. Invalid/archived IDs must fail closed. On the notice page, verify public image and decrementing timer, then archive/delete the synthetic notice + image using Admin-authorized Storage APIs.
6. Record Android version, FCM notification received state, native channel, and sanitized screenshots — **never** FCM tokens, patient records or credentials.

## Release boundary

The current installed pilot APK predates the Guest foreground / staging image / single-consumer tap fixes in this branch. **A green Web/Flutter CI is not device validation and cannot update installed native code.** Further native packaging requires owner approval. No changes to `https://sukunlife.com`, no new preview site, no Play release, and no automatic Firebase/topic broadcasts.
