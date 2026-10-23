# Sukun Life — Li Ador Noirrit font picker (23 October 2026)

## Source evidence

The user identified the font variants in a screenshot. Ten matching TTF originals have also been recovered from their personal Library and inspected with fontTools, **without copying them to a public GitHub repository**. Their TrueType family/style metadata reads as Li Ador Noirrit / ExtraLight / Light / SemiBold and each file covers 82 Bengali Unicode cmap entries.

The linked GitHub API connection supports UTF-8 text commits but does not accept a local binary attachment by path. **Binary font assets have not been committed.** Do not say the production picker is functional until the original TTF assets are added, licensed for web distribution, and deployed.

## Correct font asset paths (private staging before publication)

Once redistribution rights are verified, upload original TTF bytes (do not replace with a similarly named typeface) to:

`app/assets/fonts/li_ador_noirrit/`

Required filenames:
- Li Ador Noirrit ExtraLight.ttf
- Li Ador Noirrit ExtraLight Italic.ttf
- Li Ador Noirrit Light.ttf
- Li Ador Noirrit Light Italic.ttf
- Li Ador Noirrit Regular.ttf
- Li Ador Noirrit Italic.ttf
- Li Ador Noirrit SemiBold.ttf
- Li Ador Noirrit SemiBold Italic.ttf
- Li Ador Noirrit Bold.ttf
- Li Ador Noirrit Bold Italic.ttf

Flutter family registration under the existing `flutter:` key in `app/pubspec.yaml`:

```yaml
  fonts:
    - family: SukunLiAdorNoirrit
      fonts:
        - asset: 'assets/fonts/li_ador_noirrit/Li Ador Noirrit ExtraLight.ttf'
          weight: 200
        - asset: 'assets/fonts/li_ador_noirrit/Li Ador Noirrit ExtraLight Italic.ttf'
          weight: 200
          style: italic
        - asset: 'assets/fonts/li_ador_noirrit/Li Ador Noirrit Light.ttf'
          weight: 300
        - asset: 'assets/fonts/li_ador_noirrit/Li Ador Noirrit Light Italic.ttf'
          weight: 300
          style: italic
        - asset: 'assets/fonts/li_ador_noirrit/Li Ador Noirrit Regular.ttf'
          weight: 400
        - asset: 'assets/fonts/li_ador_noirrit/Li Ador Noirrit Italic.ttf'
          weight: 400
          style: italic
        - asset: 'assets/fonts/li_ador_noirrit/Li Ador Noirrit SemiBold.ttf'
          weight: 600
        - asset: 'assets/fonts/li_ador_noirrit/Li Ador Noirrit SemiBold Italic.ttf'
          weight: 600
          style: italic
        - asset: 'assets/fonts/li_ador_noirrit/Li Ador Noirrit Bold.ttf'
          weight: 700
        - asset: 'assets/fonts/li_ador_noirrit/Li Ador Noirrit Bold Italic.ttf'
          weight: 700
          style: italic
```

## Release gate

1. Validate file permissions (distribution through a public Flutter Web browser bundle is redistribution).
2. Add actual TTF files, register the ten styles in pubspec and verify exact filenames; no fake empty font files.
3. After assets are present, pass `--dart-define=SUKUN_LI_ADOR_NOIRRIT_BUNDLED=true` to Flutter Web, Android/iOS and Flutter tests. Do not set this define until real files are bundled. This gates the dropdown choice and branded default; current code fails closed instead.
4. Run `dart format --output=none --set-exit-if-changed`, `flutter analyze`, unit/widget tests and `flutter build web` from the real app source.
5. Manually verify Bengali ligatures, headings, body text, font weight 200/300/400/600/700, italics, dark mode, refresh/persistence, and that Arabic Qur'an text remains Naskh.
6. Merge only after CI green. Verify Pages deployed SHA and inspect actual Web text rendering; do not confuse a green code PR with shipped TTF bytes.

No Supabase migrations/functions, no `sukunlife.com` edits, no APK/AAB packaging.
