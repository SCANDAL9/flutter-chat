import 'package:flutter/material.dart';

/// Exact design tokens mirrored from UmlStudio's `@umlstudio/ui` Design System.
/// References:
/// - `packages/ui/src/styles/tokens/primitives.css`
/// - `packages/ui/src/styles/tokens/semantics.css`
/// - `packages/ui/src/styles/tokens/metrics.css`
class UmlStudioTokens {
  UmlStudioTokens._();

  // =========================================================================
  // Brand Palette (Coolors Specification)
  // =========================================================================
  static const Color dodgerBlue = Color(0xFF3590F3);   // --color-palette-dodger-blue (Brand Primary)
  static const Color deepSkyBlue = Color(0xFF62BFED);  // --color-palette-deep-sky (Brand Accent)
  static const Color babyBlue = Color(0xFF8FB8ED);     // --color-palette-baby-blue
  static const Color periwinkle = Color(0xFFC2BBF0);   // --color-palette-periwinkle
  static const Color lavenderVeil = Color(0xFFF1E3F3); // --color-palette-lavender-veil

  // =========================================================================
  // Dark Theme Tokens ("Deep Obsidian Technical Precision Studio")
  // =========================================================================
  static const Color darkBackground = Color(0xFF0B0F19);        // --umlstudio-background
  static const Color darkBackgroundVariant = Color(0xFF101626); // --umlstudio-background-variant
  static const Color darkSurface = Color(0xFF151D2E);           // --umlstudio-surface (Raised Cards)
  static const Color darkSurfaceSunken = Color(0xFF0C101A);     // --umlstudio-surface-sunken
  static const Color darkSurfaceHover = Color(0xFF1E293F);      // --umlstudio-surface-hover
  static const Color darkSurfaceActive = Color(0xFF273550);     // --umlstudio-surface-active

  // Typography & Foreground (Dark)
  static const Color darkForeground = Color(0xFFF8FAFC);       // --umlstudio-foreground
  static const Color darkTextSecondary = Color(0xFFCBD5E1);    // --umlstudio-text-secondary
  static const Color darkTextMuted = Color(0xFF94A3B8);        // --umlstudio-text-muted
  static const Color darkGray = Color(0xFF1E293B);             // --umlstudio-gray
  static const Color darkGrayVariant = Color(0xFF475569);      // --umlstudio-gray-variant

  // Technical Borders (Dark)
  static const Color darkBorder = Color(0xFF243046);           // --umlstudio-border
  static const Color darkBorderSubtle = Color(0xFF192233);     // --umlstudio-border-subtle
  static const Color darkBorderStrong = Color(0xFF3B4C68);     // --umlstudio-border-strong

  // Status & Functional Colors (Dark)
  static const Color success = Color(0xFF34D399);              // --umlstudio-success (Emerald 400)
  static const Color warning = Color(0xFFFBBF24);              // --umlstudio-warning (Amber 400)
  static const Color danger = Color(0xFFF87171);               // --umlstudio-danger (Red 400)
  static const Color info = Color(0xFF38BDF8);                 // --umlstudio-info (Sky 400)

  // Canvas Grid Dots
  static const Color darkGridDot = Color(0x1462BFED);          // rgba(98, 191, 237, 0.08)

  // =========================================================================
  // Metrics & Radii
  // =========================================================================
  static const double radiusXs = 4.0;
  static const double radiusSm = 6.0;
  static const double radiusMd = 8.0;
  static const double radiusLg = 12.0;
  static const double radiusXl = 16.0;
  static const double radiusFull = 9999.0;
}
