import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/theme/tautin_theme.dart';
import '../../../../shared/widgets/tauti_mascot.dart';
import '../../domain/gamification_summary.dart';

/// The `.mcard` from the HTML mockup: level pill, title, speech bubble,
/// XP bar, `Misi` chip and the Tauti mascot placed to the left.
///
/// Tapping the card body toggles `TautiMood.poke` and triggers
/// `HapticFeedback.lightImpact`.  The `Misi` pill opens [onMisiTap].
class TautiMascotCard extends StatefulWidget {
  const TautiMascotCard({
    super.key,
    required this.summary,
    this.onMisiTap,
  });

  final GamificationSummary summary;
  final VoidCallback? onMisiTap;

  @override
  State<TautiMascotCard> createState() => _TautiMascotCardState();
}

class _TautiMascotCardState extends State<TautiMascotCard> {
  TautiMood _mood = TautiMood.idle;

  void _poke() {
    HapticFeedback.lightImpact();
    setState(() => _mood = TautiMood.poke);
    Future<void>.delayed(const Duration(milliseconds: 1200), () {
      if (mounted) {
        setState(() => _mood = TautiMood.idle);
      }
    });
  }

  TautiOutfit get _outfit {
    final int lvl = widget.summary.level;
    // Use the mascot-level mapping: curator ≥5, master ≥10, legend ≥20.
    if (lvl >= TautiOutfit.legend.level) {
      return TautiOutfit.legend;
    }
    if (lvl >= TautiOutfit.master.level) {
      return TautiOutfit.master;
    }
    if (lvl >= TautiOutfit.curator.level) {
      return TautiOutfit.curator;
    }
    return TautiOutfit.none;
  }

  String get _speechText {
    final int streakDays = widget.summary.streakDays;
    if (streakDays >= 7) {
      return 'Streak $streakDays hari! Kamu keren banget! 🔥';
    }
    if (streakDays >= 3) {
      return 'Streak $streakDays hari! Terus semangat! 💪';
    }
    return 'Halo! Ada tautan baru hari ini?';
  }

  @override
  Widget build(BuildContext context) {
    final GamificationSummary s = widget.summary;
    final bool isDark = Theme.of(context).brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
      child: GestureDetector(
        onTap: _poke,
        child: Container(
          height: 196,
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            color: isDark ? TautinColors.darkCard : TautinColors.iceBlue,
            borderRadius: BorderRadius.circular(32),
          ),
          child: Stack(
            children: <Widget>[
              // Decorative tautin flower (top-right, 55 % opacity)
              Positioned(
                right: -58,
                top: -58,
                child: Opacity(
                  opacity: 0.55,
                  child: SizedBox(
                    width: 210,
                    height: 210,
                    child: CustomPaint(
                      painter: _TautinDecorPainter(
                        color: isDark
                            ? TautinColors.mintAccent
                            : TautinColors.mintAccent,
                      ),
                    ),
                  ),
                ),
              ),

              // Mascot (left-aligned, bottom: -6)
              Positioned(
                left: 6,
                bottom: -6,
                child: SizedBox(
                  width: 130,
                  height: 160,
                  child: TautiMascot(
                    mood: _mood,
                    outfit: _outfit,
                  ),
                ),
              ),

              // Right content area
              Positioned(
                left: 146,
                right: 14,
                top: 14,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    // Level pill + title
                    Row(
                      children: <Widget>[
                        Container(
                          height: 26,
                          padding: const EdgeInsets.symmetric(horizontal: 11),
                          decoration: BoxDecoration(
                            color: TautinColors.brandTeal,
                            borderRadius: BorderRadius.circular(13),
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            'Lv ${s.level}',
                            style: const TextStyle(
                              fontFamily: 'Plus Jakarta Sans',
                              fontWeight: FontWeight.w800,
                              fontSize: 12.5,
                              color: TautinColors.mintAccent,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Flexible(
                          child: Text(
                            s.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w600,
                              color: isDark
                                  ? TautinColors.textPrimaryDark
                                  : TautinColors.brandTeal,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),

                    // Speech bubble
                    _SpeechBubble(
                      text: _speechText,
                      isDark: isDark,
                    ),
                    const SizedBox(height: 12),

                    // XP progress bar
                    ClipRRect(
                      borderRadius: BorderRadius.circular(5),
                      child: SizedBox(
                        height: 10,
                        child: LinearProgressIndicator(
                          value: s.progressFraction,
                          backgroundColor: isDark
                              ? Colors.white.withValues(alpha: 0.15)
                              : Colors.white.withValues(alpha: 0.7),
                          valueColor: AlwaysStoppedAnimation<Color>(
                            isDark
                                ? TautinColors.mintAccent
                                : TautinColors.brandTeal,
                          ),
                          borderRadius: BorderRadius.circular(5),
                        ),
                      ),
                    ),
                    const SizedBox(height: 5),

                    // XP text + Misi chip
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: <Widget>[
                        Text(
                          '${s.currentStepXp} / ${s.stepTarget} XP',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: isDark
                                ? TautinColors.textSecondaryDark
                                : TautinColors.brandTeal,
                          ),
                        ),
                        GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onTap: () {
                            HapticFeedback.lightImpact();
                            widget.onMisiTap?.call();
                          },
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              vertical: 6,
                              horizontal: 4,
                            ),
                            child: Container(
                              height: 22,
                              padding: const EdgeInsets.only(
                                  left: 10, right: 8),
                              decoration: BoxDecoration(
                                color: TautinColors.brandTeal,
                                borderRadius: BorderRadius.circular(11),
                              ),
                              child: const Row(
                                mainAxisSize: MainAxisSize.min,
                                children: <Widget>[
                                  Text(
                                    'Misi',
                                    style: TextStyle(
                                      fontFamily: 'Plus Jakarta Sans',
                                      fontWeight: FontWeight.w800,
                                      fontSize: 10.5,
                                      letterSpacing: 0.2,
                                      color: TautinColors.mintAccent,
                                    ),
                                  ),
                                  Icon(
                                    Icons.chevron_right_rounded,
                                    size: 14,
                                    color: TautinColors.mintAccent,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The cream-coloured speech bubble with a 45-degree arrow pointing left.
class _SpeechBubble extends StatelessWidget {
  const _SpeechBubble({required this.text, required this.isDark});

  final String text;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    final Color bg =
        isDark ? TautinColors.darkBackground : TautinColors.creamBackground;

    return Stack(
      clipBehavior: Clip.none,
      children: <Widget>[
        // Arrow (left: -6, top: 20)
        Positioned(
          left: -6,
          top: 20,
          child: Transform.rotate(
            angle: math.pi / 4,
            child: Container(
              width: 14,
              height: 14,
              decoration: BoxDecoration(
                color: bg,
                borderRadius: BorderRadius.circular(3),
              ),
            ),
          ),
        ),
        // Bubble body
        Container(
          width: double.infinity,
          constraints: const BoxConstraints(minHeight: 52),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(18),
          ),
          child: Text(
            text,
            style: TextStyle(
              fontSize: 13,
              height: 1.4,
              fontWeight: FontWeight.w500,
              color: isDark
                  ? TautinColors.textPrimaryDark
                  : TautinColors.brandTeal,
            ),
          ),
        ),
      ],
    );
  }
}

/// Decorative tautin flower (circles with 't' glyph).
class _TautinDecorPainter extends CustomPainter {
  _TautinDecorPainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final double cx = size.width / 2;
    final double cy = size.height / 2;
    final double scale = size.width / 100;
    final Paint paint = Paint()..color = color;

    // Central circle
    canvas.drawCircle(Offset(cx, cy), 34 * scale, paint);

    // 8 satellite circles (radius 17, orbit radius 30)
    const int count = 8;
    for (int i = 0; i < count; i++) {
      final double angle = (i / count) * math.pi * 2 - math.pi / 2;
      canvas.drawCircle(
        Offset(cx + 30 * scale * math.cos(angle),
            cy + 30 * scale * math.sin(angle)),
        17 * scale,
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(_TautinDecorPainter oldDelegate) =>
      color != oldDelegate.color;
}
