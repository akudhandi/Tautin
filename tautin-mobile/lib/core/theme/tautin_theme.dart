import 'dart:io';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Tautin brand palette (see PRD section 5.1).
abstract final class TautinColors {
  // Brand
  static const Color primaryIndigo = Color(0xFF4F46E5);
  static const Color aiViolet = Color(0xFF8B5CF6);

  // Light mode
  static const Color lightBackground = Color(0xFFF8FAFC);
  static const Color lightCard = Color(0xFFFFFFFF);
  static const Color textPrimaryLight = Color(0xFF0F172A);
  static const Color textSecondaryLight = Color(0xFF64748B);
  static const Color aiSummaryBoxLight = Color(0xFFF5F3FF);
  static const Color aiSummaryBorderLight = Color(0xFFDDD6FE);

  // Dark mode
  static const Color darkBackground = Color(0xFF0F172A);
  static const Color darkCard = Color(0xFF1E293B);
  static const Color textPrimaryDark = Color(0xFFF8FAFC);
  static const Color textSecondaryDark = Color(0xFF94A3B8);
  static const Color aiSummaryBoxDark = Color(0xFF1E1B4B);
  static const Color aiSummaryBorderDark = Color(0xFF4C1D95);

  // Semantic
  static const Color successGreen = Color(0xFF16A34A);
  static const Color errorRed = Color(0xFFDC2626);
  static const Color warningAmber = Color(0xFFF59E0B);
}

enum _FontKind { heading, body }

/// Builds light and dark [ThemeData] for the whole app.
///
/// Typography: `Plus Jakarta Sans` for headings and `Inter` for body text.
/// Fonts are fetched from Google Fonts at runtime; during tests
/// (`FLUTTER_TEST=1`) they are replaced by the default system font to keep
/// widget tests deterministic and offline.
abstract final class TautinTheme {
  static bool get _fontsEnabled => !Platform.environment.containsKey('FLUTTER_TEST');

  static ThemeData get light {
    return _base(
      brightness: Brightness.light,
      background: TautinColors.lightBackground,
      card: TautinColors.lightCard,
      textPrimary: TautinColors.textPrimaryLight,
      textSecondary: TautinColors.textSecondaryLight,
      inputFill: TautinColors.lightCard,
    );
  }

  static ThemeData get dark {
    return _base(
      brightness: Brightness.dark,
      background: TautinColors.darkBackground,
      card: TautinColors.darkCard,
      textPrimary: TautinColors.textPrimaryDark,
      textSecondary: TautinColors.textSecondaryDark,
      inputFill: TautinColors.darkCard,
    );
  }

  static ThemeData _base({
    required Brightness brightness,
    required Color background,
    required Color card,
    required Color textPrimary,
    required Color textSecondary,
    required Color inputFill,
  }) {
    final ColorScheme scheme = ColorScheme.fromSeed(
      seedColor: TautinColors.primaryIndigo,
      brightness: brightness,
      surface: card,
    );

    final TextTheme headings = _headingTextTheme(textPrimary);
    final TextTheme bodyDefaults = _bodyTextTheme(textPrimary, textSecondary);
    final TextTheme merged = headings.merge(bodyDefaults);

    final bool lightMode = brightness == Brightness.light;

    final OutlinedBorder buttonShape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(12),
    );

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: scheme,
      scaffoldBackgroundColor: background,
      textTheme: merged,
      appBarTheme: AppBarTheme(
        backgroundColor: background,
        foregroundColor: textPrimary,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: _font(
          _FontKind.heading,
          size: 19,
          weight: FontWeight.w600,
          color: textPrimary,
        ),
      ),
      cardTheme: CardThemeData(
        color: card,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: textSecondary.withValues(alpha: 0.18)),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: inputFill,
        hintStyle: _font(_FontKind.body, size: 14, color: textSecondary),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: textSecondary.withValues(alpha: 0.3)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: textSecondary.withValues(alpha: 0.3)),
        ),
        focusedBorder: const OutlineInputBorder(
          borderRadius: BorderRadius.all(Radius.circular(12)),
          borderSide: BorderSide(color: TautinColors.primaryIndigo, width: 1.6),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor:
            lightMode ? TautinColors.textPrimaryLight : TautinColors.darkCard,
        contentTextStyle: _font(
          _FontKind.body,
          size: 13.5,
          color:
              lightMode
                  ? TautinColors.textPrimaryDark
                  : TautinColors.textPrimaryLight,
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: card,
        selectedColor: TautinColors.primaryIndigo.withValues(alpha: 0.14),
        side: BorderSide(color: textSecondary.withValues(alpha: 0.28)),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        labelStyle: _font(_FontKind.body, size: 13, color: textPrimary),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: TautinColors.primaryIndigo,
          foregroundColor: Colors.white,
          minimumSize: const Size.fromHeight(52),
          textStyle: _font(_FontKind.body, size: 15.5, weight: FontWeight.w600),
          shape: buttonShape,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: TautinColors.primaryIndigo,
          minimumSize: const Size.fromHeight(50),
          side: const BorderSide(color: TautinColors.primaryIndigo),
          textStyle: _font(_FontKind.body, size: 15, weight: FontWeight.w600),
          shape: buttonShape,
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor:
              lightMode ? TautinColors.primaryIndigo : TautinColors.aiViolet,
          textStyle: _font(_FontKind.body, size: 14, weight: FontWeight.w600),
        ),
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: TautinColors.aiViolet,
        linearTrackColor: textSecondary.withValues(alpha: 0.2),
      ),
      dividerTheme: DividerThemeData(
        color: textSecondary.withValues(alpha: 0.18),
      ),
    );
  }

  static TextTheme _headingTextTheme(Color primary) {
    return TextTheme(
      displaySmall: _font(_FontKind.heading, size: 32, weight: FontWeight.w700, color: primary),
      headlineMedium: _font(_FontKind.heading, size: 26, weight: FontWeight.w700, color: primary),
      headlineSmall: _font(_FontKind.heading, size: 22, weight: FontWeight.w700, color: primary),
      titleLarge: _font(_FontKind.heading, size: 19, weight: FontWeight.w600, color: primary),
      titleMedium: _font(_FontKind.heading, size: 16.5, weight: FontWeight.w600, color: primary),
      titleSmall: _font(_FontKind.heading, size: 14.5, weight: FontWeight.w600, color: primary),
    );
  }

  static TextTheme _bodyTextTheme(Color primary, Color secondary) {
    return TextTheme(
      bodyLarge: _font(_FontKind.body, size: 15, color: primary, height: 1.5),
      bodyMedium: _font(_FontKind.body, size: 14, color: primary, height: 1.45),
      bodySmall: _font(_FontKind.body, size: 12.5, color: secondary, height: 1.4),
      labelLarge: _font(_FontKind.body, size: 14, weight: FontWeight.w600, color: primary),
      labelMedium: _font(_FontKind.body, size: 12.5, color: secondary),
      labelSmall: _font(_FontKind.body, size: 11, color: secondary),
    );
  }

  static TextStyle _font(
    _FontKind kind, {
    double? size,
    FontWeight? weight,
    Color? color,
    double? height,
    double? letterSpacing,
  }) {
    if (!_fontsEnabled) {
      return TextStyle(
        fontSize: size,
        fontWeight: weight,
        color: color,
        height: height,
        letterSpacing: letterSpacing,
      );
    }

    if (kind == _FontKind.heading) {
      return GoogleFonts.plusJakartaSans(
        fontSize: size,
        fontWeight: weight,
        color: color,
        height: height,
        letterSpacing: letterSpacing,
      );
    }
    return GoogleFonts.inter(
      fontSize: size,
      fontWeight: weight,
      color: color,
      height: height,
      letterSpacing: letterSpacing,
    );
  }
}
