import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

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

class YushiPalette {
  const YushiPalette(this.dark);
  final bool dark;
  Color get cobalt => dark ? const Color(0xFF91ADFF) : YushiColors.cobalt;
  Color get ink => dark ? const Color(0xFFE8EDF6) : YushiColors.ink;
  Color get secondary => dark ? const Color(0xFFB3BFD2) : YushiColors.secondary;
  Color get background =>
      dark ? const Color(0xFF11151D) : YushiColors.background;
  Color get paper => dark ? const Color(0xFF1B2230) : YushiColors.paper;
  Color get focus => dark ? const Color(0xFF293956) : YushiColors.focus;
  Color get rule => dark ? const Color(0xFF39465C) : YushiColors.rule;
  Color get success => dark ? const Color(0xFF7CD5B0) : YushiColors.success;
  Color get danger => dark ? const Color(0xFFFFAAA2) : YushiColors.danger;
}

extension YushiContextColors on BuildContext {
  YushiPalette get colors =>
      YushiPalette(Theme.of(this).brightness == Brightness.dark);
}

ThemeData buildYushiTheme({Brightness brightness = Brightness.light}) {
  final colors = YushiPalette(brightness == Brightness.dark);
  final scheme =
      ColorScheme.fromSeed(
        seedColor: colors.cobalt,
        brightness: brightness,
        surface: colors.paper,
      ).copyWith(
        primary: colors.cobalt,
        onPrimary: brightness == Brightness.dark
            ? const Color(0xFF14213C)
            : Colors.white,
        surface: colors.paper,
        onSurface: colors.ink,
        outline: colors.rule,
        error: colors.danger,
      );
  return ThemeData(
    useMaterial3: true,
    brightness: brightness,
    bottomSheetTheme: BottomSheetThemeData(backgroundColor: colors.paper),
    colorScheme: scheme,
    scaffoldBackgroundColor: colors.background,
    appBarTheme: AppBarTheme(
      systemOverlayStyle: brightness == Brightness.dark
          ? SystemUiOverlayStyle.light
          : SystemUiOverlayStyle.dark,
    ),
    textTheme: TextTheme(
      headlineLarge: TextStyle(
        color: colors.ink,
        fontSize: 36,
        height: 1.25,
        fontWeight: FontWeight.w700,
      ),
      headlineMedium: TextStyle(
        color: colors.ink,
        fontSize: 27,
        height: 1.3,
        fontWeight: FontWeight.w700,
      ),
      titleLarge: TextStyle(
        color: colors.ink,
        fontSize: 22,
        height: 1.35,
        fontWeight: FontWeight.w700,
      ),
      titleMedium: TextStyle(
        color: colors.ink,
        fontSize: 18,
        height: 1.4,
        fontWeight: FontWeight.w600,
      ),
      bodyLarge: TextStyle(
        color: colors.ink,
        fontSize: 17,
        height: 1.5,
        fontWeight: FontWeight.w600,
      ),
      bodyMedium: TextStyle(
        color: colors.secondary,
        fontSize: 15,
        height: 1.5,
        fontWeight: FontWeight.w500,
      ),
      bodySmall: TextStyle(
        color: colors.secondary,
        fontSize: 13,
        height: 1.4,
        fontWeight: FontWeight.w500,
      ),
      labelLarge: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
    ),
    dividerColor: colors.rule,
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: colors.paper,
      hintStyle: TextStyle(
        color: colors.secondary,
        fontWeight: FontWeight.w500,
      ),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: colors.rule),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: colors.rule),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: colors.cobalt, width: 1.5),
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
              ? colors.cobalt
              : colors.secondary,
          fontSize: 13,
          fontWeight: states.contains(WidgetState.selected)
              ? FontWeight.w700
              : FontWeight.w600,
        ),
      ),
    ),
  );
}
