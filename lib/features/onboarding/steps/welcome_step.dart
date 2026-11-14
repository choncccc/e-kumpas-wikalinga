import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../theme/app_colors.dart';
import '../../../theme/app_theme.dart';
import '../../../widgets/staggered_entrance.dart';

/// Intro shown before the questions: a waving hand and the app name.
class WelcomeStep extends StatelessWidget {
  const WelcomeStep({super.key});

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return StaggeredEntrance(
      stagger: const Duration(milliseconds: 110),
      itemDuration: const Duration(milliseconds: 650),
      offset: 36,
      children: [
        const WavingHand(),
        const SizedBox(height: 36),
        Text('Kumusta!', style: text.displayLarge?.copyWith(fontSize: 56)),
        const SizedBox(height: 6),
        const Text(
          'Welcome to e-Kumpas Wikalinga',
          style: TextStyle(
            fontFamily: AppFonts.display,
            fontWeight: FontWeight.w700,
            fontSize: 22,
            color: AppColors.teal,
          ),
        ),
        const SizedBox(height: 16),
        Text(
          'Learn Filipino Sign Language for everyday talk and healthcare, '
          'one sign at a time. First, let’s get to know you.',
          style: text.bodyLarge,
        ),
      ],
    );
  }
}

/// Hand icon in a mustard badge that waves on a loop.
class WavingHand extends StatefulWidget {
  const WavingHand({super.key, this.size = 112});

  final double size;

  @override
  State<WavingHand> createState() => _WavingHandState();
}

class _WavingHandState extends State<WavingHand>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2400),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.of(context).disableAnimations) {
      _controller.stop();
    } else if (!_controller.isAnimating) {
      _controller.repeat();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  /// Two quick waves in the first ~half of each cycle, then a rest.
  double _angle(double t) {
    if (t > 0.55) return 0;
    final p = t / 0.55;
    final envelope = math.sin(p * math.pi);
    return math.sin(p * 4 * math.pi) * 0.38 * envelope;
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.size;
    return Container(
      width: s,
      height: s,
      decoration: BoxDecoration(
        color: AppColors.mustard,
        borderRadius: BorderRadius.circular(s * 0.32),
        boxShadow: [
          BoxShadow(
            color: AppColors.mustard.withValues(alpha: 0.45),
            blurRadius: 30,
            offset: const Offset(0, 14),
          ),
        ],
      ),
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) => Transform.rotate(
          angle: _angle(_controller.value),
          alignment: const Alignment(0.2, 0.7),
          child: child,
        ),
        child: Icon(
          Icons.waving_hand_rounded,
          size: s * 0.56,
          color: AppColors.white,
        ),
      ),
    );
  }
}
