import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/theme/tautin_theme.dart';

/// Moods of the Tauti mascot, mirroring the `.m-*` classes of the design
/// mockup (`m-idle`, `m-happy`, `m-think`, `m-read`, `m-cheer`, `m-sleep`,
/// `m-poke`).
enum TautiMood { idle, happy, think, read, cheer, sleep, poke }

/// Costumes the mascot can wear, mirroring the `COSTUMES` map of the mockup.
///
/// A costume is independent of the [TautiMood]: every mood can be combined with
/// every costume. [level] is the level at which the costume unlocks.
enum TautiOutfit {
  /// The plain mascot, no costume.
  none(0),

  /// Kurator Cilik — vest, glasses and a magnifying glass.
  curator(5),

  /// Master Tautan — short cape with clasps and a star medal.
  master(10),

  /// Legenda Tautin — long cape, crown and a sparkling aura.
  legend(20);

  const TautiOutfit(this.level);

  /// Level at which this costume unlocks.
  final int level;
}

/// The Tauti mascot, drawn straight from the geometry, transforms and
/// keyframes defined in `opendesign-tautin.html`.
///
/// The mockup renders a `viewBox="0 0 200 250"` SVG and animates it with CSS
/// keyframes (`breathe`, `breatheSleep`, `blink`, `linkWig`, `idleWave`,
/// `jump`, `shadowJump`, `tilt`, `wiggle`, `spin`, `cheerL/R`, `sparkPop`,
/// `fall`, `zfloat`, `capeSway`, `twinkle`, `medalPulse`). CSS is not
/// reproducible 1:1 in Flutter, so every phase below is re-implemented with a
/// dedicated [AnimationController] using the exact same timing values.
class TautiMascot extends StatefulWidget {
  const TautiMascot({
    super.key,
    this.mood = TautiMood.idle,
    this.outfit = TautiOutfit.none,
    this.width = 120,
    this.animate = true,
  });

  /// Which pose/behaviour the mascot should hold.
  final TautiMood mood;

  /// Costume worn on top of the base character.
  final TautiOutfit outfit;

  /// Rendered width. Height follows the 200:250 viewBox ratio.
  final double width;

  /// When `false`, the mascot is frozen on its first frame (useful for tests).
  final bool animate;

  /// Height for a given [width] following the mockup aspect ratio.
  static double heightFor(double width) => width * 250 / 200;

  @override
  State<TautiMascot> createState() => _TautiMascotState();
}

class _TautiMascotState extends State<TautiMascot>
    with TickerProviderStateMixin {
  late final AnimationController _breathe = _make(2800);
  late final AnimationController _blink = _make(4200);
  late final AnimationController _idleWave = _make(6000);
  late final AnimationController _jump = _make(950);
  late final AnimationController _shadow = _make(950);
  late final AnimationController _link = _make(3200);
  late final AnimationController _tilt = _make(1800);
  late final AnimationController _wiggle = _make(600);
  late final AnimationController _sleep = _make(4000);
  late final AnimationController _orbit = _make(2600);
  late final AnimationController _confetti = _make(1600);
  late final AnimationController _zzz = _make(2600);
  late final AnimationController _spark = _make(900);
  late final AnimationController _cheer = _make(400);
  late final AnimationController _cape = _make(4600);
  late final AnimationController _capeLong = _make(5800);
  late final AnimationController _twinkle = _make(2800);
  late final AnimationController _medal = _make(3600);

  late final List<AnimationController> _all = <AnimationController>[
    _breathe,
    _blink,
    _idleWave,
    _jump,
    _shadow,
    _link,
    _tilt,
    _wiggle,
    _sleep,
    _orbit,
    _confetti,
    _zzz,
    _spark,
    _cheer,
    _cape,
    _capeLong,
    _twinkle,
    _medal,
  ];

  late final Listenable _repaint = Listenable.merge(_all);

  AnimationController _make(int ms) =>
      AnimationController(vsync: this, duration: Duration(milliseconds: ms));

  @override
  void initState() {
    super.initState();
    _sync();
  }

  @override
  void didUpdateWidget(TautiMascot oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.mood != widget.mood ||
        oldWidget.outfit != widget.outfit ||
        oldWidget.animate != widget.animate) {
      _sync();
    }
  }

  /// Starts exactly the animations the current mood/outfit needs, resetting the
  /// rest.
  void _sync() {
    for (final AnimationController c in _all) {
      c.stop();
      c.value = 0;
    }

    if (!widget.animate) {
      return;
    }

    // `.mascot .link { animation: linkWig 3.2s ease-in-out infinite; }` — the
    // chain above the head wiggles in *every* mood.
    _link.repeat();

    // `.mascot .eye { animation: blink 4.2s infinite; }`, but `.m-sleep`
    // replaces the open eyes with closed lids.
    if (widget.mood != TautiMood.sleep) {
      _blink.repeat();
    }

    switch (widget.mood) {
      case TautiMood.idle:
        // `.m-idle .char` breathes for 2.8s, the right arm waves every 6s.
        _breathe.duration = const Duration(milliseconds: 2800);
        _breathe.repeat();
        _idleWave.repeat();
      case TautiMood.read:
        // `.m-read .char { animation: breathe 3.6s ease-in-out infinite; }`
        _breathe.duration = const Duration(milliseconds: 3600);
        _breathe.repeat();
      case TautiMood.happy:
        // The mockup re-applies the `m-happy` class every 2.6s
        // (`setInterval(..., 2600)`), so `jump .95s` and `sparkPop .9s both`
        // replay once per 2.6s cycle.
        _jump.duration = const Duration(milliseconds: 2600);
        _jump.repeat();
        _shadow.repeat();
      case TautiMood.cheer:
        // `.m-cheer .char { animation: jump .8s ease-out infinite; }`
        _jump.duration = const Duration(milliseconds: 800);
        _jump.repeat();
        _shadow.repeat();
        _cheer.repeat();
        _confetti.repeat();
        _spark.repeat();
      case TautiMood.think:
        _tilt.repeat(reverse: true);
        _orbit.repeat();
      case TautiMood.sleep:
        // `.m-sleep .zzz` holds the floating `z`s.
        _sleep.repeat();
        _zzz.repeat();
      case TautiMood.poke:
        // `.m-poke .char { animation: wiggle .6s ease-in-out 1; }`
        _wiggle.forward(from: 0);
    }

    switch (widget.outfit) {
      case TautiOutfit.none:
      case TautiOutfit.curator:
        break;
      case TautiOutfit.master:
        _cape.repeat();
        _medal.repeat();
      case TautiOutfit.legend:
        _capeLong.repeat();
        _twinkle.repeat();
    }
  }

  @override
  void dispose() {
    for (final AnimationController c in _all) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final double height = TautiMascot.heightFor(widget.width);
    return SizedBox(
      width: widget.width,
      height: height,
      child: AnimatedBuilder(
        animation: _repaint,
        builder: (BuildContext context, Widget? _) {
          return CustomPaint(
            size: Size(widget.width, height),
            painter: _TautiMascotPainter(
              mood: widget.mood,
              outfit: widget.outfit,
              breathe: _breathe.value,
              blink: _blink.value,
              idleWave: _idleWave.value,
              jump: _jump.value,
              shadow: _shadow.value,
              link: _link.value,
              tilt: _tilt.value,
              wiggle: _wiggle.value,
              sleep: _sleep.value,
              orbit: _orbit.value,
              confetti: _confetti.value,
              zzz: _zzz.value,
              spark: _spark.value,
              cheer: _cheer.value,
              cape: _cape.value,
              capeLong: _capeLong.value,
              twinkle: _twinkle.value,
              medal: _medal.value,
            ),
          );
        },
      ),
    );
  }
}

/// Immutable snapshot of every animation phase, fed to [_TautiMascotPainter].
class _MascotPhase {
  const _MascotPhase({
    required this.breathe,
    required this.blink,
    required this.idleWave,
    required this.jump,
    required this.shadow,
    required this.link,
    required this.tilt,
    required this.wiggle,
    required this.sleep,
    required this.orbit,
    required this.confetti,
    required this.zzz,
    required this.spark,
    required this.cheer,
    required this.cape,
    required this.capeLong,
    required this.twinkle,
    required this.medal,
  });

  final double breathe;
  final double blink;
  final double idleWave;
  final double jump;
  final double shadow;
  final double link;
  final double tilt;
  final double wiggle;
  final double sleep;
  final double orbit;
  final double confetti;
  final double zzz;
  final double spark;
  final double cheer;
  final double cape;
  final double capeLong;
  final double twinkle;
  final double medal;
}

class _TautiMascotPainter extends CustomPainter {
  _TautiMascotPainter({
    required this.mood,
    required this.outfit,
    required double breathe,
    required double blink,
    required double idleWave,
    required double jump,
    required double shadow,
    required double link,
    required double tilt,
    required double wiggle,
    required double sleep,
    required double orbit,
    required double confetti,
    required double zzz,
    required double spark,
    required double cheer,
    required double cape,
    required double capeLong,
    required double twinkle,
    required double medal,
  }) : phase = _MascotPhase(
          breathe: breathe,
          blink: blink,
          idleWave: idleWave,
          jump: jump,
          shadow: shadow,
          link: link,
          tilt: tilt,
          wiggle: wiggle,
          sleep: sleep,
          orbit: orbit,
          confetti: confetti,
          zzz: zzz,
          spark: spark,
          cheer: cheer,
          cape: cape,
          capeLong: capeLong,
          twinkle: twinkle,
          medal: medal,
        );

  final TautiMood mood;
  final TautiOutfit outfit;
  final _MascotPhase phase;

  // Palette from the mockup.
  static const Color _ink = TautinColors.brandTeal; // #204654
  static const Color _lime = TautinColors.mintAccent; // #CAFFA6
  static const Color _mist = TautinColors.creamBackground; // #F7F9E1
  static const Color _sky = TautinColors.iceBlue; // #A9E0F1
  static const Color _limeDeep = Color(0xFFB3F08A);
  static const Color _capeSeam = Color(0xFF3B5E6C);

  // viewBox 0 0 200 250
  static const Size _vb = Size(200, 250);

  /// Default CSS `transform-box: view-box` origin: 50% 50% of the viewBox.
  static const Offset _viewBoxOrigin = Offset(100, 125);

  /// `.mascot .cape, .mascot .cape-long { transform-origin: 50% 8%; }`
  static const Offset _capeOrigin = Offset(100, 87.3);

  @override
  void paint(Canvas canvas, Size size) {
    final double scale = size.width / _vb.width;
    canvas.save();
    canvas.scale(scale, scale);

    _paintShadow(canvas);
    if (mood == TautiMood.cheer) {
      _paintConfetti(canvas);
    }
    _paintChar(canvas);
    if (mood == TautiMood.think) {
      _paintOrbit(canvas);
    }
    if (mood == TautiMood.happy || mood == TautiMood.cheer) {
      _paintBurst(canvas);
    }
    if (mood == TautiMood.sleep) {
      _paintZzz(canvas);
    }

    canvas.restore();
  }

  // ---- Phases -------------------------------------------------------------

  /// `jump` progress of the character.
  ///
  /// `.m-happy` replays its `.95s` jump once per `2.6s` cycle, while
  /// `.m-cheer` loops its `.8s` jump non-stop, so the raw controller value is
  /// stretched/clamped for happy.
  double get _jumpT => mood == TautiMood.happy
      ? (phase.jump * (2600 / 950)).clamp(0.0, 1.0)
      : phase.jump;

  // ---- Groups -------------------------------------------------------------

  void _paintShadow(Canvas canvas) {
    // `.m-happy .shadow, .m-cheer .shadow { shadowJump .95s ease-out infinite }`
    double s = 1;
    if (mood == TautiMood.happy || mood == TautiMood.cheer) {
      s = 1 -
          0.3 *
              _piecewise(
                phase.shadow,
                const <double>[0, .45, 1],
                const <double>[0, 1, 0],
              );
    }
    canvas.save();
    _transformAbout(canvas, const Offset(100, 238), scaleX: s, scaleY: s);
    canvas.drawOval(
      Rect.fromCenter(center: const Offset(100, 238), width: 80, height: 12),
      Paint()..color = _ink.withValues(alpha: 0.14),
    );
    canvas.restore();
  }

  void _paintConfetti(Canvas canvas) {
    // rects: x, fill, animation-duration
    const List<(double, Color, double)> rects = <(double, Color, double)>[
      (22, _ink, 1.2),
      (48, _mist, 1.6),
      (74, _lime, 1.4),
      (100, _ink, 1.8),
      (126, _mist, 1.3),
      (152, _lime, 1.7),
      (178, _ink, 1.5),
      (60, _mist, 1.9),
    ];
    for (int i = 0; i < rects.length; i++) {
      final (double x, Color fill, double duration) = rects[i];
      // `.m-cheer .cf { animation: fall 1.6s linear infinite }` with
      // `animation-duration` per rect and `animation-delay: i*0.17s`, so
      // progress = ((t - delay) / duration) mod 1.
      final double p =
          _wrap(phase.confetti * (1.6 / duration) - (i * 0.17) / duration);
      final double dy = -10 + 250 * p; // translateY(-10px) -> translateY(240px)
      final double rot = 540 * p * math.pi / 180;
      final double opacity = 1 - 0.3 * p;
      canvas.save();
      canvas.translate(0, dy);
      // `.spark, .cf { transform-box: fill-box; transform-origin: center }`
      _transformAbout(
        canvas,
        Offset(x + 3.5, -0.5),
        rotateRadians: rot,
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(x, -6, 7, 11),
          const Radius.circular(3),
        ),
        Paint()..color = fill.withValues(alpha: opacity),
      );
      canvas.restore();
    }
  }

  void _paintChar(Canvas canvas) {
    canvas.save();
    _applyCharTransform(canvas);

    // Cape layers sit behind the whole character but, unlike the mockup (which
    // places them outside `<g class="char">`), they follow the body so the cape
    // moves with the jump/breathe.
    _paintOutfitBack(canvas);

    // legs (thin)
    canvas.drawPath(
      Path()
        ..moveTo(84, 172)
        ..lineTo(84, 228)
        ..lineTo(72, 228)
        ..moveTo(116, 172)
        ..lineTo(116, 228)
        ..lineTo(128, 228),
      _thinPaint(4),
    );

    // link (badge chain above the head)
    // `.mascot .link { transform-origin: 100px 46px; linkWig 3.2s }`
    canvas.save();
    _transformAbout(
      canvas,
      const Offset(100, 46),
      rotateRadians: (-4 + 9 * _sine(phase.link)) * math.pi / 180,
    );
    canvas.drawPath(
      Path()
        ..moveTo(100, 46)
        ..lineTo(100, 36),
      _thinPaint(4),
    );
    _drawRoundedRectRotated(
      canvas,
      rect: const Rect.fromLTWH(78, 12, 28, 16),
      radius: 8,
      origin: const Offset(92, 20),
      deg: -18,
      paint: _thinPaint(4),
    );
    _drawRoundedRectRotated(
      canvas,
      rect: const Rect.fromLTWH(94, 18, 28, 16),
      radius: 8,
      origin: const Offset(108, 26),
      deg: 18,
      paint: _thinPaint(4),
    );
    canvas.restore();

    // body + highlight, clipped to body
    final Path body = _bodyPath();
    canvas.drawPath(body, Paint()..color = _lime);
    canvas.save();
    canvas.clipPath(body);
    canvas.drawCircle(
      const Offset(146, 150),
      62,
      Paint()..color = _limeDeep,
    );
    canvas.restore();

    // sparkle on chest
    canvas.drawPath(
      Path()
        ..moveTo(100, 120)
        ..cubicTo(101.5, 129, 106, 133.5, 115, 135)
        ..cubicTo(106, 136.5, 101.5, 141, 100, 150)
        ..cubicTo(98.5, 141, 94, 136.5, 85, 135)
        ..cubicTo(94, 133.5, 98.5, 129, 100, 120)
        ..close(),
      Paint()..color = _mist,
    );

    _paintFace(canvas);
    if (mood == TautiMood.read) {
      _paintBook(canvas);
    }

    // Costume front layers are inserted before `<g class="armL">`.
    _paintOutfitFront(canvas);

    _paintArm(canvas, left: true);
    _paintArm(canvas, left: false);

    canvas.restore();
  }

  void _paintFace(Canvas canvas) {
    // eyes translateY: think -3, read +3
    double dy = 0;
    if (mood == TautiMood.think) {
      dy = -3;
    } else if (mood == TautiMood.read) {
      dy = 3;
    }

    canvas.save();
    canvas.translate(0, dy);

    if (mood == TautiMood.sleep) {
      final Paint stroke = _thinPaint(3.5);
      canvas.drawPath(
        Path()
          ..moveTo(78, 86)
          ..quadraticBezierTo(84, 91, 90, 86),
        stroke,
      );
      canvas.drawPath(
        Path()
          ..moveTo(110, 86)
          ..quadraticBezierTo(116, 91, 122, 86),
        stroke,
      );
    } else {
      // `.mascot .eye { animation: blink 4.2s infinite; }`
      final double blinkY = _blinkScaleY(phase.blink);
      for (final double cx in <double>[84, 116]) {
        canvas.save();
        _transformAbout(canvas, Offset(cx, 84), scaleX: 1, scaleY: blinkY);
        canvas.drawOval(
          Rect.fromCenter(center: Offset(cx, 84), width: 9, height: 11),
          Paint()..color = _ink,
        );
        canvas.restore();
      }
    }

    // cheeks
    canvas.drawCircle(const Offset(72, 98), 6, Paint()..color = _sky);
    canvas.drawCircle(const Offset(128, 98), 6, Paint()..color = _sky);

    canvas.restore();

    _paintMouth(canvas);
  }

  void _paintMouth(Canvas canvas) {
    switch (mood) {
      case TautiMood.idle:
      case TautiMood.read:
        canvas.drawPath(
          Path()
            ..moveTo(92, 96)
            ..quadraticBezierTo(100, 104, 108, 96),
          _thinPaint(4),
        );
      case TautiMood.happy:
      case TautiMood.cheer:
        canvas.drawPath(
          Path()
            ..moveTo(91, 94)
            ..quadraticBezierTo(100, 114, 109, 94)
            ..close(),
          Paint()..color = _ink,
        );
      case TautiMood.think:
      case TautiMood.sleep:
        canvas.drawPath(
          Path()
            ..moveTo(93, 99)
            ..lineTo(107, 99),
          _thinPaint(4),
        );
      case TautiMood.poke:
        canvas.drawOval(
          Rect.fromCenter(center: const Offset(100, 100), width: 8, height: 10),
          Paint()..color = _ink,
        );
    }
  }

  void _paintBook(Canvas canvas) {
    final Paint fill = Paint()..color = _mist;
    canvas.drawPath(
      Path()
        ..moveTo(100, 128)
        ..lineTo(64, 124)
        ..lineTo(64, 158)
        ..lineTo(100, 162)
        ..close(),
      fill,
    );
    canvas.drawPath(
      Path()
        ..moveTo(100, 128)
        ..lineTo(136, 124)
        ..lineTo(136, 158)
        ..lineTo(100, 162)
        ..close(),
      fill,
    );
    canvas.drawPath(
      Path()
        ..moveTo(100, 128)
        ..lineTo(100, 162)
        ..moveTo(72, 134)
        ..lineTo(92, 137)
        ..moveTo(72, 142)
        ..lineTo(92, 145)
        ..moveTo(108, 137)
        ..lineTo(128, 134)
        ..moveTo(108, 145)
        ..lineTo(128, 142),
      _thinPaint(2.5),
    );
  }

  // ---- Costumes -----------------------------------------------------------

  void _paintOutfitBack(Canvas canvas) {
    switch (outfit) {
      case TautiOutfit.none:
      case TautiOutfit.curator:
        break;
      case TautiOutfit.master:
        canvas.save();
        // `.mascot .cape { transform-origin: 50% 8%; capeSway 4.6s }`
        _transformAbout(
          canvas,
          _capeOrigin,
          rotateRadians: (-0.8 + 1.8 * _sine(phase.cape)) * math.pi / 180,
        );
        canvas.drawPath(
          _masterCapePath(),
          Paint()..color = _sky,
        );
        canvas.drawPath(_masterCapePath(), _outlinePaint(5));
        canvas.drawPath(
          Path()
            ..moveTo(42, 180)
            ..cubicTo(66, 190, 134, 190, 158, 180),
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 3.2
            ..strokeCap = StrokeCap.round
            ..color = _capeSeam.withValues(alpha: 0.3),
        );
        canvas.restore();
      case TautiOutfit.legend:
        canvas.save();
        // `.mascot .cape-long { transform-origin: 50% 8%; capeSway 5.8s }`
        _transformAbout(
          canvas,
          _capeOrigin,
          rotateRadians: (-0.8 + 1.8 * _sine(phase.capeLong)) * math.pi / 180,
        );
        canvas.drawPath(_legendCapePath(), Paint()..color = _mist);
        canvas.drawPath(_legendCapePath(), _outlinePaint(5));
        canvas.drawPath(
          Path()
            ..moveTo(30, 196)
            ..cubicTo(58, 210, 142, 210, 170, 196),
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 8
            ..strokeCap = StrokeCap.round
            ..color = _lime,
        );
        canvas.drawPath(
          Path()
            ..moveTo(33, 150)
            ..cubicTo(40, 168, 37, 184, 34, 194),
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 4
            ..strokeCap = StrokeCap.round
            ..color = _sky.withValues(alpha: 0.7),
        );
        canvas.restore();
    }
  }

  void _paintOutfitFront(Canvas canvas) {
    switch (outfit) {
      case TautiOutfit.none:
        break;
      case TautiOutfit.curator:
        // Vest.
        canvas.drawPath(_curatorVestPath(), Paint()..color = _sky);
        canvas.drawPath(_curatorVestPath(), _outlinePaint(5));
        _drawOutlinedRect(
          canvas,
          rect: const Rect.fromLTWH(67, 151, 18, 13),
          radius: 4,
          strokeWidth: 3.2,
        );
        _drawOutlinedRect(
          canvas,
          rect: const Rect.fromLTWH(115, 151, 18, 13),
          radius: 4,
          strokeWidth: 3.2,
        );
        // Glasses.
        final Paint lens = Paint()..color = _mist.withValues(alpha: 0.3);
        canvas.drawCircle(const Offset(84, 84), 12, lens);
        canvas.drawCircle(const Offset(116, 84), 12, lens);
        final Paint frame = _inkStroke(3.6);
        canvas.drawCircle(const Offset(84, 84), 12, frame);
        canvas.drawCircle(const Offset(116, 84), 12, frame);
        canvas.drawPath(
          Path()
            ..moveTo(96, 84)
            ..lineTo(104, 84)
            ..moveTo(73, 80)
            ..lineTo(64, 76)
            ..moveTo(127, 80)
            ..lineTo(136, 76),
          frame,
        );
      case TautiOutfit.master:
        // Clasps + star medal.
        canvas.drawCircle(const Offset(68, 106), 9, Paint()..color = _mist);
        canvas.drawCircle(const Offset(68, 106), 9, _inkStroke(4));
        canvas.drawCircle(const Offset(132, 106), 9, Paint()..color = _mist);
        canvas.drawCircle(const Offset(132, 106), 9, _inkStroke(4));
        canvas.save();
        // `.mascot .cost-medal { transform-origin: center; medalPulse 3.6s }`
        _transformAbout(
          canvas,
          const Offset(100, 157),
          scaleX: 1 + 0.06 * _sine(phase.medal),
          scaleY: 1 + 0.06 * _sine(phase.medal),
        );
        canvas.drawCircle(const Offset(100, 157), 15, Paint()..color = _mist);
        canvas.drawCircle(const Offset(100, 157), 15, _inkStroke(4.5));
        canvas.drawPath(_starPath(), Paint()..color = _ink);
        canvas.restore();
      case TautiOutfit.legend:
        // Crown.
        canvas.drawPath(_crownPath(), Paint()..color = _lime);
        final Paint crownStroke = _inkStroke(4.5)
          ..strokeJoin = StrokeJoin.round;
        canvas.drawPath(_crownPath(), crownStroke);
        canvas.drawPath(
          Path()
            ..moveTo(78, 70)
            ..quadraticBezierTo(100, 78, 122, 70),
          crownStroke,
        );
        canvas.drawCircle(const Offset(84, 62), 2.8, Paint()..color = _mist);
        canvas.drawCircle(const Offset(100, 64), 3.2, Paint()..color = _mist);
        canvas.drawCircle(const Offset(116, 62), 2.8, Paint()..color = _mist);
        // Sparkling aura. `.tw { transform-origin: center; twinkle 2.8s }`
        const List<(double, double, double, Color, double)> aura =
            <(double, double, double, Color, double)>[
          (42, 78, .55, _mist, 0),
          (160, 66, .45, _lime, .7),
          (34, 132, .42, _mist, 1.3),
          (166, 140, .5, _mist, 1.9),
        ];
        for (final (double x, double y, double s, Color color, double delay)
            in aura) {
          final double p = _wrap(phase.twinkle - delay / 2.8);
          final double tw = .85 + 0.27 * _sine(p);
          final double opacity = .35 + 0.65 * _sine(p);
          canvas.save();
          canvas.translate(x, y);
          canvas.scale(s * tw);
          canvas.drawPath(
            _sparkPath(),
            Paint()..color = color.withValues(alpha: opacity),
          );
          canvas.restore();
        }
    }
  }

  void _paintArm(Canvas canvas, {required bool left}) {
    final double deg = _armDegrees(left: left);
    final Offset origin = left ? const Offset(56, 110) : const Offset(144, 110);
    final Path path = left
        ? (Path()
          ..moveTo(56, 110)
          ..quadraticBezierTo(44, 132, 50, 158))
        : (Path()
          ..moveTo(144, 110)
          ..quadraticBezierTo(156, 132, 150, 158));
    final Offset hand = left ? const Offset(50, 158) : const Offset(150, 158);

    canvas.save();
    _transformAbout(canvas, origin, rotateDeg: deg);
    // The curator's magnifying glass is held by the left hand, so it rotates
    // with that arm (`.cost-mag` is painted just below `<g class="armL">`).
    if (left && outfit == TautiOutfit.curator) {
      _paintMagnifier(canvas);
    }
    canvas.drawPath(path, _thinPaint(4));
    canvas.drawCircle(hand, 5.5, Paint()..color = _ink);
    canvas.restore();
  }

  void _paintMagnifier(Canvas canvas) {
    canvas.drawPath(
      Path()
        ..moveTo(50, 158)
        ..lineTo(38, 182),
      _inkStroke(6),
    );
    canvas.drawCircle(
      const Offset(34, 196),
      13,
      Paint()..color = _mist.withValues(alpha: 0.85),
    );
    canvas.drawCircle(const Offset(34, 196), 13, _inkStroke(4));
    canvas.drawPath(
      Path()
        ..moveTo(27, 191)
        ..quadraticBezierTo(31, 185, 39, 184),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3
        ..strokeCap = StrokeCap.round
        ..color = Colors.white,
    );
  }

  double _armDegrees({required bool left}) {
    switch (mood) {
      case TautiMood.idle:
        if (!left) {
          // @keyframes idleWave on the right arm.
          return _piecewise(
            phase.idleWave,
            const <double>[0, .58, .64, .71, .78, .85, .92, 1],
            const <double>[-8, -8, -152, -124, -152, -124, -8, -8],
          );
        }
        return 8;
      case TautiMood.read:
        return left ? -62 : 62;
      case TautiMood.happy:
        return left ? 140 : -140;
      case TautiMood.cheer:
        // @keyframes cheerL/R alternate
        return left ? 128 + 30 * phase.cheer : -158 + 30 * phase.cheer;
      case TautiMood.think:
        return left ? 8 : 92;
      case TautiMood.sleep:
        return left ? 8 : -8;
      case TautiMood.poke:
        return left ? 45 : -45;
    }
  }

  void _paintOrbit(Canvas canvas) {
    const List<(double, double, Color)> sparks = <(double, double, Color)>[
      (100, 10, _ink),
      (162, 112, _mist),
      (38, 112, _ink),
    ];
    canvas.save();
    // `.m-think .orbit-spin: transform-origin 100px 82px; animation spin 2.6s`
    _transformAbout(canvas, const Offset(100, 82), rotateDeg: 360 * phase.orbit);
    for (final (double x, double y, Color color) in sparks) {
      canvas.save();
      canvas.translate(x, y);
      canvas.drawPath(_sparkPath(), Paint()..color = color);
      canvas.restore();
    }
    canvas.restore();
  }

  void _paintBurst(Canvas canvas) {
    // (x, y, scale, fill, animation-delay)
    const List<(double, double, double, Color, double)> sparks =
        <(double, double, double, Color, double)>[
      (34, 58, 1.3, _ink, 0),
      (168, 52, 1.1, _mist, .12),
      (26, 140, 1.0, _mist, .2),
      (176, 136, 1.3, _ink, .08),
    ];
    for (final (double x, double y, double s, Color color, double delay)
        in sparks) {
      // `@keyframes sparkPop { 0%: scale(0) op 0; 40%: scale(1.5) op 1;
      // 100%: scale(0) op 0 }`. Happy uses `both` (plays once per cycle),
      // cheer uses `infinite`.
      final double p = mood == TautiMood.happy
          ? ((phase.jump * 2600 - delay * 1000) / 900).clamp(0.0, 1.0)
          : _wrap(phase.spark - delay / 0.9);
      final double pop = _piecewise(p, const <double>[0, .4, 1],
          const <double>[0, 1.5, 0]);
      final double opacity = _piecewise(p, const <double>[0, .4, 1],
          const <double>[0, 1, 0]);
      if (pop <= 0) {
        continue;
      }
      canvas.save();
      canvas.translate(x, y);
      canvas.scale(s * pop);
      canvas.drawPath(
        _sparkPath(),
        Paint()..color = color.withValues(alpha: opacity),
      );
      canvas.restore();
    }
  }

  void _paintZzz(Canvas canvas) {
    // `<text class="z" x="132" y="58" font-size="22">` (+ 146/44/28, 160/28/34)
    // with `animation-delay: .8s / 1.6s`.
    const List<(double, double, double, double)> zs =
        <(double, double, double, double)>[
      (132, 58, 22, 0),
      (146, 44, 28, .8),
      (160, 28, 34, 1.6),
    ];
    for (final (double x, double y, double fontSize, double delay) in zs) {
      // `@keyframes zfloat { 0%: translate(0,0) scale(.6) op 0;
      // 20%: op 1; 100%: translate(22px,-46px) scale(1.2) op 0 }` — applied on
      // the default view-box origin, so `scale` shrinks towards the viewBox
      // centre before the translation is added.
      final double p = _wrap(phase.zzz - delay / 2.6);
      final double s = .6 + .6 * p;
      final double px = _viewBoxOrigin.dx + s * (x - _viewBoxOrigin.dx) + 22 * p;
      final double py = _viewBoxOrigin.dy + s * (y - _viewBoxOrigin.dy) - 46 * p;
      final double opacity = _piecewise(p, const <double>[0, .2, 1],
          const <double>[0, 1, 0]);
      final TextPainter tp = TextPainter(
        text: TextSpan(
          text: 'z',
          style: TextStyle(
            color: _ink.withValues(alpha: opacity.clamp(0, 1)),
            fontSize: fontSize,
            fontWeight: FontWeight.w800,
            fontFamily: 'Plus Jakarta Sans',
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      final double baseline =
          tp.computeDistanceToActualBaseline(TextBaseline.alphabetic);
      tp.paint(canvas, Offset(px, py - baseline));
    }
  }

  // ---- Transforms ---------------------------------------------------------

  void _applyCharTransform(Canvas canvas) {
    // `.char: transform-origin: 100px 236px`
    const Offset origin = Offset(100, 236);
    switch (mood) {
      case TautiMood.idle:
      case TautiMood.read:
        final double s = _sine(phase.breathe);
        _transformAbout(
          canvas,
          origin,
          scaleX: 1 + .012 * s,
          scaleY: 1 + .025 * s,
        );
      case TautiMood.happy:
      case TautiMood.cheer:
        // `@keyframes jump`
        final double t = _jumpT;
        final double ty = _piecewise(t, const <double>[0, .14, .45, .75, 1],
            const <double>[0, 0, -34, 0, 0]);
        final double sx = _piecewise(t, const <double>[0, .14, .45, .75, 1],
            const <double>[1, 1.08, .95, 1.06, 1]);
        final double sy = _piecewise(t, const <double>[0, .14, .45, .75, 1],
            const <double>[1, .9, 1.07, .92, 1]);
        _transformAbout(canvas, origin, translateY: ty, scaleX: sx, scaleY: sy);
      case TautiMood.think:
        // `@keyframes tilt { from: rotate(-3deg) to: rotate(3deg) }`
        _transformAbout(canvas, origin, rotateDeg: -3 + 6 * phase.tilt);
      case TautiMood.sleep:
        // `@keyframes breatheSleep { rotate(5deg) scale(1..1.02, 1..1.035) }`
        final double s = _sine(phase.sleep);
        _transformAbout(
          canvas,
          origin,
          rotateDeg: 5,
          scaleX: 1 + .02 * s,
          scaleY: 1 + .035 * s,
        );
      case TautiMood.poke:
        // `@keyframes wiggle { 0,100%: 0; 20%: -7; 45%: 6; 70%: -4 }`
        final double deg = _piecewise(phase.wiggle, const <double>[0, .2, .45, .7, 1],
            const <double>[0, -7, 6, -4, 0]);
        _transformAbout(canvas, origin, rotateDeg: deg);
    }
  }

  /// Applies a transform about a point expressed in viewBox coordinates.
  void _transformAbout(
    Canvas canvas,
    Offset origin, {
    double rotateDeg = 0,
    double rotateRadians = 0,
    double scaleX = 1,
    double scaleY = 1,
    double translateY = 0,
  }) {
    canvas.translate(origin.dx, origin.dy + translateY);
    final double radians =
        rotateRadians != 0 ? rotateRadians : rotateDeg * math.pi / 180;
    if (radians != 0) {
      canvas.rotate(radians);
    }
    if (scaleX != 1 || scaleY != 1) {
      canvas.scale(scaleX, scaleY);
    }
    canvas.translate(-origin.dx, -origin.dy);
  }

  // ---- Paths & helpers ----------------------------------------------------

  Path _bodyPath() => Path()
    ..moveTo(54, 112)
    ..cubicTo(54, 66, 74, 44, 100, 44)
    ..cubicTo(126, 44, 146, 66, 146, 112)
    ..lineTo(146, 142)
    ..cubicTo(146, 164, 126, 176, 100, 176)
    ..cubicTo(74, 176, 54, 164, 54, 142)
    ..close();

  Path _masterCapePath() => Path()
    ..moveTo(66, 78)
    ..cubicTo(44, 94, 34, 134, 36, 188)
    ..cubicTo(54, 197, 146, 197, 164, 188)
    ..cubicTo(166, 134, 156, 94, 134, 78)
    ..close();

  Path _legendCapePath() => Path()
    ..moveTo(70, 76)
    ..cubicTo(42, 92, 26, 142, 24, 206)
    ..cubicTo(48, 220, 152, 220, 176, 206)
    ..cubicTo(174, 142, 158, 92, 130, 76)
    ..close();

  Path _curatorVestPath() => Path()
    ..moveTo(58, 108)
    ..cubicTo(56, 132, 56, 152, 60, 168)
    ..cubicTo(70, 176, 84, 181, 100, 181)
    ..cubicTo(116, 181, 130, 176, 140, 168)
    ..cubicTo(144, 152, 144, 132, 142, 108)
    ..lineTo(128, 108)
    ..lineTo(100, 143)
    ..lineTo(72, 108)
    ..close();

  Path _crownPath() => Path()
    ..moveTo(78, 70)
    ..lineTo(84, 55)
    ..lineTo(92, 66)
    ..lineTo(100, 52)
    ..lineTo(108, 66)
    ..lineTo(116, 55)
    ..lineTo(122, 70);

  Path _starPath() => Path()
    ..moveTo(100, 147)
    ..lineTo(103.4, 154.2)
    ..lineTo(111, 155)
    ..lineTo(105.4, 160.2)
    ..lineTo(107, 168)
    ..lineTo(100, 164.4)
    ..lineTo(93, 168)
    ..lineTo(94.6, 160.2)
    ..lineTo(89, 155)
    ..lineTo(96.6, 154.2)
    ..close();

  Path _sparkPath() => Path()
    ..moveTo(0, -9)
    ..cubicTo(1, -4, 4, -1, 9, 0)
    ..cubicTo(4, 1, 1, 4, 0, 9)
    ..cubicTo(-1, 4, -4, 1, -9, 0)
    ..cubicTo(-4, -1, -1, -4, 0, -9)
    ..close();

  Paint _thinPaint(double width) => Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = width
    ..strokeCap = StrokeCap.round
    ..strokeJoin = StrokeJoin.round
    ..color = _ink;

  /// `.o { stroke: #204654; stroke-width: 5; round join/cap }` (stroke only).
  Paint _outlinePaint(double width) => _inkStroke(width);

  Paint _inkStroke(double width) => Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = width
    ..strokeCap = StrokeCap.round
    ..strokeJoin = StrokeJoin.round
    ..color = _ink;

  void _drawOutlinedRect(
    Canvas canvas, {
    required Rect rect,
    required double radius,
    required double strokeWidth,
  }) {
    final RRect r = RRect.fromRectAndRadius(rect, Radius.circular(radius));
    canvas.drawRRect(r, Paint()..color = _mist);
    canvas.drawRRect(r, _inkStroke(strokeWidth));
  }

  void _drawRoundedRectRotated(
    Canvas canvas, {
    required Rect rect,
    required double radius,
    required Offset origin,
    required double deg,
    required Paint paint,
  }) {
    canvas.save();
    _transformAbout(canvas, origin, rotateDeg: deg);
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, Radius.circular(radius)),
      paint,
    );
    canvas.restore();
  }

  /// `0% .. 100%` keyframe interpolation.
  double _piecewise(double t, List<double> xs, List<double> ys) {
    if (t <= xs.first) {
      return ys.first;
    }
    for (int i = 0; i < xs.length - 1; i++) {
      if (t <= xs[i + 1]) {
        final double u = (t - xs[i]) / (xs[i + 1] - xs[i]);
        return ys[i] + (ys[i + 1] - ys[i]) * u;
      }
    }
    return ys.last;
  }

  /// `(1 - cos)` shape: 0 at t=0, 1 at t=.5, 0 at t=1 — matches the
  /// `0,100% -> base / 50% -> peak` easing of the `ease-in-out` keyframes.
  double _sine(double t) => (1 - math.cos(2 * math.pi * t)) / 2;

  /// Always-positive modulo, so phase maths stays in `0 .. 1` even when a
  /// negative `animation-delay` equivalent is subtracted.
  double _wrap(double t) {
    final double x = t % 1.0;
    return x < 0 ? x + 1.0 : x;
  }

  /// blink: scaleY(1) except a short dip to `.1` near 96%.
  double _blinkScaleY(double t) => _piecewise(
        t,
        const <double>[0, .92, .955, .97, 1],
        const <double>[1, 1, .1, 1, 1],
      );

  @override
  bool shouldRepaint(covariant _TautiMascotPainter oldDelegate) => true;
}
