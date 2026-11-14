import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../theme/app_colors.dart';
import '../../../theme/app_theme.dart';
import '../../../widgets/staggered_entrance.dart';
import '../onboarding_draft.dart';
import '../widgets/step_parts.dart';

/// Expects [OnboardingDraft.birthdate] to be seeded before it is shown, so the
/// wheel and the Continue button agree from the first frame.
class BirthdateStep extends StatelessWidget {
  const BirthdateStep({super.key, required this.draft});

  final OnboardingDraft draft;

  static final _minDate = DateTime(1900);

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: draft,
      builder: (context, _) {
        final age = draft.ageFromBirthdate;
        final error = draft.birthdateError;
        return StaggeredEntrance(
          children: [
            const StepHeader(
              eyebrow: 'Step 4 · Birthday',
              title: 'When’s your birthday?',
              subtitle: 'Scroll the wheels to pick your month, day and year.',
            ),
            const SizedBox(height: 28),
            Container(
              height: 216,
              decoration: BoxDecoration(
                color: AppColors.white,
                borderRadius: BorderRadius.circular(28),
                border: Border.all(color: AppColors.butter, width: 2),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.mustard.withValues(alpha: 0.12),
                    blurRadius: 24,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              clipBehavior: Clip.antiAlias,
              child: CupertinoTheme(
                data: const CupertinoThemeData(
                  textTheme: CupertinoTextThemeData(
                    dateTimePickerTextStyle: TextStyle(
                      fontFamily: AppFonts.body,
                      fontSize: 20,
                      fontWeight: FontWeight.w500,
                      color: AppColors.ink,
                    ),
                  ),
                ),
                child: CupertinoDatePicker(
                  mode: CupertinoDatePickerMode.date,
                  dateOrder: DatePickerDateOrder.mdy,
                  initialDateTime: draft.birthdate,
                  minimumDate: _minDate,
                  maximumDate: draft.today,
                  onDateTimeChanged: (d) {
                    HapticFeedback.selectionClick();
                    draft.birthdate = DateTime(d.year, d.month, d.day);
                  },
                ),
              ),
            ),
            const SizedBox(height: 22),
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 280),
              switchInCurve: Curves.easeOutBack,
              switchOutCurve: Curves.easeIn,
              transitionBuilder: (c, a) => FadeTransition(
                opacity: a,
                child: ScaleTransition(
                  scale: Tween(begin: 0.85, end: 1.0).animate(a),
                  child: c,
                ),
              ),
              child: _AgeBadge(
                key: ValueKey('${error ?? ''}$age'),
                text: error == null || error.isEmpty
                    ? 'That makes you $age year${age == 1 ? '' : 's'} old'
                    : error,
                isError: error != null && error.isNotEmpty,
              ),
            ),
          ],
        );
      },
    );
  }
}

class _AgeBadge extends StatelessWidget {
  const _AgeBadge({super.key, required this.text, required this.isError});

  final String text;
  final bool isError;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: isError ? AppColors.blush : AppColors.iceMint,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isError ? AppColors.coral : AppColors.seafoam,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isError ? Icons.info_outline_rounded : Icons.cake_rounded,
            color: isError ? AppColors.coral : AppColors.forest,
            size: 20,
          ),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              text,
              style: TextStyle(
                color: isError ? AppColors.coral : AppColors.forest,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
