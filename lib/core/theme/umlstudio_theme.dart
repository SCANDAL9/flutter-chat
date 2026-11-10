import 'package:flutter/material.dart';
import 'umlstudio_tokens.dart';

class UmlStudioTheme {
  UmlStudioTheme._();

  static ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: UmlStudioTokens.darkBackground,
      colorScheme: const ColorScheme.dark(
        primary: UmlStudioTokens.dodgerBlue,
        onPrimary: Colors.white,
        secondary: UmlStudioTokens.deepSkyBlue,
        onSecondary: UmlStudioTokens.darkBackground,
        surface: UmlStudioTokens.darkSurface,
        onSurface: UmlStudioTokens.darkForeground,
        error: UmlStudioTokens.danger,
        onError: Colors.white,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: UmlStudioTokens.darkSurfaceSunken,
        foregroundColor: UmlStudioTokens.darkForeground,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        shape: Border(
          bottom: BorderSide(
            color: UmlStudioTokens.darkBorderSubtle,
            width: 1.0,
          ),
        ),
        titleTextStyle: TextStyle(
          color: UmlStudioTokens.darkForeground,
          fontSize: 16,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.2,
        ),
      ),
      cardTheme: CardThemeData(
        color: UmlStudioTokens.darkSurface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(UmlStudioTokens.radiusLg),
          side: const BorderSide(
            color: UmlStudioTokens.darkBorder,
            width: 1.0,
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: UmlStudioTokens.darkSurfaceSunken,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        hintStyle: const TextStyle(
          color: UmlStudioTokens.darkTextMuted,
          fontSize: 14,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(UmlStudioTokens.radiusFull),
          borderSide: const BorderSide(
            color: UmlStudioTokens.darkBorder,
            width: 1.0,
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(UmlStudioTokens.radiusFull),
          borderSide: const BorderSide(
            color: UmlStudioTokens.dodgerBlue,
            width: 1.5,
          ),
        ),
      ),
      dividerTheme: const DividerThemeData(
        color: UmlStudioTokens.darkBorderSubtle,
        thickness: 1.0,
        space: 1.0,
      ),
    );
  }
}
