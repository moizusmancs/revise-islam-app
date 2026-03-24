import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';

// Placeholder needle color — light orange
const _needleColor = Color(0xFFFF8C55);

class QiblahScreen extends StatefulWidget {
  const QiblahScreen({super.key});

  @override
  State<QiblahScreen> createState() => _QiblahScreenState();
}

class _QiblahScreenState extends State<QiblahScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _waveController;

  // Placeholder — will be driven by real compass heading later
  final double _heading = 45.0;

  @override
  void initState() {
    super.initState();
    _waveController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 8),
    )..repeat();
  }

  @override
  void dispose() {
    _waveController.dispose();
    super.dispose();
  }

  String get _directionLabel {
    if (_heading < 22.5) return 'N';
    if (_heading < 67.5) return 'NE';
    if (_heading < 112.5) return 'E';
    if (_heading < 157.5) return 'SE';
    if (_heading < 202.5) return 'S';
    if (_heading < 247.5) return 'SW';
    if (_heading < 292.5) return 'W';
    if (_heading < 337.5) return 'NW';
    return 'N';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundWhite,
      appBar: AppBar(
        title: const Text('Qiblah Finder'),
      ),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedBuilder(
              animation: _waveController,
              builder: (context, _) {
                return SizedBox(
                  width: 300,
                  height: 300,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      // Swiggly circles + boundary ring + cardinals
                      CustomPaint(
                        size: const Size(300, 300),
                        painter: _CompassPainter(_waveController.value),
                      ),

                      // Single-direction needle
                      Transform.rotate(
                        angle: _heading * math.pi / 180,
                        child: SizedBox(
                          width: 40,
                          height: 240,
                          child: CustomPaint(painter: _NeedlePainter()),
                        ),
                      ),

                      // Degree + direction label
                      Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            '${_heading.toStringAsFixed(0)}°',
                            style: const TextStyle(
                              color: AppColors.brandingGreen,
                              fontSize: 52,
                              fontWeight: FontWeight.w700,
                              letterSpacing: -2,
                              height: 1,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _directionLabel,
                            style: const TextStyle(
                              color: AppColors.textLight,
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                              letterSpacing: 4,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                );
              },
            ),

            const SizedBox(height: 32),

            const Text(
              'Point your phone towards Qiblah',
              style: TextStyle(
                color: AppColors.textDisabled,
                fontSize: 12,
                fontWeight: FontWeight.w400,
                letterSpacing: 0.3,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Needle (single direction, rounded tip, orange) ───────────────────────────

class _NeedlePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;

    // Needle: uniform width → tapers → rounded thin tip
    const w = 5.0;          // half-width at base
    const tw = 1.2;         // half-width at tip (very thin)
    const taperStart = -36.0;
    const tipY = -92.0;

    final path = Path()
      ..moveTo(cx - w, cy + 4)
      ..lineTo(cx + w, cy + 4)                    // base
      ..lineTo(cx + w, cy + taperStart)            // straight right side
      ..cubicTo(                                   // right side tapers inward
        cx + w,  cy + taperStart - 18,
        cx + tw, cy + tipY + 6,
        cx + tw, cy + tipY,
      )
      ..arcToPoint(                                // rounded tip
        Offset(cx - tw, cy + tipY),
        radius: const Radius.circular(tw),
        clockwise: false,
      )
      ..cubicTo(                                   // left side tapers back out
        cx - tw, cy + tipY + 6,
        cx - w,  cy + taperStart - 18,
        cx - w,  cy + taperStart,
      )
      ..lineTo(cx - w, cy + 4)
      ..close();

    canvas.drawPath(
      path,
      Paint()
        ..color = _needleColor
        ..style = PaintingStyle.fill,
    );

    // Pivot dot
    canvas.drawCircle(Offset(cx, cy), 5, Paint()..color = AppColors.white);
    canvas.drawCircle(
      Offset(cx, cy),
      5,
      Paint()
        ..color = AppColors.brandingGreen
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// ─── Compass Painter (swiggly rings + boundary + N/S/E/W) ────────────────────

class _CompassPainter extends CustomPainter {
  final double t;

  const _CompassPainter(this.t);

  Path _wavyCircle({
    required Offset center,
    required double radius,
    required double amplitude,
    required double phaseOffset,
    required double speedMultiplier,
  }) {
    const steps = 360;
    final path = Path();

    for (int i = 0; i <= steps; i++) {
      final angle = (i / steps) * 2 * math.pi;
      final wave = amplitude *
          math.sin(3 * angle + phaseOffset + t * 2 * math.pi * speedMultiplier);
      final r = radius + wave;
      final x = center.dx + r * math.cos(angle);
      final y = center.dy + r * math.sin(angle);
      i == 0 ? path.moveTo(x, y) : path.lineTo(x, y);
    }

    path.close();
    return path;
  }

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);

    // ── Swiggly rings ──
    final rings = [
      (radius: 52.0,  amplitude: 3.0, phase: 0.0, speed: 1.0,  opacity: 0.22),
      (radius: 82.0,  amplitude: 3.5, phase: 2.1, speed: 0.75, opacity: 0.14),
      (radius: 112.0, amplitude: 4.0, phase: 4.2, speed: 0.55, opacity: 0.08),
    ];

    for (final ring in rings) {
      canvas.drawPath(
        _wavyCircle(
          center: center,
          radius: ring.radius,
          amplitude: ring.amplitude,
          phaseOffset: ring.phase,
          speedMultiplier: ring.speed,
        ),
        Paint()
          ..color = AppColors.brandingGreen.withValues(alpha: ring.opacity)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.4,
      );
    }

    // ── Boundary ring (after swiggly lines end) ──
    const boundaryRadius = 132.0;
    canvas.drawCircle(
      center,
      boundaryRadius,
      Paint()
        ..color = AppColors.brandingGreen.withValues(alpha: 0.10)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2,
    );

    // ── Cardinal labels — centered on the boundary ring ──
    const cardinals = [
      (label: 'N', angle: 0.0),
      (label: 'E', angle: 90.0),
      (label: 'S', angle: 180.0),
      (label: 'W', angle: 270.0),
    ];

    for (final c in cardinals) {
      final rad = c.angle * math.pi / 180;
      final pos = Offset(
        center.dx + boundaryRadius * math.sin(rad),
        center.dy - boundaryRadius * math.cos(rad),
      );

      final tp = TextPainter(
        text: TextSpan(
          text: c.label,
          style: const TextStyle(
            color: AppColors.brandingGreen,
            fontSize: 15,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.5,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();

      tp.paint(canvas, pos - Offset(tp.width / 2, tp.height / 2));
    }
  }

  @override
  bool shouldRepaint(_CompassPainter old) => old.t != t;
}
