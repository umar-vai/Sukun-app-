# Sukun Life — owner-authorized audio use record

**Recorded:** 2026-10-12  
**Basis:** Direct statement of the Sukun Life project owner/representative in the app development conversation.  
**Scope:** All audio resources identified in the Sukun Life guide and mapped to Ruqyah Support BD's audio catalog, including the 19-item crosswalk. Owner says Sukun Life has permission and licensing for in-app use, including streaming and distribution.  

## Operating decision

- Record this as an **owner-attested authorization**, not a third-party-signed certificate. No signed external license document was supplied, so no document or third-party signature has been fabricated.
- Do **not** request repeated manual license approval for the same in-scope recordings. Existing and newly imported items use one reusable rights statement in **Admin metadata**.
- Preserve original audio attribution and URLs. Reuse the working **Flutter in-app audio player** with direct HTTPS streaming from the original host. Do not download or duplicate large audio files into Sukun Life Storage solely to prove rights or deliver playback.
- Listeners (Guest, General User, Patient) see **track title, playable media, and optional short publisher credit** — not internal rights notes, book paragraph numbers, legal review status or licensing warnings.
- Separate editorial accuracy, file accessibility, player/browser compatibility and patient eligibility checks from copyright authorization. Publication status is never silently changed by this attestation.
- For recordings outside this owner-attested scope, require an independently recorded appropriate rights basis before publishing.
- To archive an actual signed license, a company operator may attach the genuine agreement later to private controlled storage. Avoid placing signatures or private legal contracts in public GitHub, web client assets or application responses.

## Implementation state

- 19 staging CMS audio entries received the owner rights statement on 2026-10-12 while retaining their existing 17 Draft / 2 Published and all Staff-only visibility settings.
- Both the original linked audio detail and the 19-track source directory are intended to keep an in-app audio player and source attribution.
- This record is not evidence that all 19 URLs have passed real-device playback tests; one working device track was confirmed by the user.
- No production patient database or existing public sukunlife.com modifications are required.
