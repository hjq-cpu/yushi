import 'package:flutter/material.dart';

abstract final class YushiColors {
  static const cobalt = Color(0xFF2F5CF3);
  static const ink = Color(0xFF18243C);
  static const secondary = Color(0xFF5C6880);
  static const background = Color(0xFFF8FAFF);
  static const paper = Color(0xFFFFFFFF);
  static const focus = Color(0xFFEDF3FF);
  static const rule = Color(0xFFDCE4F1);
  static const success = Color(0xFF16845B);
  static const danger = Color(0xFFB42318);
}

ThemeData buildYushiTheme() {
  final scheme =
      ColorScheme.fromSeed(
        seedColor: YushiColors.cobalt,
        brightness: Brightness.light,
        surface: YushiColors.paper,
      ).copyWith(
        primary: YushiColors.cobalt,
        onPrimary: Colors.white,
        surface: YushiColors.paper,
        onSurface: YushiColors.ink,
        outline: YushiColors.rule,
        error: YushiColors.danger,
      );
  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: YushiColors.background,
    fontFamily: 'NotoSerifSC',
    textTheme: const TextTheme(
      headlineLarge: TextStyle(
        color: YushiColors.ink,
        fontSize: 35,
        height: 1.42,
      ),
      headlineMedium: TextStyle(
        color: YushiColors.ink,
        fontSize: 28,
        height: 1.4,
      ),
      titleLarge: TextStyle(color: YushiColors.ink, fontSize: 23, height: 1.45),
      titleMedium: TextStyle(
        color: YushiColors.ink,
        fontSize: 17,
        height: 1.5,
        fontWeight: FontWeight.w500,
      ),
      bodyLarge: TextStyle(color: YushiColors.ink, fontSize: 16, height: 1.65),
      bodyMedium: TextStyle(
        color: YushiColors.secondary,
        fontSize: 14,
        height: 1.65,
      ),
      bodySmall: TextStyle(
        color: YushiColors.secondary,
        fontSize: 12,
        height: 1.5,
      ),
      labelLarge: TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
    ),
    dividerColor: YushiColors.rule,
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: YushiColors.paper,
      hintStyle: const TextStyle(color: YushiColors.secondary),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: YushiColors.rule),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: YushiColors.rule),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: YushiColors.cobalt, width: 1.5),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size(48, 50),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    ),
  );
}
