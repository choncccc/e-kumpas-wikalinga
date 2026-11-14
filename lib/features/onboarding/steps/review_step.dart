import 'package:flutter/material.dart';

import '../../../theme/app_colors.dart';
import '../../../theme/app_theme.dart';
import '../../../widgets/pressable.dart';
import '../../../widgets/profile_avatar.dart';
import '../../../widgets/staggered_entrance.dart';
import '../onboarding_draft.dart';
import '../widgets/step_parts.dart';

/// Profile-card summary styled after the Profile mockup. Tapping a row jumps
/// back to that step.
class ReviewStep extends StatelessWidget {
  const ReviewStep({super.key, required this.draft, required this.onEdit});

  final OnboardingDraft draft;
  final ValueChanged<int> onEdit;

  @override
  Widget build(BuildContext context) {
    final age = draft.age ?? 0;
    return StaggeredEntrance(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      stagger: const Duration(milliseconds: 80),
      children: [
        const StepHeader(
          eyebrow: 'Almost there',
          title: 'Does this look right?',
          subtitle: 'Tap anything you want to change.',
        ),
        const SizedBox(height: 24),
        Center(
          child: Semantics(
            button: true,
            label: 'Edit profile picture',
            child: Pressable(
              onTap: () => onEdit(3),
              child: TweenAnimationBuilder<double>(
                tween: Tween(begin: 0, end: 1),
                duration: const Duration(milliseconds: 700),
                curve: Curves.elasticOut,
                builder: (context, t, child) =>
                    Transform.scale(scale: 0.6 + 0.4 * t, child: child),
                child: ProfileAvatar(
                  nickname: draft.nickname,
                  photoPath: draft.photoPath,
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 20),
        _InfoRow(
          label: 'Name',
          value: draft.name.trim(),
          onTap: () => onEdit(1),
        ),
        _InfoRow(
          label: 'Nickname',
          value: draft.nickname.trim(),
          onTap: () => onEdit(2),
        ),
        _InfoRow(
          label: 'Birthday',
          value: draft.birthdate == null
              ? ''
              : formatLongDate(draft.birthdate!),
          onTap: () => onEdit(4),
        ),
        _InfoRow(
          label: 'Age',
          // Age comes from the birthday, so editing it means editing that.
          value: '$age year${age == 1 ? '' : 's'} old',
          onTap: () => onEdit(4),
        ),
      ],
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({
    required this.label,
    required this.value,
    required this.onTap,
  });

  final String label;
  final String value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Semantics(
        button: true,
        label: 'Edit $label: $value',
        excludeSemantics: true,
        child: Pressable(
          onTap: onTap,
          scale: 0.97,
          child: Container(
            padding: const EdgeInsets.fromLTRB(8, 8, 14, 8),
            decoration: BoxDecoration(
              color: AppColors.white,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: AppColors.butter, width: 2),
            ),
            child: Row(
              children: [
                Container(
                  width: 104,
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  decoration: BoxDecoration(
                    color: AppColors.butter,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    label.toUpperCase(),
                    style: const TextStyle(
                      fontFamily: AppFonts.display,
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                      letterSpacing: 0.8,
                      color: AppColors.teal,
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Text(
                    value,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontFamily: AppFonts.display,
                      fontWeight: FontWeight.w700,
                      fontSize: 17,
                      color: AppColors.slate,
                    ),
                  ),
                ),
                const Icon(
                  Icons.edit_rounded,
                  size: 18,
                  color: AppColors.seafoam,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
