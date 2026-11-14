import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// Soft palette-coloured shapes that drift slowly behind the content.
class DriftingBlobs extends StatefulWidget {
  const DriftingBlobs({super.key, this.intensity = 1});

  /// 0..1. Lets a parent fade the blobs in or tone them down per screen.
  final double intensity;

  @override
  State<DriftingBlobs> createState() => _DriftingBlobsState();
}

class _DriftingBlobsState extends State<DriftingBlobs>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 18),
  )..repeat();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Respect the system "remove animations" setting.
    final reduceMotion = MediaQuery.of(context).disableAnimations;
    if (reduceMotion && _controller.isAnimating) {
      _controller.stop();
    } else if (!reduceMotion && !_controller.isAnimating) {
      _controller.repeat();
    }
  }

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) => CustomPaint(
          painter: _BlobPainter(_controller.value, widget.intensity),
          size: Size.infinite,
        ),
      ),
    );
  }
}

class _Blob {
  const _Blob(this.color, this.anchor, this.radius, this.orbit, this.phase);
  final Color color;
  final Offset anchor; // fraction of the canvas
  final double radius; // fraction of the shortest side
  final double orbit; // drift distance in logical px
  final double phase;
}

class _BlobPainter extends CustomPainter {
  _BlobPainter(this.t, this.intensity);

  final double t;
  final double intensity;

  static const _blobs = [
    _Blob(AppColors.aqua, Offset(0.05, 0.08), 0.55, 26, 0.0),
    _Blob(AppColors.butter, Offset(1.0, 0.22), 0.45, 32, 0.33),
    _Blob(AppColors.leaf, Offset(0.9, 0.95), 0.6, 22, 0.66),
    _Blob(AppColors.mustard, Offset(0.0, 0.78), 0.28, 30, 0.5),
  ];

  @override
  void paint(Canvas canvas, Size size) {
    final shortest = size.shortestSide;
    for (final b in _blobs) {
      final angle = (t + b.phase) * 2 * math.pi;
      final center = Offset(
        b.anchor.dx * size.width + math.cos(angle) * b.orbit,
        b.anchor.dy * size.height + math.sin(angle * 2) * b.orbit * 0.6,
      );
      final r = b.radius * shortest * (1 + 0.04 * math.sin(angle * 3));
      final paint = Paint()
        ..shader = RadialGradient(
          colors: [
            b.color.withValues(alpha: 0.42 * intensity),
            b.color.withValues(alpha: 0),
          ],
        ).createShader(Rect.fromCircle(center: center, radius: r));
      canvas.drawCircle(center, r, paint);
    }
  }

  @override
  bool shouldRepaint(_BlobPainter old) =>
      old.t != t || old.intensity != intensity;
}
