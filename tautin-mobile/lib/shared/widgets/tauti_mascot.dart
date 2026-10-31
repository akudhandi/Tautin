import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/theme/tautin_theme.dart';

/// Moods of the Tauti mascot, mirroring the `.m-*` classes of the design
/// mockup (`m-idle`, `m-happy`, `m-think`, `m-read`, `m-cheer`, `m-sleep`,
/// `m-poke`).
enum TautiMood { idle, happy, think, read, cheer, sleep, poke }

/// The Tauti mascot, drawn straight from the geometry, transforms and
/// keyframes defined in `opendesign-tautin.html`.
///
/// The mockup renders a `viewBox="0 0 200 250"` SVG and animates it with CSS
/// keyframes (`breathe`, `blink`, `idleWave`, `jump`, `tilt`, `wiggle`,
/// `breatheSleep`, `spin`, `cheerL/R`, `sparkPop`, `fall`, `zfloat`). CSS is
/// not reproducible 1:1 in Flutter, so every phase below is re-implemented with
/// a dedicated [AnimationController] using the exact same timing values.
class TautiMascot extends StatefulWidget {
  const TautiMascot({
    super.key,
    this.mood = TautiMood.idle,
    this.width = 120,
    this.animate = true,
  });

  /// Which pose/behaviour the mascot should hold.
  final TautiMood mood;

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
  late final AnimationController _tilt = _make(1800);
  late final AnimationController _wiggle = _make(600);
  late final AnimationController _sleep = _make(4000);
  late final AnimationController _orbit = _make(2600);
  late final AnimationController _confetti = _make(1600);
  late final AnimationController _zzz = _make(2600);
  late final AnimationController _spark = _make(900);
  late final AnimationController _cheer = _make(400);

  late final List<AnimationController> _all = <AnimationController>[
    _breathe,
    _blink,
    _idleWave,
    _jump,
    _tilt,
    _wiggle,
    _sleep,
    _orbit,
    _confetti,
    _zzz,
    _spark,
    _cheer,
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
        oldWidget.animate != widget.animate) {
      _sync();
    }
  }

  /// Starts exactly the animations the current mood needs, resetting the rest.
  void _sync() {
    for (final AnimationController c in _all) {
      c.stop();
      c.value = 0;
    }

    if (!widget.animate) {
      return;
    }

    switch (widget.mood) {
      case TautiMood.idle:
        _breathe.repeat();
        _blink.repeat();
        _idleWave.repeat();
      case TautiMood.read:
        _breathe.repeat();
        _blink.repeat();
      case TautiMood.happy:
        _blink.repeat();
        _jump.forward(from: 0);
        _spark.repeat();
      case TautiMood.cheer:
        _blink.repeat();
        _jump.repeat();
        _cheer.repeat();
        _confetti.repeat();
        _spark.repeat();
      case TautiMood.think:
        _blink.repeat();
        _tilt.repeat(reverse: true);
        _orbit.repeat();
      case TautiMood.sleep:
        _sleep.repeat();
      case TautiMood.poke:
        _blink.repeat();
        _wiggle.forward(from: 0);
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
              breathe: _breathe.value,
              blink: _blink.value,
              idleWave: _idleWave.value,
              jump: _jump.value,
              tilt: _tilt.value,
              wiggle: _wiggle.value,
              sleep: _sleep.value,
              orbit: _orbit.value,
              confetti: _confetti.value,
              zzz: _zzz.value,
              spark: _spark.value,
              cheer: _cheer.value,
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
    required this.tilt,
    required this.wiggle,
    required this.sleep,
    required this.orbit,
    required this.confetti,
    required this.zzz,
    required this.spark,
    required this.cheer,
  });

  final double breathe;
  final double blink;
  final double idleWave;
  final double jump;
  final double tilt;
  final double wiggle;
  final double sleep;
  final double orbit;
  final double confetti;
  final double zzz;
  final double spark;
  final double cheer;
}

class _TautiMascotPainter extends CustomPainter {
  _TautiMascotPainter({
    required this.mood,
    required double breathe,
    required double blink,
    required double idleWave,
    required double jump,
    required double tilt,
    required double wiggle,
    required double sleep,
    required double orbit,
    required double confetti,
    required double zzz,
    required double spark,
    required double cheer,
  }) : phase = _MascotPhase(
          breathe: breathe,
          blink: blink,
          idleWave: idleWave,
          jump: jump,
          tilt: tilt,
          wiggle: wiggle,
          sleep: sleep,
          orbit: orbit,
          confetti: confetti,
          zzz: zzz,
          spark: spark,
          cheer: cheer,
        );

  final TautiMood mood;
  final _MascotPhase phase;

  // Palette from the mockup.
  static const Color _ink = TautinColors.brandTeal; // #204654
  static const Color _lime = TautinColors.mintAccent; // #CAFFA6
  static const Color _mist = TautinColors.creamBackground; // #F7F9E1
  static const Color _sky = TautinColors.iceBlue; // #A9E0F1
  static const Color _limeDeep = Color(0xFFB3F08A);

  // viewBox 0 0 200 250
  static const Size _vb = Size(200, 250);

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

  // ---- Groups -------------------------------------------------------------

  void _paintShadow(Canvas canvas) {
    double s = 1;
    if (mood == TautiMood.happy || mood == TautiMood.cheer) {
      // @keyframes shadowJump { 0,100%: scale(1); 45%: scale(.7) }
      s = 1 - 0.3 * _piecewise(phase.jump, <double>[0, .45, 1], <double>[0, 1, 0]);
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
      // animation-delay: i*0.17s, duration varies per rect.
      final double p = ((phase.confetti * (1.6 / duration)) + i * 0.17) % 1.0;
      final double dy = -10 + 250 * p; // @keyframes fall
      final double rot = 540 * p * math.pi / 180;
      final double opacity = 1 - 0.3 * p;
      canvas.save();
      canvas.translate(x + 3.5, -6 + 5.5);
      canvas.rotate(rot);
      canvas.translate(-(x + 3.5), -(-6 + 5.5));
      canvas.translate(0, dy);
      final RRect r = RRect.fromRectAndRadius(
        Rect.fromLTWH(x, -6, 7, 11),
        const Radius.circular(3),
      );
      canvas.drawRRect(r, Paint()..color = fill.withValues(alpha: opacity));
      canvas.restore();
    }
  }

  void _paintChar(Canvas canvas) {
    canvas.save();
    _applyCharTransform(canvas);

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

    // link (badge chain above the head) @keyframes linkWig about (100,46)
    final double linkDeg = -4 + 9 * _triangle(phase.breathe * 1.0 + phase.tilt);
    canvas.save();
    _transformAbout(canvas, const Offset(100, 46), rotateDeg: linkDeg);
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
      // @keyframes blink { 0,92,100%: scaleY(1); 96%: scaleY(.1) }
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
    canvas.drawPath(path, _thinPaint(4));
    canvas.drawCircle(hand, 5.5, Paint()..color = _ink);
    canvas.restore();
  }

  double _armDegrees({required bool left}) {
    switch (mood) {
      case TautiMood.idle:
        if (!left) {
          // @keyframes idleWave on the right arm.
          return _piecewise(
            phase.idleWave,
            <double>[0, .58, .64, .71, .78, .85, .92, 1],
            <double>[-8, -8, -152, -124, -152, -124, -8, -8],
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
    // .orbit-spin: transform-origin 100px 82px; animation spin 2.6s linear.
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
      // @keyframes sparkPop { 0%: scale(0),op0; 40%: scale(1.5),op1; 100%: scale(0),op0 }
      final double p = (phase.spark + delay) % 1.0;
      final double pop = _piecewise(p, <double>[0, .4, 1], <double>[0, 1.5, 0]);
      final double opacity = _piecewise(p, <double>[0, .4, 1], <double>[0, 1, 0]);
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
    // text z at (132,58,22), (146,44,28,.8s), (160,28,34,1.6s)
    const List<(double, double, double, double)> zs =
        <(double, double, double, double)>[
      (132, 58, 22, 0),
      (146, 44, 28, .8),
      (160, 28, 34, 1.6),
    ];
    for (final (double x, double y, double fontSize, double delay) in zs) {
      // @keyframes zfloat 2.6s ease-in infinite
      final double p = (phase.zzz + delay / 2.6) % 1.0;
      final double dy = -46 * p;
      final double dx = 22 * p;
      final double sc = .6 + .6 * p;
      final double opacity = p < .2 ? p / .2 : 1 - (p - .2) / .8;
      canvas.save();
      canvas.translate(x + dx, y + dy);
      canvas.scale(sc);
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
      tp.paint(canvas, Offset(-tp.width / 2, -tp.height / 2));
      canvas.restore();
    }
  }

  // ---- Transforms ---------------------------------------------------------

  void _applyCharTransform(Canvas canvas) {
    // .char: transform-origin 100px 236px
    const Offset origin = Offset(100, 236);
    switch (mood) {
      case TautiMood.idle:
      case TautiMood.read:
        // @keyframes breathe
        final double s = _sine(phase.breathe);
        _transformAbout(canvas, origin, scaleX: 1 + .012 * s, scaleY: 1 + .025 * s);
      case TautiMood.happy:
      case TautiMood.cheer:
        // @keyframes jump
        final double ty = _piecewise(
          phase.jump,
          <double>[0, .14, .45, .75, 1],
          <double>[0, 0, -34, 0, 0],
        );
        final double sx = _piecewise(
          phase.jump,
          <double>[0, .14, .45, .75, 1],
          <double>[1, 1.08, .95, 1.06, 1],
        );
        final double sy = _piecewise(
          phase.jump,
          <double>[0, .14, .45, .75, 1],
          <double>[1, .9, 1.07, .92, 1],
        );
        _transformAbout(canvas, origin, translateY: ty, scaleX: sx, scaleY: sy);
      case TautiMood.think:
        // @keyframes tilt { from -3deg to 3deg }
        _transformAbout(canvas, origin, rotateDeg: -3 + 6 * phase.tilt);
      case TautiMood.sleep:
        // @keyframes breatheSleep: rotate(5deg) scale(1..1.02, 1..1.035)
        final double s = _sine(phase.sleep);
        _transformAbout(
          canvas,
          origin,
          rotateDeg: 5,
          scaleX: 1 + .02 * s,
          scaleY: 1 + .035 * s,
        );
      case TautiMood.poke:
        // @keyframes wiggle { 0,100%: 0; 20%: -7; 45%: 6; 70%: -4 }
        final double deg = _piecewise(
          phase.wiggle,
          <double>[0, .2, .45, .7, 1],
          <double>[0, -7, 6, -4, 0],
        );
        _transformAbout(canvas, origin, rotateDeg: deg);
    }
  }

  /// Applies a transform about a point expressed in viewBox coordinates.
  void _transformAbout(
    Canvas canvas,
    Offset origin, {
    double rotateDeg = 0,
    double scaleX = 1,
    double scaleY = 1,
    double translateY = 0,
  }) {
    canvas.translate(origin.dx, origin.dy + translateY);
    if (rotateDeg != 0) {
      canvas.rotate(rotateDeg * math.pi / 180);
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
  /// `0,100% -> base / 50% -> peak` easing of the breathe keyframes.
  double _sine(double t) => (1 - math.cos(2 * math.pi * t)) / 2;

  /// Triangle wave 0 -> 1 -> 0 used for the decorative link wiggle.
  double _triangle(double t) {
    final double x = t % 1.0;
    return x < .5 ? x * 2 : (1 - x) * 2;
  }

  /// blink: scaleY(1) except a short dip to `.1` near 96%.
  double _blinkScaleY(double t) => _piecewise(
        t,
        <double>[0, .92, .955, .97, 1],
        <double>[1, 1, .1, 1, 1],
      );

  @override
  bool shouldRepaint(covariant _TautiMascotPainter oldDelegate) => true;
}
