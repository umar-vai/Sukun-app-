import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:sukun_life/app/theme/bengali_font_settings.dart';

abstract final class SukunTypography {
  static TextTheme englishTextTheme(TextTheme base) {
    return GoogleFonts.poppinsTextTheme(base).copyWith(
      displayLarge: GoogleFonts.poppins(
        textStyle: base.displayLarge,
        fontSize: 42,
        height: 1.08,
        fontWeight: FontWeight.w300,
      ),
      displayMedium: GoogleFonts.poppins(
        textStyle: base.displayMedium,
        fontSize: 34,
        height: 1.12,
        fontWeight: FontWeight.w300,
      ),
      headlineLarge: GoogleFonts.poppins(
        textStyle: base.headlineLarge,
        fontSize: 30,
        height: 1.18,
        fontWeight: FontWeight.w600,
      ),
      headlineMedium: GoogleFonts.poppins(
        textStyle: base.headlineMedium,
        fontSize: 25,
        height: 1.22,
        fontWeight: FontWeight.w600,
      ),
      headlineSmall: GoogleFonts.poppins(
        textStyle: base.headlineSmall,
        fontSize: 21,
        height: 1.25,
        fontWeight: FontWeight.w600,
      ),
      titleLarge: GoogleFonts.poppins(
        textStyle: base.titleLarge,
        fontSize: 20,
        height: 1.3,
        fontWeight: FontWeight.w600,
      ),
      titleMedium: GoogleFonts.poppins(
        textStyle: base.titleMedium,
        fontSize: 16,
        height: 1.35,
        fontWeight: FontWeight.w600,
      ),
      titleSmall: GoogleFonts.poppins(
        textStyle: base.titleSmall,
        fontSize: 14,
        height: 1.35,
        fontWeight: FontWeight.w600,
      ),
      bodyLarge: GoogleFonts.poppins(
        textStyle: base.bodyLarge,
        fontSize: 16,
        height: 1.55,
        fontWeight: FontWeight.w400,
      ),
      bodyMedium: GoogleFonts.poppins(
        textStyle: base.bodyMedium,
        fontSize: 14,
        height: 1.55,
        fontWeight: FontWeight.w400,
      ),
      bodySmall: GoogleFonts.poppins(
        textStyle: base.bodySmall,
        fontSize: 12,
        height: 1.5,
        fontWeight: FontWeight.w400,
      ),
      labelLarge: GoogleFonts.poppins(
        textStyle: base.labelLarge,
        fontSize: 14,
        fontWeight: FontWeight.w600,
      ),
    );
  }

  static TextStyle previewBengaliFont(
    BengaliFontChoice choice, {
    TextStyle? textStyle,
    FontWeight fontWeight = FontWeight.w400,
  }) => switch (choice) {
    BengaliFontChoice.hindSiliguri => GoogleFonts.hindSiliguri(
      textStyle: textStyle,
      fontWeight: fontWeight,
    ),
    BengaliFontChoice.anekBangla => GoogleFonts.anekBangla(
      textStyle: textStyle,
      fontWeight: fontWeight,
    ),
    BengaliFontChoice.tiroBangla => GoogleFonts.tiroBangla(
      textStyle: textStyle,
      fontWeight: fontWeight,
    ),
  };

  /// Apply a user-selected Bengali fallback while retaining Poppins for Latin.
  static TextTheme withBengaliFallback(
    TextTheme theme,
    BengaliFontChoice choice,
  ) {
    final family = previewBengaliFont(choice).fontFamily;
    if (family == null) return theme;
    TextStyle? fallback(TextStyle? style) =>
        style?.copyWith(fontFamilyFallback: [family]);

    return theme.copyWith(
      displayLarge: fallback(theme.displayLarge),
      displayMedium: fallback(theme.displayMedium),
      displaySmall: fallback(theme.displaySmall),
      headlineLarge: fallback(theme.headlineLarge),
      headlineMedium: fallback(theme.headlineMedium),
      headlineSmall: fallback(theme.headlineSmall),
      titleLarge: fallback(theme.titleLarge),
      titleMedium: fallback(theme.titleMedium),
      titleSmall: fallback(theme.titleSmall),
      bodyLarge: fallback(theme.bodyLarge),
      bodyMedium: fallback(theme.bodyMedium),
      bodySmall: fallback(theme.bodySmall),
      labelLarge: fallback(theme.labelLarge),
      labelMedium: fallback(theme.labelMedium),
      labelSmall: fallback(theme.labelSmall),
    );
  }

  static TextStyle banglaDisplay({TextStyle? textStyle}) => previewBengaliFont(
    BengaliFontSettings.instance.value,
    textStyle: textStyle,
    fontWeight: FontWeight.w600,
  );

  static TextStyle banglaBody({TextStyle? textStyle}) => previewBengaliFont(
    BengaliFontSettings.instance.value,
    textStyle: textStyle,
  );

  static TextStyle canonicalReligiousText({TextStyle? textStyle}) {
    // Arabic scripture uses a clear Naskh face, not the Bangla display font.
    // Do not alter diacritics or apply decorative letter spacing.
    return GoogleFonts.notoNaskhArabic(
      textStyle: textStyle,
      fontSize: 26,
      fontWeight: FontWeight.w400,
      height: 2.0,
      letterSpacing: 0,
    );
  }
}
