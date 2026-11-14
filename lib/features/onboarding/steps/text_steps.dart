import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../theme/app_colors.dart';
import '../../../theme/app_theme.dart';
import '../../../widgets/pressable.dart';
import '../../../widgets/staggered_entrance.dart';
import '../onboarding_draft.dart';
import '../widgets/step_parts.dart';

/// Shared plumbing for steps that are a single text field: keeps a controller
/// in sync with the draft and focuses the field once the slide-in settles.
mixin _AutofocusTextStep<T extends StatefulWidget> on State<T> {
  late final TextEditingController textController;
  final FocusNode focusNode = FocusNode();
  Timer? _focusTimer;

  String initialText();
  void onTextChanged(String value);

  @override
  void initState() {
    super.initState();
    textController = TextEditingController(text: initialText())
      ..addListener(() => onTextChanged(textController.text));
    _focusTimer = Timer(const Duration(milliseconds: 450), () {
      if (mounted) focusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    _focusTimer?.cancel();
    textController.dispose();
    focusNode.dispose();
    super.dispose();
  }
}

String? _visibleError(String? error, String text) =>
    (error == null || error.isEmpty || text.trim().isEmpty) ? null : error;

class NameStep extends StatefulWidget {
  const NameStep({super.key, required this.draft, required this.onSubmit});

  final OnboardingDraft draft;
  final VoidCallback onSubmit;

  @override
  State<NameStep> createState() => _NameStepState();
}

class _NameStepState extends State<NameStep> with _AutofocusTextStep {
  @override
  String initialText() => widget.draft.name;

  @override
  void onTextChanged(String value) => widget.draft.name = value;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.draft,
      builder: (context, _) => StaggeredEntrance(
        children: [
          const StepHeader(
            eyebrow: 'Step 1 · Name',
            title: 'What’s your name?',
            subtitle: 'Your full name, the way you’d like it on your profile.',
          ),
          const SizedBox(height: 32),
          GlowTextField(
            controller: textController,
            focusNode: focusNode,
            hint: 'e.g. Juan Dela Cruz',
            icon: Icons.person_rounded,
            maxLength: OnboardingDraft.nameMax,
            errorText: _visibleError(widget.draft.nameError, widget.draft.name),
            onSubmitted: (_) => widget.onSubmit(),
          ),
        ],
      ),
    );
  }
}

class NicknameStep extends StatefulWidget {
  const NicknameStep({super.key, required this.draft, required this.onSubmit});

  final OnboardingDraft draft;
  final VoidCallback onSubmit;

  @override
  State<NicknameStep> createState() => _NicknameStepState();
}

class _NicknameStepState extends State<NicknameStep> with _AutofocusTextStep {
  @override
  String initialText() => widget.draft.nickname;

  @override
  void onTextChanged(String value) => widget.draft.nickname = value;

  void _useSuggestion(String s) {
    textController.value = TextEditingValue(
      text: s,
      selection: TextSelection.collapsed(offset: s.length),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.draft,
      builder: (context, _) {
        final draft = widget.draft;
        final suggestion = draft.suggestedNickname;
        final showSuggestion =
            suggestion.isNotEmpty && draft.nickname.trim() != suggestion;
        final preview = draft.nickname.trim().isEmpty
            ? '…'
            : draft.nickname.trim();

        return StaggeredEntrance(
          children: [
            const StepHeader(
              eyebrow: 'Step 2 · Nickname',
              title: 'What should we call you?',
              subtitle: 'This is how the app will greet you.',
            ),
            const SizedBox(height: 32),
            GlowTextField(
              controller: textController,
              focusNode: focusNode,
              hint: 'e.g. Juanito',
              icon: Icons.tag_faces_rounded,
              maxLength: OnboardingDraft.nicknameMax,
              textCapitalization: TextCapitalization.words,
              inputFormatters: [
                FilteringTextInputFormatter.deny(RegExp(r'\n')),
              ],
              errorText: _visibleError(draft.nicknameError, draft.nickname),
              onSubmitted: (_) => widget.onSubmit(),
            ),
            AnimatedSize(
              duration: const Duration(milliseconds: 280),
              curve: Curves.easeOutCubic,
              alignment: Alignment.topLeft,
              child: showSuggestion
                  ? Padding(
                      padding: const EdgeInsets.only(top: 14),
                      child: Pressable(
                        onTap: () => _useSuggestion(suggestion),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 9,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.iceMint,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: AppColors.seafoam),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.auto_awesome_rounded,
                                size: 16,
                                color: AppColors.sage,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                'Use “$suggestion”',
                                style: const TextStyle(
                                  color: AppColors.teal,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    )
                  : const SizedBox(width: double.infinity),
            ),
            const SizedBox(height: 28),
            _GreetingPreview(nickname: preview),
          ],
        );
      },
    );
  }
}

/// Mini version of the home header from the mockup, updating as you type.
class _GreetingPreview extends StatelessWidget {
  const _GreetingPreview({required this.nickname});

  final String nickname;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.mist,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Row(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: const BoxDecoration(
              color: AppColors.mustard,
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 220),
              transitionBuilder: (c, a) => ScaleTransition(scale: a, child: c),
              child: Text(
                nickname == '…' ? '?' : nickname.characters.first.toUpperCase(),
                key: ValueKey(nickname.characters.first),
                style: const TextStyle(
                  fontFamily: AppFonts.display,
                  fontWeight: FontWeight.w900,
                  fontSize: 24,
                  color: AppColors.ink,
                ),
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Welcome!',
                  style: TextStyle(
                    fontFamily: AppFonts.display,
                    fontWeight: FontWeight.w900,
                    fontSize: 24,
                    color: AppColors.ink,
                    height: 1.1,
                  ),
                ),
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 180),
                  layoutBuilder: (current, previous) => Stack(
                    alignment: Alignment.centerLeft,
                    children: [...previous, ?current],
                  ),
                  child: Text(
                    nickname.toUpperCase(),
                    key: ValueKey(nickname),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: AppColors.teal,
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
