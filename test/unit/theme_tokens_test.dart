import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:umlstudio_mobile/core/theme/umlstudio_tokens.dart';
import 'package:umlstudio_mobile/core/theme/umlstudio_theme.dart';

void main() {
  group('UmlStudio Design Tokens Integrity Tests', () {
    test('Brand Palette tokens match Coolors / UmlStudio specifications', () {
      // #3590f3 -> 0xFF3590F3 (Dodger Blue)
      expect(UmlStudioTokens.dodgerBlue, equals(const Color(0xFF3590F3)));

      // #62bfed -> 0xFF62BFED (Deep Sky Blue)
      expect(UmlStudioTokens.deepSkyBlue, equals(const Color(0xFF62BFED)));

      // #8fb8ed -> 0xFF8FB8ED (Baby Blue)
      expect(UmlStudioTokens.babyBlue, equals(const Color(0xFF8FB8ED)));

      // #c2bbf0 -> 0xFFC2BBF0 (Periwinkle)
      expect(UmlStudioTokens.periwinkle, equals(const Color(0xFFC2BBF0)));

      // #f1e3f3 -> 0xFFF1E3F3 (Lavender Veil)
      expect(UmlStudioTokens.lavenderVeil, equals(const Color(0xFFF1E3F3)));
    });

    test('Dark Theme tokens match Deep Obsidian Technical Studio specification', () {
      // #0b0f19 -> 0xFF0B0F19 (Dark Background)
      expect(UmlStudioTokens.darkBackground, equals(const Color(0xFF0B0F19)));

      // #151d2e -> 0xFF151D2E (Dark Surface Raised)
      expect(UmlStudioTokens.darkSurface, equals(const Color(0xFF151D2E)));

      // #0c101a -> 0xFF0C101A (Dark Surface Sunken)
      expect(UmlStudioTokens.darkSurfaceSunken, equals(const Color(0xFF0C101A)));

      // #243046 -> 0xFF243046 (Dark Border)
      expect(UmlStudioTokens.darkBorder, equals(const Color(0xFF243046)));

      // #f8fafc -> 0xFFF8FAFC (Dark Foreground)
      expect(UmlStudioTokens.darkForeground, equals(const Color(0xFFF8FAFC)));
    });

    test('UmlStudioTheme configures ThemeData with exact design system surfaces', () {
      final theme = UmlStudioTheme.darkTheme;

      expect(theme.brightness, equals(Brightness.dark));
      expect(theme.scaffoldBackgroundColor, equals(UmlStudioTokens.darkBackground));
      expect(theme.colorScheme.primary, equals(UmlStudioTokens.dodgerBlue));
      expect(theme.colorScheme.surface, equals(UmlStudioTokens.darkSurface));
    });
  });
}
