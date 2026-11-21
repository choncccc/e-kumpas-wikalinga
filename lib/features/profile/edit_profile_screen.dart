import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../../data/photo_picker.dart';
import '../../data/user_profile.dart';
import '../../data/user_repository.dart';
import '../../theme/app_colors.dart';
import '../../widgets/pressable.dart';
import '../../widgets/profile_avatar.dart';
import '../lessons/category_screen.dart' show LessonBackButton;
import '../onboarding/onboarding_draft.dart';
import '../onboarding/steps/photo_step.dart' show showPhotoSourceSheet;
import '../onboarding/widgets/step_parts.dart';

/// Edit name, nickname, birthday and photo, with the sign-up rules.
/// Pops with the saved profile, or null if nothing was saved.
class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({
    super.key,
    required this.profile,
    required this.repository,
    required this.photoPicker,
  });

  final UserProfile profile;
  final UserRepository repository;
  final PhotoPicker photoPicker;

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  late final OnboardingDraft _draft = OnboardingDraft()
    ..name = widget.profile.name
    ..nickname = widget.profile.nickname
    ..birthdate = widget.profile.birthdate
    ..photoPath = widget.profile.photoPath;
  late final TextEditingController _name = TextEditingController(
    text: _draft.name,
  )..addListener(() => _draft.name = _name.text);
  late final TextEditingController _nickname = TextEditingController(
    text: _draft.nickname,
  )..addListener(() => _draft.nickname = _nickname.text);
  bool _saving = false;

  @override
  void dispose() {
    _name.dispose();
    _nickname.dispose();
    _draft.dispose();
    super.dispose();
  }

  bool get _valid =>
      _draft.nameError == null &&
      _draft.nicknameError == null &&
      _draft.birthdateError == null;

  static String? _shown(String? error) =>
      error == null || error.isEmpty ? null : error;

  Future<void> _pickBirthday() async {
    var picked = _draft.birthdate!;
    final today = _draft.today;
    final ok = await showModalBottomSheet<bool>(
      context: context,
      backgroundColor: AppColors.cream,
      showDragHandle: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (sheet) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                height: 200,
                child: CupertinoDatePicker(
                  mode: CupertinoDatePickerMode.date,
                  initialDateTime: picked,
                  minimumYear: today.year - OnboardingDraft.maxAge,
                  maximumDate: today,
                  onDateTimeChanged: (d) => picked = d,
                ),
              ),
              const SizedBox(height: 8),
              PrimaryButton(
                label: 'Done',
                icon: Icons.check_rounded,
                onPressed: () => Navigator.pop(sheet, true),
              ),
            ],
          ),
        ),
      ),
    );
    if (ok == true) {
      _draft.birthdate = DateTime(picked.year, picked.month, picked.day);
    }
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    final p = widget.profile.copyWith(
      name: _draft.name.trim(),
      nickname: _draft.nickname.trim(),
      birthdate: _draft.birthdate,
      age: _draft.age,
      photoPath: _draft.photoPath,
      clearPhoto: _draft.photoPath == null,
    );
    try {
      final saved = await widget.repository.saveProfile(p);
      if (mounted) Navigator.of(context).pop(saved);
    } catch (_) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Couldn’t save your profile. Try again.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.cream,
      body: SafeArea(
        child: ListenableBuilder(
          listenable: _draft,
          builder: (context, _) => ListView(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
            children: [
              Row(
                children: [
                  LessonBackButton(
                    onTap: () => Navigator.of(context).maybePop(),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Text(
                      'Edit profile',
                      style: Theme.of(context).textTheme.headlineLarge,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              Center(
                child: Semantics(
                  button: true,
                  label: 'Change profile picture',
                  child: Pressable(
                    onTap: () => showPhotoSourceSheet(
                      context,
                      draft: _draft,
                      picker: widget.photoPicker,
                    ),
                    scale: 0.94,
                    child: Stack(
                      clipBehavior: Clip.none,
                      children: [
                        ProfileAvatar(
                          nickname: _draft.nickname,
                          photoPath: _draft.photoPath,
                          size: 132,
                        ),
                        Positioned(
                          right: 0,
                          bottom: 4,
                          child: Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              color: AppColors.mustard,
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: AppColors.white,
                                width: 3,
                              ),
                            ),
                            child: const Icon(
                              Icons.photo_camera_rounded,
                              color: AppColors.white,
                              size: 20,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 28),
              const _Label('Name'),
              GlowTextField(
                controller: _name,
                hint: 'e.g. Juan Dela Cruz',
                icon: Icons.person_rounded,
                maxLength: OnboardingDraft.nameMax,
                errorText:
                    _shown(_draft.nameError) ??
                    (_draft.name.trim().isEmpty ? 'Enter your name.' : null),
              ),
              const SizedBox(height: 16),
              const _Label('Nickname'),
              GlowTextField(
                controller: _nickname,
                hint: 'What should we call you?',
                icon: Icons.face_rounded,
                maxLength: OnboardingDraft.nicknameMax,
                errorText:
                    _shown(_draft.nicknameError) ??
                    (_draft.nickname.trim().isEmpty
                        ? 'Enter a nickname.'
                        : null),
              ),
              const SizedBox(height: 16),
              const _Label('Birthday'),
              Semantics(
                button: true,
                label: 'Birthday, ${formatLongDate(_draft.birthdate!)}',
                excludeSemantics: true,
                child: Pressable(
                  onTap: _pickBirthday,
                  scale: 0.98,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 16,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.white,
                      borderRadius: BorderRadius.circular(22),
                      border: Border.all(
                        color: _draft.birthdateError == null
                            ? AppColors.seafoam.withValues(alpha: 0.6)
                            : AppColors.coral,
                        width: 1.6,
                      ),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.cake_rounded, color: AppColors.teal),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            formatLongDate(_draft.birthdate!),
                            style: const TextStyle(
                              fontSize: 16,
                              color: AppColors.ink,
                            ),
                          ),
                        ),
                        Text(
                          '${_draft.age} yrs',
                          style: const TextStyle(color: AppColors.sage),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              if (_shown(_draft.birthdateError) case final err?)
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 6, 12, 0),
                  child: Text(
                    err,
                    style: const TextStyle(
                      color: AppColors.coral,
                      fontSize: 13,
                    ),
                  ),
                ),
              const SizedBox(height: 32),
              PrimaryButton(
                label: 'Save changes',
                icon: Icons.check_rounded,
                loading: _saving,
                onPressed: _valid ? _save : null,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Label extends StatelessWidget {
  const _Label(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(6, 0, 0, 8),
      child: Text(
        text.toUpperCase(),
        style: const TextStyle(
          fontSize: 12.5,
          fontWeight: FontWeight.w600,
          letterSpacing: 1.4,
          color: AppColors.teal,
        ),
      ),
    );
  }
}
