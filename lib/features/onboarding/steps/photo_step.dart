import 'package:flutter/material.dart';

import '../../../data/photo_picker.dart';
import '../../../theme/app_colors.dart';
import '../../../theme/app_theme.dart';
import '../../../widgets/pressable.dart';
import '../../../widgets/profile_avatar.dart';
import '../../../widgets/staggered_entrance.dart';
import '../onboarding_draft.dart';
import '../widgets/step_parts.dart';

/// Optional profile picture: camera or gallery, with a skip.
class PhotoStep extends StatelessWidget {
  const PhotoStep({super.key, required this.draft, required this.picker});

  final OnboardingDraft draft;
  final PhotoPicker picker;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: draft,
      builder: (context, _) {
        final hasPhoto = draft.photoPath != null;
        return StaggeredEntrance(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const StepHeader(
              eyebrow: 'Step 3 · Photo',
              title: 'Add a profile picture',
              subtitle:
                  'Totally optional. You can skip this and add one later.',
            ),
            const SizedBox(height: 36),
            Center(
              child: Semantics(
                button: true,
                label: hasPhoto
                    ? 'Change profile picture'
                    : 'Add profile picture',
                child: Pressable(
                  onTap: () => showPhotoSourceSheet(
                    context,
                    draft: draft,
                    picker: picker,
                  ),
                  scale: 0.94,
                  child: SizedBox(
                    width: 196,
                    height: 196,
                    child: Stack(
                      clipBehavior: Clip.none,
                      children: [
                        ProfileAvatar(
                          nickname: draft.nickname,
                          photoPath: draft.photoPath,
                          size: 196,
                        ),
                        Positioned(
                          right: 6,
                          bottom: 6,
                          child: _CameraBadge(hasPhoto: hasPhoto),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 28),
            Row(
              children: [
                Expanded(
                  child: _SourceButton(
                    icon: Icons.photo_camera_rounded,
                    label: 'Camera',
                    onTap: () =>
                        pickInto(context, draft, picker, PhotoSource.camera),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _SourceButton(
                    icon: Icons.photo_library_rounded,
                    label: 'Gallery',
                    onTap: () =>
                        pickInto(context, draft, picker, PhotoSource.gallery),
                  ),
                ),
              ],
            ),
            AnimatedSize(
              duration: const Duration(milliseconds: 280),
              curve: Curves.easeOutCubic,
              child: hasPhoto
                  ? Padding(
                      padding: const EdgeInsets.only(top: 14),
                      child: Center(
                        child: TextButton.icon(
                          onPressed: () => draft.photoPath = null,
                          icon: const Icon(
                            Icons.delete_outline_rounded,
                            color: AppColors.coral,
                          ),
                          label: const Text(
                            'Remove photo',
                            style: TextStyle(color: AppColors.coral),
                          ),
                        ),
                      ),
                    )
                  : const SizedBox(width: double.infinity),
            ),
          ],
        );
      },
    );
  }
}

/// Runs the picker and stores the result in the draft, with friendly errors.
Future<void> pickInto(
  BuildContext context,
  OnboardingDraft draft,
  PhotoPicker picker,
  PhotoSource source,
) async {
  final messenger = ScaffoldMessenger.of(context);
  try {
    final path = await picker.pick(source);
    if (path != null) draft.photoPath = path;
  } on PhotoPermissionDenied {
    messenger.showSnackBar(
      SnackBar(
        content: Text(
          source == PhotoSource.camera
              ? 'Camera access is off. You can turn it on in Settings.'
              : 'Photo access is off. You can turn it on in Settings.',
        ),
      ),
    );
  } catch (_) {
    messenger.showSnackBar(
      const SnackBar(
        content: Text('Couldn’t load that photo. Try another one.'),
      ),
    );
  }
}

/// Bottom sheet with camera / gallery / remove, used wherever the avatar is
/// tapped.
Future<void> showPhotoSourceSheet(
  BuildContext context, {
  required OnboardingDraft draft,
  required PhotoPicker picker,
}) async {
  final source = await showModalBottomSheet<PhotoSource?>(
    context: context,
    backgroundColor: AppColors.cream,
    showDragHandle: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
    ),
    builder: (sheetContext) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _SheetTile(
              icon: Icons.photo_camera_rounded,
              label: 'Take a photo',
              onTap: () => Navigator.pop(sheetContext, PhotoSource.camera),
            ),
            _SheetTile(
              icon: Icons.photo_library_rounded,
              label: 'Choose from gallery',
              onTap: () => Navigator.pop(sheetContext, PhotoSource.gallery),
            ),
            if (draft.photoPath != null)
              _SheetTile(
                icon: Icons.delete_outline_rounded,
                label: 'Remove photo',
                color: AppColors.coral,
                onTap: () {
                  draft.photoPath = null;
                  Navigator.pop(sheetContext);
                },
              ),
          ],
        ),
      ),
    ),
  );
  if (source != null && context.mounted) {
    await pickInto(context, draft, picker, source);
  }
}

class _CameraBadge extends StatelessWidget {
  const _CameraBadge({required this.hasPhoto});

  final bool hasPhoto;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 52,
      height: 52,
      decoration: BoxDecoration(
        color: AppColors.mustard,
        shape: BoxShape.circle,
        border: Border.all(color: AppColors.cream, width: 4),
        boxShadow: [
          BoxShadow(
            color: AppColors.mustard.withValues(alpha: 0.4),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 260),
        transitionBuilder: (c, a) => RotationTransition(
          turns: Tween(begin: 0.6, end: 1.0).animate(a),
          child: ScaleTransition(scale: a, child: c),
        ),
        child: Icon(
          hasPhoto ? Icons.edit_rounded : Icons.add_a_photo_rounded,
          key: ValueKey(hasPhoto),
          color: AppColors.ink,
          size: 22,
        ),
      ),
    );
  }
}

class _SourceButton extends StatelessWidget {
  const _SourceButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: label,
      excludeSemantics: true,
      child: Pressable(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 16),
          decoration: BoxDecoration(
            color: AppColors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: AppColors.seafoam.withValues(alpha: 0.6),
              width: 1.6,
            ),
          ),
          child: Column(
            children: [
              Icon(icon, color: AppColors.teal, size: 28),
              const SizedBox(height: 6),
              Text(
                label,
                style: const TextStyle(
                  fontFamily: AppFonts.body,
                  fontWeight: FontWeight.w600,
                  color: AppColors.teal,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SheetTile extends StatelessWidget {
  const _SheetTile({
    required this.icon,
    required this.label,
    required this.onTap,
    this.color = AppColors.teal,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon, color: color),
      title: Text(
        label,
        style: TextStyle(color: color, fontWeight: FontWeight.w600),
      ),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      onTap: onTap,
    );
  }
}
