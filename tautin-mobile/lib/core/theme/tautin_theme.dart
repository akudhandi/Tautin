import 'dart:io';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Tautin brand palette based on the official editorial mockup design.
///
/// Deep Spruce/Teal (`#204654`) + Soft Neon Mint (`#CAFFA6`) + Warm Cream (`#F7F9E1`).
abstract final class TautinColors {
  // Mockup Core Palette
  static const Color brandTeal = Color(0xFF204654);
  static const Color mintAccent = Color(0xFFCAFFA6);
  static const Color creamBackground = Color(0xFFF7F9E1);
  static const Color iceBlue = Color(0xFFA9E0F1);
  static const Color mistTeal = Color(0xFFD6E6EA);
  static const Color darkTeal = Color(0xFF16323D);
  static const Color softBorder = Color(0xFFB9CDB0);

  // Backward-compatible Brand Aliases
  static const Color primaryIndigo = brandTeal;
  static const Color aiViolet = mintAccent;

  // Light mode (Warm Cream & Clean Cards)
  static const Color lightBackground = creamBackground;
  static const Color lightCard = Color(0xFFFFFFFF);
  static const Color textPrimaryLight = brandTeal;
  static const Color textSecondaryLight = Color(0xFF5A7580);
  static const Color aiSummaryBoxLight = Color(0xFFFFFFFF);
  static const Color aiSummaryBorderLight = mistTeal;

  // Dark mode (Night Spruce) — values taken from the `.dk*` dark screens:
  // background `#16323D`, card `#1E3B47`, hairline border `#2E5563`,
  // secondary text `#A9C6D0`.
  static const Color darkBackground = darkTeal;
  static const Color darkCard = Color(0xFF1E3B47);
  static const Color darkBorder = Color(0xFF2E5563);
  static const Color textPrimaryDark = creamBackground;
  static const Color textSecondaryDark = Color(0xFFA9C6D0);
  static const Color aiSummaryBoxDark = darkTeal;
  static const Color aiSummaryBorderDark = darkBorder;

  // Semantic
  static const Color successGreen = Color(0xFF10B981);
  static const Color errorRed = Color(0xFFEF4444);
  static const Color warningAmber = Color(0xFFF59E0B);
}

enum _FontKind { heading, body, editorialSerif }

/// Builds light and dark [ThemeData] for the whole app.
///
/// Typography: `Plus Jakarta Sans` for titles/badges, `Instrument Serif` (italic)
/// for editorial slogans, and `Inter` for body/notes.
abstract final class TautinTheme {
  static bool get _fontsEnabled =>
      !Platform.environment.containsKey('FLUTTER_TEST');

  /// Quick helper for Instrument Serif italic headlines (e.g. slogans).
  static TextStyle editorialSerif({
    double fontSize = 36,
    Color color = TautinColors.brandTeal,
    FontWeight fontWeight = FontWeight.w400,
  }) {
    if (!_fontsEnabled) {
      return TextStyle(
        fontStyle: FontStyle.italic,
        fontSize: fontSize,
        color: color,
        fontWeight: fontWeight,
      );
    }
    return GoogleFonts.instrumentSerif(
      fontStyle: FontStyle.italic,
      fontSize: fontSize,
      color: color,
      fontWeight: fontWeight,
    );
  }

  /// Quick helper for Plus Jakarta Sans headings.
  static TextStyle jakartaHeading({
    double fontSize = 28,
    Color color = TautinColors.brandTeal,
    FontWeight fontWeight = FontWeight.w800,
    double? letterSpacing = -0.025,
  }) {
    if (!_fontsEnabled) {
      return TextStyle(
        fontSize: fontSize,
        color: color,
        fontWeight: fontWeight,
        letterSpacing: letterSpacing,
      );
    }
    return GoogleFonts.plusJakartaSans(
      fontSize: fontSize,
      color: color,
      fontWeight: fontWeight,
      letterSpacing: letterSpacing,
    );
  }

  /// Quick helper for Inter body text.
  static TextStyle interBody({
    double fontSize = 14,
    Color color = TautinColors.brandTeal,
    FontWeight fontWeight = FontWeight.w400,
  }) {
    if (!_fontsEnabled) {
      return TextStyle(
        fontSize: fontSize,
        color: color,
        fontWeight: fontWeight,
      );
    }
    return GoogleFonts.inter(
      fontSize: fontSize,
      color: color,
      fontWeight: fontWeight,
    );
  }

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
      seedColor: TautinColors.brandTeal,
      brightness: brightness,
      surface: card,
    );

    final TextTheme headings = _headingTextTheme(textPrimary);
    final TextTheme bodyDefaults = _bodyTextTheme(textPrimary, textSecondary);
    final TextTheme merged = headings.merge(bodyDefaults);

    final bool lightMode = brightness == Brightness.light;

    final OutlinedBorder buttonShape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(16),
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
          weight: FontWeight.w700,
          color: textPrimary,
        ),
      ),
      cardTheme: CardThemeData(
        color: card,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: textSecondary.withValues(alpha: 0.16)),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: inputFill,
        hintStyle: _font(_FontKind.body, size: 14, color: textSecondary),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: textSecondary.withValues(alpha: 0.24)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: textSecondary.withValues(alpha: 0.24)),
        ),
        focusedBorder: const OutlineInputBorder(
          borderRadius: BorderRadius.all(Radius.circular(16)),
          borderSide: BorderSide(color: TautinColors.brandTeal, width: 1.6),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor:
            lightMode ? TautinColors.brandTeal : TautinColors.darkCard,
        contentTextStyle: _font(
          _FontKind.body,
          size: 13.5,
          color: TautinColors.creamBackground,
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: card,
        selectedColor: TautinColors.mintAccent,
        side: BorderSide(color: textSecondary.withValues(alpha: 0.25)),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        labelStyle: _font(_FontKind.body, size: 13, color: textPrimary),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: TautinColors.brandTeal,
          foregroundColor: TautinColors.creamBackground,
          minimumSize: const Size.fromHeight(52),
          textStyle: _font(_FontKind.heading, size: 15.5, weight: FontWeight.w700),
          shape: buttonShape,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: TautinColors.brandTeal,
          minimumSize: const Size.fromHeight(50),
          side: const BorderSide(color: TautinColors.brandTeal),
          textStyle: _font(_FontKind.heading, size: 15, weight: FontWeight.w700),
          shape: buttonShape,
        ),
      ),
    );
  }

  static TextTheme _headingTextTheme(Color primary) {
    return TextTheme(
      displayLarge: _font(_FontKind.heading, size: 40, weight: FontWeight.w800, color: primary),
      displayMedium: _font(_FontKind.heading, size: 32, weight: FontWeight.w800, color: primary),
      displaySmall: _font(_FontKind.heading, size: 28, weight: FontWeight.w700, color: primary),
      headlineMedium: _font(_FontKind.heading, size: 24, weight: FontWeight.w700, color: primary),
      headlineSmall: _font(_FontKind.heading, size: 20, weight: FontWeight.w700, color: primary),
      titleLarge: _font(_FontKind.heading, size: 18, weight: FontWeight.w700, color: primary),
      titleMedium: _font(_FontKind.heading, size: 16, weight: FontWeight.w600, color: primary),
      titleSmall: _font(_FontKind.heading, size: 14, weight: FontWeight.w600, color: primary),
    );
  }

  static TextTheme _bodyTextTheme(Color primary, Color secondary) {
    return TextTheme(
      bodyLarge: _font(_FontKind.body, size: 16, color: primary),
      bodyMedium: _font(_FontKind.body, size: 14, color: primary),
      bodySmall: _font(_FontKind.body, size: 12.5, color: secondary),
      labelLarge: _font(_FontKind.heading, size: 14, weight: FontWeight.w700, color: primary),
      labelMedium: _font(_FontKind.body, size: 12, weight: FontWeight.w600, color: primary),
      labelSmall: _font(_FontKind.body, size: 11, color: secondary),
    );
  }

  static TextStyle _font(
    _FontKind kind, {
    required double size,
    FontWeight weight = FontWeight.w400,
    Color? color,
  }) {
    if (!_fontsEnabled) {
      return TextStyle(fontSize: size, fontWeight: weight, color: color);
    }
    switch (kind) {
      case _FontKind.heading:
        return GoogleFonts.plusJakartaSans(
          fontSize: size,
          fontWeight: weight,
          color: color,
        );
      case _FontKind.body:
        return GoogleFonts.inter(
          fontSize: size,
          fontWeight: weight,
          color: color,
        );
      case _FontKind.editorialSerif:
        return GoogleFonts.instrumentSerif(
          fontStyle: FontStyle.italic,
          fontSize: size,
          fontWeight: weight,
          color: color,
        );
    }
  }
}

/// Custom painter for the 9-circle Tautin flower logo with 't' center.
class TautinFlowerPainter extends CustomPainter {
  const TautinFlowerPainter({
    this.fillColor = TautinColors.mintAccent,
    this.letterColor = TautinColors.brandTeal,
  });

  final Color fillColor;
  final Color letterColor;

  @override
  void paint(Canvas canvas, Size size) {
    final Paint paint = Paint()
      ..color = fillColor
      ..style = PaintingStyle.fill;

    final double scale = size.width / 100.0;
    canvas.save();
    canvas.scale(scale, scale);

    // Center circle
    canvas.drawCircle(const Offset(50, 50), 34, paint);

    // 8 Outer petals
    const List<Offset> outerOffsets = <Offset>[
      Offset(80, 50),
      Offset(71.2, 71.2),
      Offset(50, 80),
      Offset(28.8, 71.2),
      Offset(20, 50),
      Offset(28.8, 28.8),
      Offset(50, 20),
      Offset(71.2, 28.8),
    ];

    for (final Offset pt in outerOffsets) {
      canvas.drawCircle(pt, 17, paint);
    }

    // Letter 't'
    final TextPainter tp = TextPainter(
      text: TextSpan(
        text: 't',
        style: TextStyle(
          color: letterColor,
          fontSize: 46,
          fontWeight: FontWeight.w800,
          fontFamily: 'Plus Jakarta Sans',
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();

    tp.paint(canvas, Offset(50 - tp.width / 2, 50 - tp.height / 2 - 2));

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant TautinFlowerPainter oldDelegate) =>
      oldDelegate.fillColor != fillColor ||
      oldDelegate.letterColor != letterColor;
}

/// Reusable brand logo icon widget.
class TautinLogoIcon extends StatelessWidget {
  const TautinLogoIcon({
    super.key,
    this.size = 36,
    this.petalColor = TautinColors.mintAccent,
    this.letterColor = TautinColors.brandTeal,
  });

  final double size;
  final Color petalColor;
  final Color letterColor;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: TautinFlowerPainter(
          fillColor: petalColor,
          letterColor: letterColor,
        ),
      ),
    );
  }
}

/// Brand logo row with icon and 'tautin' wordmark.
class TautinBrandHeader extends StatelessWidget {
  const TautinBrandHeader({super.key, this.iconSize = 34, this.fontSize = 22});

  final double iconSize;
  final double fontSize;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        TautinLogoIcon(size: iconSize),
        const SizedBox(width: 8),
        Text(
          'tautin',
          style: TautinTheme.jakartaHeading(
            fontSize: fontSize,
            fontWeight: FontWeight.w800,
            color: TautinColors.brandTeal,
            letterSpacing: -0.03,
          ),
        ),
      ],
    );
  }
}
