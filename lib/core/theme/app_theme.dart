import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  AppTheme._();

  static const Color imageBgColor = Color(0xFFE8E8FB);
  static const Color buttonColor = Color(0xFF5B5BD6);
  static const Color bgColor = Color(0xFFFFFFFF);
  static const Color textColor = Color(0xFF1C1C21);
  static const Color subheadingColor = Color(0xFF6E6E7A);

  static const Color appBackground = Color(0xFFF4F4F6);
  static const Color cardBackground = Color(0xFFFFFFFF);
  static const Color softSurface = Color(0xFFF7F7FA);
  static const Color fieldBackground = Color(0xFFF1F1F4);
  static const Color chatBubble = Color(0xFFEFEFF4);
  static const Color classroomBackground = Color(0xFFFFFFFF);
  static const Color classroomMessageSurface = Color(0xFFEEEEF1);
  static const Color mutedLavender = Color(0xFFE5E4FA);
  static const Color profileBar = Color(0xFFE5E1F1);
  static const Color selectedSurface = Color(0xFFF4F3FF);
  static const Color onboardingBackground = Color(0xFFF5F6FA);
  static const Color onboardingSurface = Color(0xFFF8F9FD);
  static const Color mediaPlaceholder = Color(0xFFF0F0F3);
  static const Color disabledButton = Color(0xFFBDC3C7);
  static const Color imagePlaceholder = Color(0xFFB9BBC8);
  static const Color subtleShadow = Color(0xFF000000);

  static const Color borderColor = Color(0xFFE1E2EA);
  static const Color dividerColor = Color(0xFFD9DAE4);
  static const Color mutedText = Color(0xFF777887);
  static const Color faintText = Color(0xFF8E8E9F);
  static const Color headingText = Color(0xFF111116);

  static const Color pointColor = Color(0xFFF4A22E);
  static const Color pointBg = Color(0xFFFFEBCF);
  static const Color gemBg = Color(0xFFE8E5FF);
  static const Color streakColor = Color(0xFF24A866);
  static const Color streakBg = Color(0xFFDFF5E8);
  static const Color successBubble = Color(0xFFE0F2E6);
  static const Color chatSuccessBubble = Color(0xFFE8FAF1);
  static const Color successText = Color(0xFF0F5132);
  static const Color dangerText = Color(0xFFD34B40);
  static const Color warningSurface = Color(0xFFFFF0D8);

  static const Color userBubble = Color(0xFFE2F5E9);
  static const Color successSurface = Color(0xFFE7F7EE);
  static const Color successToast = Color(0xFFDCF6E7);
  static const Color errorToast = Color(0xFFFFE7E2);
  static const Color dangerSurface = Color(0xFFFFF1EF);
  static const Color dangerBorder = Color(0xFFF3C4BE);
  static const Color dangerChip = Color(0xFFF9D9D3);
  static const Color wrongAnswerSurface = Color(0xFFFBECEA);
  static const Color wrongAnswerBorder = Color(0xFFD98F86);
  static const Color warningSoft = Color(0xFFFFF1E9);
  static const Color warningIcon = Color(0xFFE29A22);
  static const Color rewardGold = Color(0xFFF3A72C);
  static const Color revealBackground = Color(0xFFDBF4C9);
  static const Color revealIconSurface = Color(0xFFE0F6E9);
  static const Color orbCore = Color(0xFF292930);
  static const Color orbHalo = Color(0xFFB9AAFF);
  static const Color orbMid = Color(0xFF8F80FF);
  static const Color orbFace = Color(0xFFE9FFE9);
  static const Color chipLavender = Color(0xFFF0EDFF);
  static const Color answerText = Color(0xFF4A4A55);
  static const Color stemText = Color(0xFF2C2C34);
  static const Color toastText = Color(0xFF25252B);
  static const Color pageMuted = Color(0xFFF6F6F9);

  static const double radiusSm = 10;
  static const double radiusMd = 14;
  static const double radiusLg = 18;
  static const double radiusXl = 24;
  static const double radiusPill = 999;

  static const List<BoxShadow> floatingShadow = [
    BoxShadow(color: Color(0x1A000000), blurRadius: 18, offset: Offset(0, 6)),
  ];

  static TextStyle text({
    double size = 14,
    FontWeight weight = FontWeight.w400,
    Color color = textColor,
    double? height,
    FontStyle fontStyle = FontStyle.normal,
    double? letterSpacing,
  }) => GoogleFonts.inter(
    fontSize: size,
    fontWeight: weight,
    color: color,
    height: height,
    fontStyle: fontStyle,
    letterSpacing: letterSpacing,
  );

  static ButtonStyle primaryButtonStyle({
    double radius = radiusMd,
    Color? disabledColor,
  }) => ElevatedButton.styleFrom(
    backgroundColor: buttonColor,
    foregroundColor: Colors.white,
    disabledBackgroundColor: disabledColor ?? dividerColor,
    disabledForegroundColor: Colors.white,
    elevation: 0,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(radius)),
  );

  static ButtonStyle secondaryButtonStyle({double radius = radiusMd}) =>
      ElevatedButton.styleFrom(
        backgroundColor: mutedLavender,
        foregroundColor: buttonColor,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radius),
        ),
      );

  static ThemeData get themeData {
    return ThemeData(
      useMaterial3: true,
      scaffoldBackgroundColor: bgColor,
      colorScheme: ColorScheme.fromSeed(
        seedColor: buttonColor,
        primary: buttonColor,
        surface: bgColor,
        onPrimary: Colors.white,
        onSurface: textColor,
      ),
      dividerColor: dividerColor,
      dividerTheme: const DividerThemeData(
        color: dividerColor,
        thickness: 1,
        space: 1,
      ),
      textTheme: TextTheme(
        headlineLarge: text(
          size: 28,
          weight: FontWeight.w700,
          color: textColor,
          height: 36 / 28,
          letterSpacing: -0.14,
        ),
        headlineSmall: text(
          size: 20,
          weight: FontWeight.w800,
          color: textColor,
          height: 1.3,
        ),
        bodyLarge: text(
          size: 18,
          color: subheadingColor,
          height: 27 / 18,
        ),
        bodyMedium: text(
          size: 14,
          color: textColor,
          height: 1.5,
        ),
        bodySmall: text(
          size: 12,
          color: subheadingColor,
          height: 1.4,
        ),
        labelLarge: text(
          size: 14,
          weight: FontWeight.w700,
          color: textColor,
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: buttonColor,
          foregroundColor: Colors.white,
          minimumSize: const Size(double.infinity, 52),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radiusMd),
          ),
          textStyle: text(
            size: 16,
            weight: FontWeight.w600,
            color: Colors.white,
          ),
          elevation: 0,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: buttonColor,
          side: const BorderSide(color: borderColor),
          minimumSize: const Size(0, 48),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radiusMd),
          ),
          textStyle: text(size: 15, weight: FontWeight.w600),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: cardBackground,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 14,
        ),
        hintStyle: text(size: 14, color: faintText),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusMd),
          borderSide: const BorderSide(color: borderColor),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusMd),
          borderSide: const BorderSide(color: borderColor),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusMd),
          borderSide: const BorderSide(color: buttonColor, width: 1.5),
        ),
        disabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusMd),
          borderSide: const BorderSide(color: borderColor),
        ),
      ),
    );
  }
}