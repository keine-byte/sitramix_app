import 'package:flutter/material.dart';

class AppTheme {
  AppTheme._();

  static const primary = Color(0xFFE12D2E);
  static const secondary = Color(0xFF4142A1);

  static const dark = Color(0xFF111827);

  static const amber = Color(0xFFB7791F);

  static const amberSuave = Color(0x26B7791F);

  static const gray = Color(0xFFF3F4F6);

  static const border = Color(0xFFD1D5DB);

  static const muted = Color(0xFF9A8F80);

  static const rule = Color(0xFF3A3430);

  static const navDivider = Color(0xFF1F2937);

  static const green = Color(0xFF15803D);
  static const greenBg = Color(0xFFF0FDF4);
  static const greenBorder = Color(0xFFA5D6A7);

  static const red = Color(0xFFB91C1C);
  static const redBg = Color(0xFFFEF2F2);
  static const redBorder = Color(0xFFFCA5A5);

  static const blue = Color(0xFF1D4ED8);

  static const splash = Color(0xFF265240);

  static const fontFamily = 'IBMPlexSans';

  static ThemeData get tema => ThemeData(
    fontFamily: fontFamily,
    colorScheme: ColorScheme.fromSeed(
      seedColor: primary,
      brightness: Brightness.light,
    ),
    scaffoldBackgroundColor: Colors.white,
    appBarTheme: const AppBarTheme(
      backgroundColor: Colors.white,
      foregroundColor: dark,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
      iconTheme: IconThemeData(color: amber),
      titleTextStyle: TextStyle(
        fontFamily: fontFamily,
        fontSize: 13,
        fontWeight: FontWeight.w700,
        color: dark,
      ),
    ),
  );
}
