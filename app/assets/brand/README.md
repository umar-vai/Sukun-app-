# Sukun Life brand assets

The official, client-supplied logo is stored at:

`assets/brand/sukunlife_logo.png`

The checked-in PNG is the client-supplied source file and must remain unmodified. Do not add a recreated, recolored, stretched, cropped, or AI-generated logo.

## Official browser and Android icons

The full client-supplied PNG above is the **only** icon artwork source.
`tool/branding/GenerateSukunIcons.java` places the **whole logo**, retaining
its color and aspect ratio, onto Sukun Navy square canvases; it never edits
this source, removes any part of the mark, or creates a new interpretation.

- The Flutter Web Pages workflow generates `web/favicon.png`,
  `web/icons/Icon-192.png`, `Icon-512.png`, `Icon-maskable-512.png`,
  and `apple-touch-icon.png` before the actual Flutter Web build.
- Android Gradle runs `generateOfficialSukunLauncherIcons` before merging
  Android resources to replace default `ic_launcher` images at every density
  and generate adaptive icon foregrounds. **This does not package an APK.**
- On a developer machine (JDK 17+): from `app/`, run
  `java -Djava.awt.headless=true tool/branding/GenerateSukunIcons.java --web .`
  for a local Web favicon, then `python3 tool/branding/verify_brand_icons.py`
  after also generating `--android`.
- Existing user installations change launcher icons only after the next
  **separately approved and installed Android update**, never from a Web deploy.
- iOS launcher icons are a separate native-platform release readiness task.
