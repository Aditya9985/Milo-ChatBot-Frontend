import 'package:flutter/material.dart';

class AppTheme {
  static bool isSuzu = false;

  static Color get blue =>
      isSuzu ? const Color(0xffa83f69) : const Color(0xff8a5a00);
  static Color get brightBlue =>
      isSuzu ? const Color(0xffe789ad) : const Color(0xffe7b742);
  static const ink = Color(0xff131b2e);
  static const muted = Color(0xff6f7882);
  static const subtle = Color(0xff3f4851);
  static const red = Color(0xffb7131a);
  static Color get paleBlue =>
      isSuzu ? const Color(0xfff3c9d9) : const Color(0xfff5e4b7);
  static Color get wash =>
      isSuzu ? const Color(0xfffff0f6) : const Color(0xfffff8e8);
  static Color get canvas =>
      isSuzu ? const Color(0xfffff6fa) : const Color(0xfffff9eb);
  static Color get surface =>
      isSuzu ? const Color(0xfffffbfd) : const Color(0xfffffdf7);
  static Color get primaryContainer =>
      isSuzu ? const Color(0xfff4bfd2) : const Color(0xfff2c85b);

  static ThemeData data({bool suzu = false}) {
    final primary = suzu ? const Color(0xffa83f69) : const Color(0xff8a5a00);
    final primaryContainer =
        suzu ? const Color(0xfff4bfd2) : const Color(0xfff2c85b);
    final surface =
        suzu ? const Color(0xfffffbfd) : const Color(0xfffffdf7);
    return ThemeData(
        useMaterial3: true,
        scaffoldBackgroundColor: surface,
        colorScheme:
            ColorScheme.fromSeed(
                    seedColor: primary, brightness: Brightness.light)
                .copyWith(
          primary: primary,
          primaryContainer: primaryContainer,
          secondary: red,
          surface: surface,
          onPrimary: Colors.white,
          onPrimaryContainer: ink,
        ),
        fontFamily: 'Plus Jakarta Sans',
        appBarTheme: AppBarTheme(
            backgroundColor: surface,
            foregroundColor: ink,
            elevation: 0,
            centerTitle: false),
        inputDecorationTheme: InputDecorationTheme(
            filled: true,
            fillColor: Colors.white,
            hintStyle: const TextStyle(color: muted),
            border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(18),
                borderSide: BorderSide.none),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 18, vertical: 16)));
  }
}
