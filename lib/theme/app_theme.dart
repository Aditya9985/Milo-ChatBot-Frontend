import 'package:flutter/material.dart';

class AppTheme {
  static const blue = Color(0xff006096);
  static const brightBlue = Color(0xff007abc);
  static const ink = Color(0xff131b2e);
  static const muted = Color(0xff6f7882);
  static const subtle = Color(0xff3f4851);
  static const red = Color(0xffb7131a);
  static const paleBlue = Color(0xffcee5ff);
  static const wash = Color(0xfff2f3ff);
  static const canvas = Color(0xfffaf8ff);

  static ThemeData data() => ThemeData(
        useMaterial3: true,
        scaffoldBackgroundColor: canvas,
        colorScheme:
            ColorScheme.fromSeed(seedColor: blue, brightness: Brightness.light)
                .copyWith(primary: blue, secondary: red, surface: Colors.white),
        fontFamily: 'Plus Jakarta Sans',
        appBarTheme: const AppBarTheme(
            backgroundColor: canvas,
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
                const EdgeInsets.symmetric(horizontal: 18, vertical: 16)),
      );
}
