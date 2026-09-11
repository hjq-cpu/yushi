import 'package:flutter/material.dart';

abstract final class YushiColors {
  static const cobalt = Color(0xFF2F5CF3);
  static const ink = Color(0xFF18243C);
  static const secondary = Color(0xFF46536B);
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
    textTheme: const TextTheme(
      headlineLarge: TextStyle(
        color: YushiColors.ink,
        fontSize: 36,
        height: 1.25,
        fontWeight: FontWeight.w700,
      ),
      headlineMedium: TextStyle(
        color: YushiColors.ink,
        fontSize: 27,
        height: 1.3,
        fontWeight: FontWeight.w700,
      ),
      titleLarge: TextStyle(
        color: YushiColors.ink,
        fontSize: 22,
        height: 1.35,
        fontWeight: FontWeight.w700,
      ),
      titleMedium: TextStyle(
        color: YushiColors.ink,
        fontSize: 18,
        height: 1.4,
        fontWeight: FontWeight.w600,
      ),
      bodyLarge: TextStyle(
        color: YushiColors.ink,
        fontSize: 17,
        height: 1.5,
        fontWeight: FontWeight.w600,
      ),
      bodyMedium: TextStyle(
        color: YushiColors.secondary,
        fontSize: 15,
        height: 1.5,
        fontWeight: FontWeight.w500,
      ),
      bodySmall: TextStyle(
        color: YushiColors.secondary,
        fontSize: 13,
        height: 1.4,
        fontWeight: FontWeight.w500,
      ),
      labelLarge: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
    ),
    dividerColor: YushiColors.rule,
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: YushiColors.paper,
      hintStyle: const TextStyle(
        color: YushiColors.secondary,
        fontWeight: FontWeight.w500,
      ),
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
        textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
      ),
    ),
    navigationBarTheme: NavigationBarThemeData(
      labelTextStyle: WidgetStateProperty.resolveWith(
        (states) => TextStyle(
          color: states.contains(WidgetState.selected)
              ? YushiColors.cobalt
              : YushiColors.secondary,
          fontSize: 13,
          fontWeight: states.contains(WidgetState.selected)
              ? FontWeight.w700
              : FontWeight.w600,
        ),
      ),
    ),
  );
}
