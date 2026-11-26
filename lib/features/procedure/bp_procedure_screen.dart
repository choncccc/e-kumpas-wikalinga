import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';
import '../../theme/app_theme.dart';
import '../../widgets/pressable.dart';
import '../../widgets/sign_media.dart';
import '../lessons/category_screen.dart' show LessonBackButton;

/// One step of the blood pressure walkthrough. Clips are built by
/// tool/build_procedure.py into assets/procedure/.
class ProcedureStep {
  const ProcedureStep(this.number, this.title, this.detail);

  final int number;
  final String title;
  final String detail;

  String get video => 'assets/procedure/bp_step_$number.mp4';
  String get poster => 'assets/procedure/bp_step_$number.jpg';
}

const bpProcedureSteps = [
  ProcedureStep(
    1,
    'Position the arm',
    'Rest the arm on the table, palm up, at about heart level.',
  ),
  ProcedureStep(2, 'Bare the arm', 'Roll the sleeve up off the upper arm.'),
  ProcedureStep(
    3,
    'Wrap the cuff',
    'Wrap the cuff snugly around the upper arm, about 2–3 cm above the '
        'bend of the elbow.',
  ),
  ProcedureStep(
    4,
    'Line up the artery mark',
    'Turn the cuff so its ARTERY arrow sits over the inner arm.',
  ),
  ProcedureStep(
    5,
    'Attach the gauge',
    'Clip the pressure gauge onto the cuff where it is easy to read.',
  ),
  ProcedureStep(
    6,
    'Place the stethoscope',
    'Put the stethoscope on the inner elbow, over the artery.',
  ),
  ProcedureStep(
    7,
    'Inflate and listen',
    'Pump the bulb to inflate the cuff, then release it slowly while '
        'listening and watching the gauge.',
  ),
  ProcedureStep(
    8,
    'Read the gauge',
    'Note the reading on the gauge once the sounds have stopped.',
  ),
  ProcedureStep(
    9,
    'Remove the cuff',
    'Fully deflate the cuff and take it off the arm.',
  ),
];

/// Step-by-step video walkthrough of taking a blood pressure reading, opened
/// from the BP card on Home. Shows one step's clip at a time, with
/// previous/next buttons and a list to jump to any step.
class BpProcedureScreen extends StatefulWidget {
  const BpProcedureScreen({super.key, this.steps = bpProcedureSteps});

  final List<ProcedureStep> steps;

  @override
  State<BpProcedureScreen> createState() => _BpProcedureScreenState();
}

class _BpProcedureScreenState extends State<BpProcedureScreen> {
  int _current = 0;
  final _scroll = ScrollController();

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  void _go(int i) {
    if (i < 0 || i >= widget.steps.length || i == _current) return;
    setState(() => _current = i);
  }

  /// From the step list: switch, then bring the player back into view.
  void _jump(int i) {
    _go(i);
    if (_scroll.hasClients && _scroll.offset > 0) {
      _scroll.animateTo(
        0,
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeOutCubic,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final steps = widget.steps;
    final step = steps[_current];
    final isLast = _current == steps.length - 1;
    return Scaffold(
      backgroundColor: AppColors.white,
      body: SafeArea(
        bottom: false,
        child: ListView(
          controller: _scroll,
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 40),
          children: [
            Row(
              children: [
                LessonBackButton(onTap: () => Navigator.of(context).maybePop()),
                const SizedBox(width: 12),
                Flexible(
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 18,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.mustard,
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: const Text(
                      'Taking Blood Pressure',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontFamily: AppFonts.display,
                        fontWeight: FontWeight.w700,
                        fontSize: 20,
                        color: AppColors.ink,
                        height: 1.15,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 12, 4, 16),
              child: Text(
                'BP Procedure · ${steps.length} steps',
                style: const TextStyle(
                  fontSize: 13,
                  color: AppColors.sage,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            AspectRatio(
              aspectRatio: 16 / 9,
              child: SignMedia(
                key: ValueKey(step.video),
                asset: step.video,
                label: 'Step ${step.number}: ${step.title}',
                color: AppColors.aqua,
                borderRadius: 22,
              ),
            ),
            const SizedBox(height: 16),
            Semantics(
              liveRegion: true,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'STEP ${step.number} OF ${steps.length}',
                    style: const TextStyle(
                      fontSize: 12,
                      letterSpacing: 1.1,
                      fontWeight: FontWeight.w700,
                      color: AppColors.teal,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    step.title,
                    style: const TextStyle(
                      fontFamily: AppFonts.display,
                      fontWeight: FontWeight.w700,
                      fontSize: 22,
                      color: AppColors.ink,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    step.detail,
                    style: const TextStyle(
                      fontSize: 15,
                      height: 1.4,
                      color: AppColors.slate,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _current == 0 ? null : () => _go(_current - 1),
                    icon: const Icon(Icons.arrow_back_rounded),
                    label: const Text('Previous'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: isLast
                        ? () => Navigator.of(context).maybePop()
                        : () => _go(_current + 1),
                    icon: Icon(
                      isLast
                          ? Icons.check_rounded
                          : Icons.arrow_forward_rounded,
                    ),
                    label: Text(isLast ? 'Done' : 'Next'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 26),
            const Padding(
              padding: EdgeInsets.only(left: 4, bottom: 10),
              child: Text(
                'All steps',
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 15,
                  color: AppColors.ink,
                ),
              ),
            ),
            for (var i = 0; i < steps.length; i++)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _StepTile(
                  step: steps[i],
                  selected: i == _current,
                  onTap: () => _jump(i),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _StepTile extends StatelessWidget {
  const _StepTile({
    required this.step,
    required this.selected,
    required this.onTap,
  });

  final ProcedureStep step;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      label: 'Step ${step.number}: ${step.title}',
      excludeSemantics: true,
      child: Pressable(
        onTap: onTap,
        scale: 0.97,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: selected ? AppColors.butter : AppColors.white,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: selected ? AppColors.mustard : AppColors.seafoam,
              width: 1.4,
            ),
          ),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: SizedBox(
                  width: 88,
                  height: 50,
                  child: Image.asset(
                    step.poster,
                    fit: BoxFit.cover,
                    errorBuilder: (_, _, _) =>
                        const ColoredBox(color: AppColors.mist),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Text(
                '${step.number}',
                style: const TextStyle(
                  fontFamily: AppFonts.display,
                  fontWeight: FontWeight.w700,
                  fontSize: 18,
                  color: AppColors.teal,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  step.title,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 14.5,
                    color: AppColors.ink,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
