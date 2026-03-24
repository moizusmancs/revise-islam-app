import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_compass/flutter_compass.dart';

import '../../core/theme/app_colors.dart';
import '../../features/qiblah/models/qibla_response.dart';
import '../../features/qiblah/services/location_service.dart';
import '../../features/qiblah/services/qibla_service.dart';

const _arrowColor = Color(0xFFFF8C55);
const _alignThreshold = 3.0; // degrees — how close = "aligned"

enum _Status { loading, locationDenied, error, ready }

// ─────────────────────────────────────────────────────────────────────────────

class QiblahScreen extends StatefulWidget {
  const QiblahScreen({super.key});

  @override
  State<QiblahScreen> createState() => _QiblahScreenState();
}

class _QiblahScreenState extends State<QiblahScreen>
    with TickerProviderStateMixin {
  // Wave animation (swiggly rings)
  late final AnimationController _waveController;

  // Scale animation for arrow alignment feedback
  late final AnimationController _alignController;
  late final Animation<double> _arrowScale;

  // Services
  final _locationService = LocationService();
  final _qiblaService = QiblaService();

  // State
  _Status _status = _Status.loading;
  String _errorMessage = '';
  double _qiblaDirection = 0; // absolute bearing from API
  double _compassHeading = 0; // live device heading
  bool _isAligned = false;

  StreamSubscription<CompassEvent>? _compassSub;

  static const double _boundaryRadius = 132.0;

  @override
  void initState() {
    super.initState();

    _waveController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 8),
    )..repeat();

    _alignController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 350),
    );

    _arrowScale = Tween<double>(begin: 1.0, end: 1.7).animate(
      CurvedAnimation(parent: _alignController, curve: Curves.easeOut),
    );

    _init();
  }

  Future<void> _init() async {
    setState(() => _status = _Status.loading);
    try {
      final position = await _locationService.getCurrentLocation();
      final QiblaResponse result = await _qiblaService.getQiblaDirection(
        position.latitude,
        position.longitude,
      );

      if (!mounted) return;
      setState(() {
        _qiblaDirection = result.direction;
        _status = _Status.ready;
      });

      _compassSub = FlutterCompass.events?.listen(_onCompassEvent);
    } on LocationException catch (e) {
      if (!mounted) return;
      setState(() {
        _status = _Status.locationDenied;
        _errorMessage = e.message;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _status = _Status.error;
        _errorMessage = e.toString();
      });
    }
  }

  void _onCompassEvent(CompassEvent event) {
    if (!mounted) return;
    final heading = event.heading;
    if (heading == null) return;

    setState(() => _compassHeading = heading);

    // Normalize angle difference to [-180, 180]
    double diff = (_qiblaDirection - heading) % 360;
    if (diff > 180) diff -= 360;
    if (diff < -180) diff += 360;
    final aligned = diff.abs() < _alignThreshold;

    if (aligned && !_isAligned) {
      setState(() => _isAligned = true);
      _alignController.forward();
      HapticFeedback.mediumImpact();
    } else if (!aligned && _isAligned) {
      setState(() => _isAligned = false);
      _alignController.reverse();
    }
  }

  @override
  void dispose() {
    _waveController.dispose();
    _alignController.dispose();
    _compassSub?.cancel();
    super.dispose();
  }

  String _directionLabel(double degrees) {
    final d = degrees % 360;
    if (d < 22.5) return 'N';
    if (d < 67.5) return 'NE';
    if (d < 112.5) return 'E';
    if (d < 157.5) return 'SE';
    if (d < 202.5) return 'S';
    if (d < 247.5) return 'SW';
    if (d < 292.5) return 'W';
    if (d < 337.5) return 'NW';
    return 'N';
  }

  // ─────────────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundWhite,
      appBar: AppBar(title: const Text('Qiblah Finder')),
      body: Center(child: _buildBody()),
    );
  }

  Widget _buildBody() {
    switch (_status) {
      case _Status.loading:
        return const Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(color: AppColors.brandingGreen),
            SizedBox(height: 20),
            Text(
              'Finding your location…',
              style: TextStyle(color: AppColors.textLight, fontSize: 14),
            ),
          ],
        );

      case _Status.locationDenied:
        return _ErrorView(
          icon: Icons.location_off_outlined,
          message: _errorMessage,
          actionLabel: 'Open Settings',
          onAction: _locationService.openAppSettings,
        );

      case _Status.error:
        return _ErrorView(
          icon: Icons.wifi_off_rounded,
          message: _errorMessage,
          actionLabel: 'Retry',
          onAction: _init,
        );

      case _Status.ready:
        return _buildCompass();
    }
  }

  Widget _buildCompass() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        AnimatedBuilder(
          animation: Listenable.merge([_waveController, _alignController]),
          builder: (context, _) {
            return SizedBox(
              width: 300,
              height: 300,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  // Swiggly rings + boundary + cardinals (rotates with heading)
                  CustomPaint(
                    size: const Size(300, 300),
                    painter: _CompassPainter(
                      _waveController.value,
                      _compassHeading,
                    ),
                  ),

                  // Qiblah indicator — fixed at top of boundary ring (12 o'clock)
                  // Arrow reaches here when phone faces Qiblah
                  Transform.translate(
                    offset: const Offset(0, -_boundaryRadius),
                    child: _QiblahIndicator(isAligned: _isAligned),
                  ),

                  // Arrow (fixed) + degree + direction — centered column
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      ScaleTransition(
                        scale: _arrowScale,
                        child: SizedBox(
                          width: 22,
                          height: 20,
                          child: CustomPaint(
                            painter: _ArrowPainter(
                              isAligned: _isAligned,
                              glowProgress: _alignController.value,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        '${_qiblaDirection.toStringAsFixed(0)}°',
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
                        _directionLabel(_qiblaDirection),
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

        AnimatedSwitcher(
          duration: const Duration(milliseconds: 400),
          child: Text(
            _isAligned ? 'You are facing the Qiblah' : 'Point your phone towards Qiblah',
            key: ValueKey(_isAligned),
            style: TextStyle(
              color: _isAligned ? AppColors.brandingGreen : AppColors.textDisabled,
              fontSize: 12,
              fontWeight: _isAligned ? FontWeight.w600 : FontWeight.w400,
              letterSpacing: 0.3,
            ),
          ),
        ),
      ],
    );
  }
}

// ─── Qiblah Indicator (on boundary ring) ─────────────────────────────────────

class _QiblahIndicator extends StatelessWidget {
  final bool isAligned;
  const _QiblahIndicator({required this.isAligned});

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 350),
      curve: Curves.easeOut,
      width: 28,
      height: 28,
      decoration: BoxDecoration(
        color: isAligned ? AppColors.brandingGreen : AppColors.brandingGreen.withValues(alpha: 0.85),
        borderRadius: BorderRadius.circular(8),
        boxShadow: isAligned
            ? [
                BoxShadow(
                  color: AppColors.brandingGreen.withValues(alpha: 0.45),
                  blurRadius: 14,
                  spreadRadius: 3,
                ),
              ]
            : [],
      ),
      child: Padding(
        padding: const EdgeInsets.all(4),
        child: Image.asset('lib/assets/icons/qaabah-icon.png'),
      ),
    );
  }
}

// ─── Error View ───────────────────────────────────────────────────────────────

class _ErrorView extends StatelessWidget {
  final IconData icon;
  final String message;
  final String actionLabel;
  final VoidCallback onAction;

  const _ErrorView({
    required this.icon,
    required this.message,
    required this.actionLabel,
    required this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 48, color: AppColors.textDisabled),
          const SizedBox(height: 16),
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: AppColors.textLight,
              fontSize: 14,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 24),
          ElevatedButton(onPressed: onAction, child: Text(actionLabel)),
        ],
      ),
    );
  }
}

// ─── Arrow Painter ────────────────────────────────────────────────────────────

class _ArrowPainter extends CustomPainter {
  final bool isAligned;
  final double glowProgress; // 0.0 → 1.0

  const _ArrowPainter({required this.isAligned, required this.glowProgress});

  Offset _toward(Offset from, Offset to, double dist) {
    final d = to - from;
    return from + d / d.distance * dist;
  }

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    const r = 5.0;

    final top = Offset(w / 2, 0);
    final bl = Offset(0, h);
    final br = Offset(w, h);

    final path = Path()
      ..moveTo(_toward(top, bl, r).dx, _toward(top, bl, r).dy)
      ..quadraticBezierTo(top.dx, top.dy, _toward(top, br, r).dx, _toward(top, br, r).dy)
      ..lineTo(_toward(br, top, r).dx, _toward(br, top, r).dy)
      ..quadraticBezierTo(br.dx, br.dy, _toward(br, bl, r).dx, _toward(br, bl, r).dy)
      ..lineTo(_toward(bl, br, r).dx, _toward(bl, br, r).dy)
      ..quadraticBezierTo(bl.dx, bl.dy, _toward(bl, top, r).dx, _toward(bl, top, r).dy)
      ..close();

    // Glow layer — fades in with glowProgress
    if (glowProgress > 0) {
      canvas.drawPath(
        path,
        Paint()
          ..color = _arrowColor.withValues(alpha: 0.45 * glowProgress)
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, 10 * glowProgress),
      );
    }

    // Fill
    canvas.drawPath(path, Paint()..color = _arrowColor);
  }

  @override
  bool shouldRepaint(_ArrowPainter old) =>
      old.isAligned != isAligned || old.glowProgress != glowProgress;
}

// ─── Compass Painter (swiggly rings + boundary + N/S/E/W) ────────────────────

class _CompassPainter extends CustomPainter {
  final double t;
  final double compassHeading;
  const _CompassPainter(this.t, this.compassHeading);

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

    // Rotate entire compass so N/E/S/W always reflect real-world directions
    canvas.translate(center.dx, center.dy);
    canvas.rotate(-compassHeading * math.pi / 180);
    canvas.translate(-center.dx, -center.dy);

    final rings = [
      (radius: 52.0, amplitude: 3.0, phase: 0.0, speed: 1.0, opacity: 0.22),
      (radius: 82.0, amplitude: 3.5, phase: 2.1, speed: 0.75, opacity: 0.14),
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

    // Boundary ring
    canvas.drawCircle(
      center,
      132.0,
      Paint()
        ..color = AppColors.brandingGreen.withValues(alpha: 0.10)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2,
    );

    // Cardinal labels
    const cardinals = [
      (label: 'N', angle: 0.0),
      (label: 'E', angle: 90.0),
      (label: 'S', angle: 180.0),
      (label: 'W', angle: 270.0),
    ];

    for (final c in cardinals) {
      final rad = c.angle * math.pi / 180;
      final pos = Offset(
        center.dx + 132.0 * math.sin(rad),
        center.dy - 132.0 * math.cos(rad),
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
  bool shouldRepaint(_CompassPainter old) =>
      old.t != t || old.compassHeading != compassHeading;
}
