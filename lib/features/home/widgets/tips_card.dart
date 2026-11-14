import 'package:flutter/material.dart';

import '../../../data/learning_content.dart';
import '../../../theme/app_colors.dart';
import '../../../widgets/pressable.dart';

/// "Sign Language Tips" card. Shows one tip at a time and moves to the next on
/// its own (or on tap), with a bar that fills while each tip is on screen.
class TipsCard extends StatefulWidget {
  const TipsCard({
    super.key,
    this.tips = LearningContent.tips,
    this.interval = const Duration(seconds: 7),
  });

  final List<SignTip> tips;
  final Duration interval;

  @override
  State<TipsCard> createState() => _TipsCardState();
}

class _TipsCardState extends State<TipsCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _timer =
      AnimationController(vsync: this, duration: widget.interval)
        ..addStatusListener((s) {
          if (s == AnimationStatus.completed) _advance();
        });
  int _index = 0;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // No auto-advance when the system asks for reduced motion; taps still work.
    if (!MediaQuery.of(context).disableAnimations && !_timer.isAnimating) {
      _timer.forward(from: _timer.value);
    }
  }

  void _advance() {
    setState(() => _index = (_index + 1) % widget.tips.length);
    if (!MediaQuery.of(context).disableAnimations) _timer.forward(from: 0);
  }

  @override
  void dispose() {
    _timer.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tip = widget.tips[_index];
    return Semantics(
      button: true,
      label:
          'Sign language tip ${_index + 1} of ${widget.tips.length}: ${tip.title}. ${tip.body}',
      hint: 'Tap for the next tip',
      excludeSemantics: true,
      child: Pressable(
        onTap: _advance,
        scale: 0.97,
        child: Container(
          padding: const EdgeInsets.fromLTRB(14, 16, 14, 14),
          decoration: BoxDecoration(
            color: AppColors.cloud,
            borderRadius: BorderRadius.circular(22),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(
                children: [
                  Icon(
                    Icons.lightbulb_rounded,
                    size: 18,
                    color: AppColors.olive,
                  ),
                  SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'SIGN LANGUAGE TIPS',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 11.5,
                        letterSpacing: 0.4,
                        color: AppColors.ink,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Expanded(
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 450),
                  switchInCurve: Curves.easeOutCubic,
                  switchOutCurve: Curves.easeInCubic,
                  layoutBuilder: (current, previous) => Stack(
                    alignment: Alignment.topLeft,
                    children: [...previous, ?current],
                  ),
                  transitionBuilder: (child, anim) => FadeTransition(
                    opacity: anim,
                    child: SlideTransition(
                      position: Tween(
                        begin: Offset(
                          0,
                          child.key == ValueKey(_index) ? 0.12 : -0.12,
                        ),
                        end: Offset.zero,
                      ).animate(anim),
                      child: child,
                    ),
                  ),
                  // Clips instead of overflowing if large system text is set.
                  child: SingleChildScrollView(
                    key: ValueKey(_index),
                    physics: const NeverScrollableScrollPhysics(),
                    child: _TipBody(tip: tip),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  for (var i = 0; i < widget.tips.length; i++)
                    Expanded(
                      child: Padding(
                        padding: EdgeInsets.only(
                          right: i == widget.tips.length - 1 ? 0 : 4,
                        ),
                        child: _Segment(
                          state: i < _index ? 1 : (i == _index ? null : 0),
                          timer: _timer,
                        ),
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TipBody extends StatelessWidget {
  const _TipBody({required this.tip});

  final SignTip tip;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: AppColors.white,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            tip.title,
            style: const TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 13,
              color: AppColors.ink,
              height: 1.25,
            ),
          ),
        ),
        const SizedBox(height: 10),
        Text(
          tip.body,
          style: const TextStyle(
            fontSize: 13,
            color: AppColors.slate,
            height: 1.45,
          ),
        ),
      ],
    );
  }
}

/// One slice of the progress strip: done (1), upcoming (0) or live (null).
class _Segment extends StatelessWidget {
  const _Segment({required this.state, required this.timer});

  final double? state;
  final Animation<double> timer;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(2),
      child: SizedBox(
        height: 4,
        child: AnimatedBuilder(
          animation: timer,
          builder: (context, _) => LinearProgressIndicator(
            value: state ?? timer.value,
            backgroundColor: AppColors.white.withValues(alpha: 0.6),
            color: AppColors.teal,
          ),
        ),
      ),
    );
  }
}
