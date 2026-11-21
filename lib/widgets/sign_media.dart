import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

import '../theme/app_colors.dart';
import 'media_placeholder.dart';

/// Shows how a sign is made: a muted, looping clip (.mp4) or a still (.jpg)
/// from assets/signs/. Falls back to [MediaPlaceholder] when there's no
/// recording or it can't be played.
///
/// Tap a clip to pause or resume; the speed chip toggles slow motion, which
/// helps when following a handshape. With reduced motion on, clips start
/// paused.
class SignMedia extends StatefulWidget {
  const SignMedia({
    super.key,
    required this.asset,
    required this.label,
    this.color = AppColors.seafoam,
    this.borderRadius = 0,
    this.showControls = true,
  });

  /// Asset path, or null when the sign has no recording yet.
  final String? asset;

  /// What is being signed, for screen readers. Pass something neutral (not
  /// the answer) in quizzes.
  final String label;
  final Color color;
  final double borderRadius;

  /// Speed chip and paused indicator. Taps still pause either way.
  final bool showControls;

  @override
  State<SignMedia> createState() => _SignMediaState();
}

class _SignMediaState extends State<SignMedia> {
  VideoPlayerController? _video;
  bool _failed = false;
  bool _slow = false;

  bool get _isVideo => widget.asset?.endsWith('.mp4') ?? false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_video == null && _isVideo && !_failed) _load();
  }

  @override
  void didUpdateWidget(SignMedia old) {
    super.didUpdateWidget(old);
    if (old.asset != widget.asset) {
      _disposeVideo();
      _failed = false;
      _slow = false;
      if (_isVideo) _load();
    }
  }

  Future<void> _load() async {
    final autoplay = !MediaQuery.of(context).disableAnimations;
    final controller = VideoPlayerController.asset(
      widget.asset!,
      videoPlayerOptions: VideoPlayerOptions(mixWithOthers: true),
    );
    _video = controller;
    controller.addListener(_onVideoChanged);
    try {
      await controller.initialize();
      await controller.setLooping(true);
      await controller.setVolume(0);
      if (autoplay) await controller.play();
    } catch (_) {
      // No video backend (e.g. widget tests) or a bad file: show the
      // placeholder rather than an error.
      if (_video == controller) {
        _disposeVideo();
        if (mounted) setState(() => _failed = true);
      }
      return;
    }
    if (mounted && _video == controller) setState(() {});
  }

  void _disposeVideo() {
    _video?.removeListener(_onVideoChanged);
    _video?.dispose();
    _video = null;
  }

  @override
  void dispose() {
    _disposeVideo();
    super.dispose();
  }

  bool _wasPlaying = false;

  /// Rebuilds when playback starts or stops (not on every frame).
  void _onVideoChanged() {
    final playing = _video?.value.isPlaying ?? false;
    if (playing != _wasPlaying && mounted) {
      setState(() => _wasPlaying = playing);
    }
  }

  void _togglePlay() {
    final v = _video;
    if (v == null || !v.value.isInitialized) return;
    v.value.isPlaying ? v.pause() : v.play();
  }

  void _toggleSpeed() {
    final v = _video;
    if (v == null) return;
    setState(() => _slow = !_slow);
    v.setPlaybackSpeed(_slow ? 0.5 : 1);
  }

  Widget _placeholder() => MediaPlaceholder(
    kind: _isVideo ? MediaKind.video : MediaKind.image,
    label: widget.asset == null ? 'Sign video coming soon' : null,
    color: widget.color,
    borderRadius: widget.borderRadius,
  );

  @override
  Widget build(BuildContext context) {
    final asset = widget.asset;
    if (asset == null || _failed) return _placeholder();

    final backdrop = widget.color.withValues(alpha: 0.18);
    Widget child;
    if (!_isVideo) {
      child = Semantics(
        image: true,
        label: widget.label,
        child: ColoredBox(
          color: backdrop,
          child: Image.asset(
            asset,
            fit: BoxFit.contain,
            errorBuilder: (_, _, _) => _placeholder(),
          ),
        ),
      );
    } else {
      final v = _video;
      if (v == null || !v.value.isInitialized) return _placeholder();
      final playing = v.value.isPlaying;
      child = Semantics(
        label: widget.label,
        hint: playing ? 'Double tap to pause' : 'Double tap to play',
        button: true,
        child: GestureDetector(
          onTap: _togglePlay,
          child: ColoredBox(
            color: backdrop,
            child: Stack(
              fit: StackFit.expand,
              children: [
                Center(
                  child: AspectRatio(
                    aspectRatio: v.value.aspectRatio,
                    child: VideoPlayer(v),
                  ),
                ),
                if (widget.showControls) ...[
                  AnimatedOpacity(
                    opacity: playing ? 0 : 1,
                    duration: const Duration(milliseconds: 200),
                    child: Center(
                      child: Container(
                        width: 56,
                        height: 56,
                        decoration: BoxDecoration(
                          color: AppColors.white.withValues(alpha: 0.85),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.play_arrow_rounded,
                          color: AppColors.teal,
                          size: 36,
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    right: 10,
                    bottom: 10,
                    child: _SpeedChip(slow: _slow, onTap: _toggleSpeed),
                  ),
                ],
              ],
            ),
          ),
        ),
      );
    }
    return ClipRRect(
      borderRadius: BorderRadius.circular(widget.borderRadius),
      child: child,
    );
  }
}

class _SpeedChip extends StatelessWidget {
  const _SpeedChip({required this.slow, required this.onTap});

  final bool slow;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      toggled: slow,
      label: 'Slow motion',
      excludeSemantics: true,
      child: Material(
        color: slow
            ? AppColors.mustard
            : AppColors.white.withValues(alpha: 0.85),
        shape: const StadiumBorder(),
        child: InkWell(
          customBorder: const StadiumBorder(),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.slow_motion_video_rounded,
                  size: 18,
                  color: AppColors.ink,
                ),
                const SizedBox(width: 4),
                Text(
                  slow ? '0.5×' : '1×',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: AppColors.ink,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
