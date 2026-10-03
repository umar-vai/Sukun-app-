import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

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

  static TextStyle banglaDisplay({TextStyle? textStyle}) {
    return GoogleFonts.anekBangla(
      textStyle: textStyle,
      fontWeight: FontWeight.w600,
    );
  }

  static TextStyle banglaBody({TextStyle? textStyle}) {
    return GoogleFonts.hindSiliguri(
      textStyle: textStyle,
      fontWeight: FontWeight.w400,
    );
  }

  static TextStyle canonicalReligiousText({TextStyle? textStyle}) {
    return GoogleFonts.tiroBangla(textStyle: textStyle);
  }
}
