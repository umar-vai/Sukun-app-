# Ruqyah Ayat collection — rights-authorized import (October 2026)

- User confirmed permission to reuse material from the Ruqyah Ayat app. No service-role key, patient data, Quran source-brand redirects or third-party promotional links are bundled.
- Imported via the original app's own versioned public JSON endpoints into the **same real Flutter app**, not another website or guest mockup.
- Source endpoints: `/data/ayah_group.json` and `/data/ruqyah_ayah.json` from the licensed reference app. Source provenance kept only in developer documentation.
- Source item counts: 8 groups, 105 original Arabic and Bengali entries. Distribution: 8, 20, 32, 5, 3, 6, 25, 6.
- 103 entries have source MP3 pointers, 95 unique audio identifiers. 2 source entries have no audio pointer; the UI correctly disables playback for those.
- Original audio path is controlled internally by a strict numeric identifier allowlist. The app uses an in-app `just_audio` player, not browser navigation to a different website.
- Exact source JSON snapshot is checked into `app/assets/data/ruqyah_ayat_authorized.json`. It preserves original section order and Arabic/Bengali text; only non-breaking HTML spaces are normalized for display.
- Production database clinical records, the 101 existing editorial Quran records and `sukunlife.com` are untouched.
- **Release gate still required:** device/browser playback of MP3s, content rights sign-off including any mandatory attribution, Quran/Dua editorial proofread for the full 105 entries, full CI, deployed SHA/role workflows. HTTP 200 MP3 alone is not browser playback proof.
- If public-use attribution is required by the rights agreement, add a compliant non-promotional credit rather than hiding required licensing details. Brand links are not displayed in the reader.
