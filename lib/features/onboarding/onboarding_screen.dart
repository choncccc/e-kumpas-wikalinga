import 'dart:async';

import 'package:flutter/material.dart';

import '../../data/photo_picker.dart';
import '../../data/user_profile.dart';
import '../../data/user_repository.dart';
import '../../theme/app_colors.dart';
import '../../widgets/drifting_blobs.dart';
import '../../widgets/pressable.dart';
import 'onboarding_draft.dart';
import 'steps/birthdate_step.dart';
import 'steps/photo_step.dart';
import 'steps/review_step.dart';
import 'steps/text_steps.dart';
import 'steps/welcome_step.dart';

/// Step-by-step sign-up:
/// welcome → name → nickname → photo → birthday → review.
/// Age is worked out from the birthday rather than asked.
class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({
    super.key,
    required this.repository,
    required this.onComplete,
    required this.photoPicker,
    this.draft,
  });

  final UserRepository repository;
  final ValueChanged<UserProfile> onComplete;
  final PhotoPicker photoPicker;

  /// Injectable for tests; a fresh draft is used otherwise.
  final OnboardingDraft? draft;

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  static const _welcome = 0,
      _name = 1,
      _nickname = 2,
      _photo = 3,
      _birthdate = 4,
      _review = 5;
  static const _questionCount = 4;

  late final OnboardingDraft _draft = widget.draft ?? OnboardingDraft();
  int _step = _welcome;
  bool _forward = true;
  bool _editingFromReview = false;
  bool _saving = false;

  @override
  void dispose() {
    if (widget.draft == null) _draft.dispose();
    super.dispose();
  }

  bool get _canContinue => switch (_step) {
    _name => _draft.nameError == null,
    _nickname => _draft.nicknameError == null,
    _birthdate => _draft.birthdateError == null,
    _ => true,
  };

  void _goTo(int step) {
    if (step == _birthdate && _draft.birthdate == null) {
      _draft.birthdate = DateTime(2000);
    }
    FocusScope.of(context).unfocus();
    setState(() {
      _forward = step > _step;
      _step = step;
    });
  }

  void _next() {
    if (!_canContinue || _saving) return;
    if (_step == _review) {
      _save();
    } else if (_editingFromReview) {
      _editingFromReview = false;
      _goTo(_review);
    } else {
      _goTo(_step + 1);
    }
  }

  void _back() {
    if (_step == _welcome || _saving) return;
    if (_editingFromReview) {
      _editingFromReview = false;
      // Discard nothing: edits are already in the draft. Go back to review only
      // if the current answer is still valid.
      if (_canContinue) return _goTo(_review);
    }
    _goTo(_step - 1);
  }

  void _editFromReview(int step) {
    _editingFromReview = true;
    _goTo(step);
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      // Hold the spinner briefly so the hand-off doesn't flash.
      final results = await Future.wait([
        widget.repository.saveProfile(_draft.toProfile()),
        Future<void>.delayed(const Duration(milliseconds: 650)),
      ]);
      if (!mounted) return;
      widget.onComplete(results.first as UserProfile);
    } catch (_) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Couldn’t save your profile. Please try again.'),
        ),
      );
    }
  }

  String get _buttonLabel {
    if (_step == _welcome) return 'Get started';
    if (_step == _review) return 'Let’s start signing!';
    if (_editingFromReview) return 'Done';
    if (_step == _photo && _draft.photoPath == null) return 'Skip for now';
    return 'Continue';
  }

  Widget _buildStep() => switch (_step) {
    _welcome => const WelcomeStep(),
    _name => NameStep(draft: _draft, onSubmit: _next),
    _nickname => NicknameStep(draft: _draft, onSubmit: _next),
    _photo => PhotoStep(draft: _draft, picker: widget.photoPicker),
    _birthdate => BirthdateStep(draft: _draft),
    _ => ReviewStep(draft: _draft, onEdit: _editFromReview),
  };

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: _step == _welcome,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _back();
      },
      child: Scaffold(
        backgroundColor: AppColors.cream,
        body: Stack(
          children: [
            const Positioned.fill(child: DriftingBlobs()),
            SafeArea(
              child: Column(
                children: [
                  _TopBar(
                    visible: _step != _welcome,
                    progress:
                        (_step.clamp(0, _questionCount + 1)) /
                        (_questionCount + 1),
                    label: _step == _review
                        ? 'Review'
                        : 'Step $_step of $_questionCount',
                    onBack: _back,
                  ),
                  Expanded(child: _buildSwitcher()),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(24, 8, 24, 20),
                    child: ListenableBuilder(
                      listenable: _draft,
                      builder: (context, _) => PrimaryButton(
                        label: _buttonLabel,
                        loading: _saving,
                        icon: _step == _review
                            ? Icons.check_rounded
                            : _buttonLabel == 'Skip for now'
                            ? Icons.skip_next_rounded
                            : Icons.arrow_forward_rounded,
                        color: _step == _review
                            ? AppColors.forest
                            : AppColors.teal,
                        onPressed: _canContinue ? _next : null,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSwitcher() {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 480),
      reverseDuration: const Duration(milliseconds: 320),
      switchInCurve: Curves.easeOutCubic,
      switchOutCurve: Curves.easeInCubic,
      layoutBuilder: (current, previous) => Stack(
        alignment: Alignment.topCenter,
        children: [...previous, ?current],
      ),
      transitionBuilder: (child, animation) {
        final incoming = child.key == ValueKey(_step);
        final dir = _forward ? 1.0 : -1.0;
        final begin = Offset((incoming ? 0.22 : -0.22) * dir, 0);
        return FadeTransition(
          opacity: animation,
          child: SlideTransition(
            position: Tween(begin: begin, end: Offset.zero).animate(animation),
            child: child,
          ),
        );
      },
      child: KeyedSubtree(
        key: ValueKey(_step),
        child: SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(24, _step == _welcome ? 72 : 20, 24, 24),
          physics: const BouncingScrollPhysics(),
          child: _buildStep(),
        ),
      ),
    );
  }
}

class _TopBar extends StatelessWidget {
  const _TopBar({
    required this.visible,
    required this.progress,
    required this.label,
    required this.onBack,
  });

  final bool visible;
  final double progress;
  final String label;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return AnimatedSlide(
      offset: visible ? Offset.zero : const Offset(0, -0.6),
      duration: const Duration(milliseconds: 420),
      curve: Curves.easeOutCubic,
      child: AnimatedOpacity(
        opacity: visible ? 1 : 0,
        duration: const Duration(milliseconds: 320),
        child: IgnorePointer(
          ignoring: !visible,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 24, 0),
            child: Row(
              children: [
                Semantics(
                  button: true,
                  label: 'Back',
                  child: Pressable(
                    onTap: onBack,
                    scale: 0.88,
                    child: Container(
                      width: 46,
                      height: 46,
                      decoration: BoxDecoration(
                        color: AppColors.white,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.ink.withValues(alpha: 0.08),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.arrow_back_rounded,
                        color: AppColors.teal,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      AnimatedSwitcher(
                        duration: const Duration(milliseconds: 220),
                        child: Text(
                          label,
                          key: ValueKey(label),
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: AppColors.sage,
                          ),
                        ),
                      ),
                      const SizedBox(height: 6),
                      _ProgressBar(progress: progress),
                    ],
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

class _ProgressBar extends StatelessWidget {
  const _ProgressBar({required this.progress});

  final double progress;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 10,
      decoration: BoxDecoration(
        color: AppColors.mist,
        borderRadius: BorderRadius.circular(5),
      ),
      child: TweenAnimationBuilder<double>(
        tween: Tween(end: progress),
        duration: const Duration(milliseconds: 600),
        curve: Curves.easeOutCubic,
        builder: (context, value, _) => FractionallySizedBox(
          alignment: Alignment.centerLeft,
          widthFactor: value.clamp(0.0, 1.0),
          child: Container(
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [AppColors.mint, AppColors.teal],
              ),
              borderRadius: BorderRadius.circular(5),
            ),
          ),
        ),
      ),
    );
  }
}
