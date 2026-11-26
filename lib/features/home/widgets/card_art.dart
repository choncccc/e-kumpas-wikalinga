import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../theme/app_colors.dart';

/// Drawn artwork for the Home feature cards, in place of a photo. The motif
/// sits in the space above the card's caption pill, on a soft gradient with
/// a large faint icon behind it.
class CardArt extends StatelessWidget {
  const CardArt({
    super.key,
    required this.color,
    required this.backdropIcon,
    required this.motif,
  });

  final Color color;
  final IconData backdropIcon;
  final Widget motif;

  /// Height kept clear at the bottom for the caption pill.
  static const _pill = 58.0;

  @override
  Widget build(BuildContext context) {
    final light = Color.lerp(color, AppColors.white, 0.35)!;
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [light, color],
        ),
      ),
      child: Stack(
        fit: StackFit.expand,
        children: [
          Positioned(
            left: -14,
            top: -18,
            child: Transform.rotate(
              angle: -0.25,
              child: Icon(
                backdropIcon,
                size: 96,
                color: AppColors.white.withValues(alpha: 0.22),
              ),
            ),
          ),
          Positioned(
            top: 8,
            right: 10,
            left: 40,
            bottom: _pill,
            child: FittedBox(alignment: Alignment.centerRight, child: motif),
          ),
        ],
      ),
    );
  }
}

/// Quiz: an answer sheet showing a hand sign, a question bubble and a tick.
class QuizMotif extends StatelessWidget {
  const QuizMotif({super.key});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 104,
      height: 56,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // Answer sheet.
          Positioned(
            left: 18,
            top: 2,
            child: Transform.rotate(
              angle: -0.12,
              child: Container(
                width: 50,
                height: 52,
                padding: const EdgeInsets.fromLTRB(6, 5, 6, 5),
                decoration: _card(AppColors.white),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(
                      Icons.sign_language_rounded,
                      size: 22,
                      color: AppColors.teal,
                    ),
                    const SizedBox(height: 3),
                    for (final w in [34.0, 24.0])
                      Container(
                        width: w,
                        height: 4,
                        margin: const EdgeInsets.only(bottom: 3),
                        decoration: BoxDecoration(
                          color: AppColors.cloud,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
          // Question bubble.
          Positioned(
            right: 0,
            top: 0,
            child: _Badge(
              color: AppColors.teal,
              size: 30,
              child: const Text(
                '?',
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 19,
                  color: AppColors.white,
                  height: 1,
                ),
              ),
            ),
          ),
          // Correct-answer tick.
          const Positioned(
            right: 12,
            bottom: 0,
            child: _Badge(
              color: AppColors.forest,
              size: 22,
              child: Icon(
                Icons.check_rounded,
                size: 16,
                color: AppColors.white,
              ),
            ),
          ),
          // Small star, for "score".
          Positioned(
            left: 0,
            bottom: 4,
            child: Icon(
              Icons.star_rounded,
              size: 18,
              color: AppColors.white.withValues(alpha: 0.9),
            ),
          ),
        ],
      ),
    );
  }
}

/// Memory Card Flip: a fan of cards, face down, mid-flip and face up.
class MemoryMotif extends StatelessWidget {
  const MemoryMotif({super.key});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 104,
      height: 58,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // Face down.
          Positioned(
            left: 0,
            top: 8,
            child: Transform.rotate(
              angle: -0.22,
              child: _MiniCard(
                color: AppColors.teal,
                child: const Text(
                  '?',
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 18,
                    color: AppColors.mustard,
                    height: 1,
                  ),
                ),
              ),
            ),
          ),
          // Mid-flip: narrowed as if turning on its vertical axis.
          Positioned(
            left: 36,
            top: 2,
            child: Transform(
              alignment: Alignment.center,
              transform: Matrix4.identity()
                ..setEntry(3, 2, 0.004)
                ..rotateY(math.pi / 3.2),
              child: _MiniCard(
                color: AppColors.white,
                child: const Icon(
                  Icons.sign_language_rounded,
                  size: 20,
                  color: AppColors.teal,
                ),
              ),
            ),
          ),
          // Face up, matched.
          Positioned(
            right: 0,
            top: 8,
            child: Transform.rotate(
              angle: 0.2,
              child: _MiniCard(
                color: AppColors.white,
                child: const Icon(
                  Icons.sign_language_rounded,
                  size: 20,
                  color: AppColors.teal,
                ),
              ),
            ),
          ),
          const Positioned(
            right: -4,
            top: -2,
            child: _Badge(
              color: AppColors.coral,
              size: 18,
              child: Icon(
                Icons.favorite_rounded,
                size: 11,
                color: AppColors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

BoxDecoration _card(Color color) => BoxDecoration(
  color: color,
  borderRadius: BorderRadius.circular(8),
  boxShadow: [
    BoxShadow(
      color: AppColors.ink.withValues(alpha: 0.18),
      blurRadius: 6,
      offset: const Offset(0, 3),
    ),
  ],
);

class _MiniCard extends StatelessWidget {
  const _MiniCard({required this.color, required this.child});

  final Color color;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 34,
      height: 46,
      alignment: Alignment.center,
      decoration: _card(color),
      child: child,
    );
  }
}

class _Badge extends StatelessWidget {
  const _Badge({required this.color, required this.size, required this.child});

  final Color color;
  final double size;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        border: Border.all(color: AppColors.white, width: 2),
      ),
      child: child,
    );
  }
}
