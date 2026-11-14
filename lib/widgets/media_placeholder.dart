import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

enum MediaKind { image, video }

/// Stand-in for photos and sign videos that haven't been added yet. A tinted
/// box with an icon and label, plus a slow shimmer so it reads as "media goes
/// here" rather than a broken image. Swap for the real Image/Video later.
class MediaPlaceholder extends StatefulWidget {
  const MediaPlaceholder({
    super.key,
    this.kind = MediaKind.image,
    this.label,
    this.color = AppColors.seafoam,
    this.borderRadius = 0,
    this.compact = false,
    this.iconAlignment = Alignment.center,
  });

  final MediaKind kind;
  final String? label;
  final Color color;
  final double borderRadius;

  /// Icon only, for small slots.
  final bool compact;

  /// Where the icon sits; move it to a corner when text covers the middle.
  final Alignment iconAlignment;

  @override
  State<MediaPlaceholder> createState() => _MediaPlaceholderState();
}

class _MediaPlaceholderState extends State<MediaPlaceholder>
    with SingleTickerProviderStateMixin {
  late final AnimationController _shimmer = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2200),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.of(context).disableAnimations) {
      _shimmer.stop();
    } else if (!_shimmer.isAnimating) {
      _shimmer.repeat();
    }
  }

  @override
  void dispose() {
    _shimmer.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.color;
    final isVideo = widget.kind == MediaKind.video;
    final label = widget.label ?? (isVideo ? 'Sign video' : 'Image');

    return Semantics(
      label: '$label placeholder',
      child: ClipRRect(
        borderRadius: BorderRadius.circular(widget.borderRadius),
        child: Stack(
          fit: StackFit.expand,
          children: [
            DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    c.withValues(alpha: 0.22),
                    c.withValues(alpha: 0.42),
                  ],
                ),
              ),
            ),
            AnimatedBuilder(
              animation: _shimmer,
              builder: (context, _) {
                final x = -1.5 + 3.0 * _shimmer.value;
                return DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment(x - 0.6, -0.4),
                      end: Alignment(x + 0.6, 0.4),
                      colors: [
                        AppColors.white.withValues(alpha: 0),
                        AppColors.white.withValues(alpha: 0.28),
                        AppColors.white.withValues(alpha: 0),
                      ],
                    ),
                  ),
                );
              },
            ),
            Align(
              alignment: widget.iconAlignment,
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Padding(
                  padding: const EdgeInsets.all(8),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: AppColors.white.withValues(alpha: 0.75),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          isVideo
                              ? Icons.play_arrow_rounded
                              : Icons.image_outlined,
                          color: AppColors.slate.withValues(alpha: 0.7),
                          size: isVideo ? 30 : 24,
                        ),
                      ),
                      if (!widget.compact) ...[
                        const SizedBox(height: 6),
                        Text(
                          label,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 0.3,
                            color: AppColors.slate.withValues(alpha: 0.75),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
