import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../theme/app_colors.dart';
import '../../../theme/app_theme.dart';

/// Question heading used at the top of every sign-up step.
class StepHeader extends StatelessWidget {
  const StepHeader({
    super.key,
    required this.eyebrow,
    required this.title,
    required this.subtitle,
  });

  final String eyebrow;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
          decoration: BoxDecoration(
            color: AppColors.butter,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            eyebrow.toUpperCase(),
            style: const TextStyle(
              fontFamily: AppFonts.display,
              fontWeight: FontWeight.w700,
              fontSize: 13,
              letterSpacing: 1.6,
              color: AppColors.teal,
            ),
          ),
        ),
        const SizedBox(height: 18),
        Text(title, style: text.headlineLarge),
        const SizedBox(height: 10),
        Text(subtitle, style: text.bodyLarge),
      ],
    );
  }
}

/// Rounded input that glows teal while focused.
class GlowTextField extends StatefulWidget {
  const GlowTextField({
    super.key,
    required this.controller,
    required this.hint,
    required this.icon,
    this.focusNode,
    this.maxLength,
    this.textCapitalization = TextCapitalization.words,
    this.inputFormatters,
    this.onSubmitted,
    this.errorText,
  });

  final TextEditingController controller;
  final FocusNode? focusNode;
  final String hint;
  final IconData icon;
  final int? maxLength;
  final TextCapitalization textCapitalization;
  final List<TextInputFormatter>? inputFormatters;
  final ValueChanged<String>? onSubmitted;
  final String? errorText;

  @override
  State<GlowTextField> createState() => _GlowTextFieldState();
}

class _GlowTextFieldState extends State<GlowTextField> {
  late final FocusNode _focus = widget.focusNode ?? FocusNode();
  bool get _ownsFocus => widget.focusNode == null;

  @override
  void initState() {
    super.initState();
    _focus.addListener(_onFocus);
  }

  void _onFocus() => setState(() {});

  @override
  void dispose() {
    _focus.removeListener(_onFocus);
    if (_ownsFocus) _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final focused = _focus.hasFocus;
    final hasError = widget.errorText != null;
    final accent = hasError ? AppColors.coral : AppColors.teal;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AnimatedContainer(
          duration: const Duration(milliseconds: 260),
          curve: Curves.easeOutCubic,
          decoration: BoxDecoration(
            color: AppColors.white,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(
              color: focused || hasError
                  ? accent
                  : AppColors.seafoam.withValues(alpha: 0.6),
              width: focused ? 2.2 : 1.6,
            ),
            boxShadow: [
              BoxShadow(
                color: accent.withValues(alpha: focused ? 0.18 : 0.0),
                blurRadius: focused ? 24 : 0,
                spreadRadius: focused ? 2 : 0,
              ),
            ],
          ),
          child: Row(
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 260),
                margin: const EdgeInsets.all(8),
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: focused ? accent : AppColors.iceMint,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  widget.icon,
                  color: focused ? AppColors.white : AppColors.sage,
                ),
              ),
              Expanded(
                child: TextField(
                  controller: widget.controller,
                  focusNode: _focus,
                  maxLength: widget.maxLength,
                  textCapitalization: widget.textCapitalization,
                  inputFormatters: widget.inputFormatters,
                  textInputAction: TextInputAction.next,
                  onSubmitted: widget.onSubmitted,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w500,
                    color: AppColors.ink,
                  ),
                  decoration: InputDecoration(
                    hintText: widget.hint,
                    hintStyle: TextStyle(
                      color: AppColors.slate.withValues(alpha: 0.4),
                    ),
                    border: InputBorder.none,
                    counterText: '',
                    contentPadding: const EdgeInsets.fromLTRB(4, 18, 18, 18),
                  ),
                ),
              ),
            ],
          ),
        ),
        AnimatedSize(
          duration: const Duration(milliseconds: 240),
          curve: Curves.easeOutCubic,
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 200),
            child: hasError
                ? Padding(
                    key: ValueKey(widget.errorText),
                    padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.info_outline_rounded,
                          size: 18,
                          color: AppColors.coral,
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            widget.errorText!,
                            style: const TextStyle(
                              color: AppColors.coral,
                              fontSize: 13,
                            ),
                          ),
                        ),
                      ],
                    ),
                  )
                : const SizedBox(width: double.infinity),
          ),
        ),
      ],
    );
  }
}

const _months = [
  'January',
  'February',
  'March',
  'April',
  'May',
  'June',
  'July',
  'August',
  'September',
  'October',
  'November',
  'December',
];

String formatLongDate(DateTime d) =>
    '${_months[d.month - 1]} ${d.day}, ${d.year}';
