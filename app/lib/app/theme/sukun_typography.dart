import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

abstract final class SukunTypography {
  static TextTheme englishTextTheme(TextTheme base) {
    return GoogleFonts.poppinsTextTheme(base).copyWith(
      displayLarge: GoogleFonts.poppins(
        textStyle: base.displayLarge,
        fontWeight: FontWeight.w300,
      ),
      displayMedium: GoogleFonts.poppins(
        textStyle: base.displayMedium,
        fontWeight: FontWeight.w300,
      ),
      headlineLarge: GoogleFonts.poppins(
        textStyle: base.headlineLarge,
        fontWeight: FontWeight.w600,
      ),
      headlineMedium: GoogleFonts.poppins(
        textStyle: base.headlineMedium,
        fontWeight: FontWeight.w600,
      ),
      titleLarge: GoogleFonts.poppins(
        textStyle: base.titleLarge,
        fontWeight: FontWeight.w600,
      ),
      bodyLarge: GoogleFonts.poppins(
        textStyle: base.bodyLarge,
        fontWeight: FontWeight.w400,
      ),
      bodyMedium: GoogleFonts.poppins(
        textStyle: base.bodyMedium,
        fontWeight: FontWeight.w400,
      ),
      labelLarge: GoogleFonts.poppins(
        textStyle: base.labelLarge,
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
