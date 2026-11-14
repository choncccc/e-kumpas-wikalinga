import 'dart:io';

import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_theme.dart';

/// Round profile picture with the green ring from the Profile mockup. Falls
/// back to the nickname's first letter when there's no photo (or the file is
/// gone), and cross-fades whenever the photo changes.
class ProfileAvatar extends StatelessWidget {
  const ProfileAvatar({
    super.key,
    required this.nickname,
    this.photoPath,
    this.size = 116,
    this.ring = true,
  });

  final String nickname;
  final String? photoPath;
  final double size;
  final bool ring;

  @override
  Widget build(BuildContext context) {
    final ringWidth = ring ? size * 0.06 : 0.0;
    final inner = size - ringWidth * 2;
    final dpr = MediaQuery.devicePixelRatioOf(context);

    return Container(
      width: size,
      height: size,
      padding: EdgeInsets.all(ringWidth),
      decoration: BoxDecoration(
        color: ring ? const Color(0xFF42927A) : null,
        shape: BoxShape.circle,
      ),
      child: ClipOval(
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 380),
          switchInCurve: Curves.easeOutCubic,
          transitionBuilder: (child, anim) => FadeTransition(
            opacity: anim,
            child: ScaleTransition(
              scale: Tween(begin: 1.15, end: 1.0).animate(anim),
              child: child,
            ),
          ),
          child: photoPath == null
              ? _Initial(
                  key: const ValueKey('initial'),
                  nickname: nickname,
                  size: inner,
                )
              : Image.file(
                  File(photoPath!),
                  key: ValueKey(photoPath),
                  width: inner,
                  height: inner,
                  fit: BoxFit.cover,
                  cacheWidth: (inner * dpr).round(),
                  gaplessPlayback: true,
                  semanticLabel: 'Profile picture',
                  errorBuilder: (_, _, _) =>
                      _Initial(nickname: nickname, size: inner),
                ),
        ),
      ),
    );
  }
}

class _Initial extends StatelessWidget {
  const _Initial({super.key, required this.nickname, required this.size});

  final String nickname;
  final double size;

  @override
  Widget build(BuildContext context) {
    final letter = nickname.trim().isEmpty
        ? '?'
        : nickname.trim().characters.first.toUpperCase();
    return Container(
      width: size,
      height: size,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFFDDF3FB), AppColors.white, AppColors.leaf],
          stops: [0, 0.55, 1],
        ),
      ),
      alignment: Alignment.center,
      child: Text(
        letter,
        style: TextStyle(
          fontFamily: AppFonts.display,
          fontWeight: FontWeight.w900,
          fontSize: size * 0.42,
          color: AppColors.forest,
        ),
      ),
    );
  }
}
