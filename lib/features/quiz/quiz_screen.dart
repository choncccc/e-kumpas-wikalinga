import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../data/quiz_content.dart';
import '../../data/study_repository.dart';
import '../../data/user_profile.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_theme.dart';
import '../../widgets/pressable.dart';
import '../../widgets/profile_avatar.dart';
import '../../widgets/sign_media.dart';
import '../lessons/category_screen.dart' show LessonBackButton;
import 'quiz_question.dart';

/// "Sign it Right!" quiz from the mockup: one of the client's fixed quizzes
/// against the clock, instant feedback on each question, then a review of
/// every answer.
class QuizScreen extends StatefulWidget {
  const QuizScreen({
    super.key,
    required this.profile,
    required this.study,
    required this.quizSet,
    required this.quiz,
    this.timeLimit,
  });

  final UserProfile profile;
  final StudyRepository study;
  final QuizSet quizSet;
  final QuizDef quiz;

  /// Defaults to the set's time per question times the question count.
  final Duration? timeLimit;

  @override
  State<QuizScreen> createState() => _QuizScreenState();
}

class _QuizScreenState extends State<QuizScreen> {
  late final List<QuizQuestion> _questions = [
    for (final item in widget.quiz.items) QuizQuestion.fromItem(item),
  ];
  List<int?> _answers = const [];
  int _index = 0;
  bool _finished = false;
  Timer? _timer;
  late Duration _remaining;

  @override
  void initState() {
    super.initState();
    _start();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Duration get _timeLimit =>
      widget.timeLimit ?? widget.quizSet.timeLimitFor(widget.quiz);

  void _start() {
    _timer?.cancel();
    _answers = List.filled(_questions.length, null);
    _index = 0;
    _finished = false;
    _remaining = _timeLimit;
    _timer = Timer.periodic(const Duration(seconds: 1), (_) => _tick());
  }

  String get _name => '${widget.quizSet.title} ${widget.quiz.number}';

  void _restart() {
    widget.study.logActivity('Restarted quiz', _name);
    setState(_start);
  }

  void _tick() {
    if (!mounted || _finished) return;
    final next = _remaining - const Duration(seconds: 1);
    if (next <= Duration.zero) {
      setState(() => _remaining = Duration.zero);
      _finish();
    } else {
      setState(() => _remaining = next);
    }
  }

  int get _score {
    final q = _questions;
    var n = 0;
    for (var i = 0; i < q.length; i++) {
      if (_answers[i] == q[i].correct) n++;
    }
    return n;
  }

  void _answer(int option) {
    if (_answers[_index] != null || _finished) return;
    final right = option == _questions[_index].correct;
    widget.study.logActivity(
      'Answered quiz question',
      '$_name, question ${_index + 1}: ${String.fromCharCode(65 + option)} '
          '(${right ? 'correct' : 'wrong'})',
    );
    right ? HapticFeedback.lightImpact() : HapticFeedback.heavyImpact();
    setState(() => _answers[_index] = option);
  }

  void _next() {
    if (_index == _questions.length - 1) {
      _finish();
    } else {
      setState(() => _index++);
    }
  }

  void _back() {
    if (_index > 0) setState(() => _index--);
  }

  void _finish() {
    if (_finished) return;
    _timer?.cancel();
    setState(() => _finished = true);
    widget.study.logActivity(
      'Finished quiz',
      '$_name: $_score/${_questions.length}'
          '${_remaining == Duration.zero ? ' (time ran out)' : ''}',
    );
    widget.study.saveQuizResult(
      _score,
      _questions.length,
      quizId: widget.quiz.id,
    );
  }

  @override
  Widget build(BuildContext context) {
    final questions = _questions;
    final Widget body;
    if (_finished) {
      body = _Results(
        key: const ValueKey('results'),
        questions: questions,
        answers: _answers,
        score: _score,
        timedOut: _remaining == Duration.zero,
        onAgain: _restart,
        onDone: () => Navigator.of(context).maybePop(),
      );
    } else {
      body = _QuestionView(
        key: const ValueKey('quiz'),
        questions: questions,
        answers: _answers,
        index: _index,
        score: _score,
        remaining: _remaining,
        onAnswer: _answer,
        onNext: _next,
        onBack: _back,
      );
    }

    return Scaffold(
      backgroundColor: AppColors.white,
      body: Column(
        children: [
          QuizHeader(
            profile: widget.profile,
            title: '${widget.quizSet.title} ${widget.quiz.number}',
            subtitle: widget.quiz.title,
          ),
          Expanded(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 380),
              switchInCurve: Curves.easeOutCubic,
              transitionBuilder: (child, anim) => FadeTransition(
                opacity: anim,
                child: SlideTransition(
                  position: Tween(
                    begin: const Offset(0, 0.04),
                    end: Offset.zero,
                  ).animate(anim),
                  child: child,
                ),
              ),
              child: body,
            ),
          ),
        ],
      ),
    );
  }
}

/// Avatar, title and the mustard "SIGN IT RIGHT" bar, shared by the quiz
/// list and the quiz itself.
class QuizHeader extends StatelessWidget {
  const QuizHeader({
    super.key,
    required this.profile,
    required this.title,
    this.subtitle,
  });

  final UserProfile profile;
  final String title;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.paddingOf(context).top;
    return Container(
      color: AppColors.mist,
      padding: EdgeInsets.fromLTRB(16, top + 10, 16, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              LessonBackButton(onTap: () => Navigator.of(context).maybePop()),
              const SizedBox(width: 12),
              ProfileAvatar(
                nickname: profile.nickname,
                photoPath: profile.photoPath,
                size: 40,
                ring: false,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Text(
                        title,
                        style: const TextStyle(
                          fontFamily: AppFonts.display,
                          fontWeight: FontWeight.w900,
                          fontSize: 28,
                          color: AppColors.ink,
                        ),
                      ),
                    ),
                    if (subtitle != null)
                      Text(
                        subtitle!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: AppColors.teal,
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
            decoration: BoxDecoration(
              color: AppColors.mustard,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              children: [
                const Expanded(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'SIGN IT RIGHT',
                      style: TextStyle(
                        fontFamily: AppFonts.display,
                        fontWeight: FontWeight.w700,
                        fontSize: 24,
                        letterSpacing: 6,
                        color: AppColors.ink,
                      ),
                    ),
                  ),
                ),
                Icon(
                  Icons.sign_language_rounded,
                  color: AppColors.white.withValues(alpha: 0.95),
                  size: 32,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Olive pill used for the score and timer.
class _Pill extends StatelessWidget {
  const _Pill({required this.child, this.icon});

  final Widget child;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.olive,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, color: AppColors.white, size: 16),
            const SizedBox(width: 6),
          ],
          Flexible(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: DefaultTextStyle.merge(
                style: const TextStyle(
                  fontFamily: AppFonts.display,
                  fontWeight: FontWeight.w600,
                  fontSize: 13.5,
                  color: AppColors.white,
                  fontFeatures: [FontFeature.tabularFigures()],
                ),
                child: child,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _QuestionView extends StatelessWidget {
  const _QuestionView({
    super.key,
    required this.questions,
    required this.answers,
    required this.index,
    required this.score,
    required this.remaining,
    required this.onAnswer,
    required this.onNext,
    required this.onBack,
  });

  final List<QuizQuestion> questions;
  final List<int?> answers;
  final int index;
  final int score;
  final Duration remaining;
  final ValueChanged<int> onAnswer;
  final VoidCallback onNext;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    final q = questions[index];
    final chosen = answers[index];
    final answered = chosen != null;
    final mins = remaining.inMinutes;
    final secs = (remaining.inSeconds % 60).toString().padLeft(2, '0');
    final lowTime = remaining.inSeconds <= 20;

    return Column(
      children: [
        Expanded(
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
            child: Container(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 20),
              decoration: BoxDecoration(
                color: AppColors.iceMint,
                borderRadius: BorderRadius.circular(36),
                border: Border.all(color: AppColors.seafoam, width: 2),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      _Pill(child: Text('Score: $score')),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Align(
                          alignment: Alignment.centerRight,
                          child: Semantics(
                            label: 'Time remaining $mins minutes $secs seconds',
                            excludeSemantics: true,
                            child: AnimatedOpacity(
                              duration: const Duration(milliseconds: 300),
                              opacity: lowTime && remaining.inSeconds.isOdd
                                  ? 0.6
                                  : 1,
                              child: _Pill(
                                icon: Icons.schedule_rounded,
                                child: Text('Time left: $mins:$secs'),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 320),
                    transitionBuilder: (child, anim) => FadeTransition(
                      opacity: anim,
                      child: SlideTransition(
                        position: Tween(
                          begin: const Offset(0.06, 0),
                          end: Offset.zero,
                        ).animate(anim),
                        child: child,
                      ),
                    ),
                    child: _QuestionBody(
                      key: ValueKey(index),
                      number: index + 1,
                      question: q,
                      chosen: chosen,
                      onAnswer: onAnswer,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        SafeArea(
          top: false,
          minimum: const EdgeInsets.fromLTRB(16, 0, 16, 14),
          child: _NavBar(
            count: questions.length,
            index: index,
            answers: answers,
            questions: questions,
            canBack: index > 0,
            canNext: answered,
            isLast: index == questions.length - 1,
            onBack: onBack,
            onNext: onNext,
          ),
        ),
      ],
    );
  }
}

class _QuestionBody extends StatelessWidget {
  const _QuestionBody({
    super.key,
    required this.number,
    required this.question,
    required this.chosen,
    required this.onAnswer,
  });

  final int number;
  final QuizQuestion question;
  final int? chosen;
  final ValueChanged<int> onAnswer;

  @override
  Widget build(BuildContext context) {
    final q = question;
    final answered = chosen != null;
    final right = chosen == q.correct;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 36,
              height: 36,
              alignment: Alignment.center,
              decoration: const BoxDecoration(
                color: AppColors.mint,
                shape: BoxShape.circle,
              ),
              child: Text(
                '$number',
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 17,
                  color: AppColors.white,
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    q.prompt,
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 16,
                      color: AppColors.ink,
                      height: 1.25,
                    ),
                  ),
                  Text(
                    q.hint,
                    style: const TextStyle(fontSize: 13, color: AppColors.teal),
                  ),
                ],
              ),
            ),
          ],
        ),
        if (q.media != null) ...[
          const SizedBox(height: 14),
          AspectRatio(
            aspectRatio: 16 / 10,
            child: SignMedia(
              // Keyed so moving to the next question starts a fresh clip.
              key: ValueKey(q.media),
              asset: q.media,
              label: 'Sign to identify',
              borderRadius: 22,
            ),
          ),
        ],
        const SizedBox(height: 16),
        for (var i = 0; i < q.options.length; i++)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: _OptionTile(
              letter: String.fromCharCode(65 + i),
              text: q.options[i],
              state: !answered
                  ? _OptionState.idle
                  : i == q.correct
                  ? _OptionState.correct
                  : i == chosen
                  ? _OptionState.wrong
                  : _OptionState.faded,
              onTap: answered ? null : () => onAnswer(i),
            ),
          ),
        AnimatedSize(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOutCubic,
          child: !answered
              ? const SizedBox(width: double.infinity)
              : Container(
                  margin: const EdgeInsets.only(top: 4),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: right ? const Color(0xFFDDF5E0) : AppColors.blush,
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        right
                            ? Icons.check_circle_rounded
                            : Icons.lightbulb_rounded,
                        color: right ? AppColors.forest : AppColors.coral,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text.rich(
                          TextSpan(
                            children: [
                              TextSpan(
                                text: right ? 'Correct! ' : 'Not quite. ',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              TextSpan(text: q.explanation),
                            ],
                          ),
                          style: const TextStyle(
                            fontSize: 13.5,
                            color: AppColors.ink,
                            height: 1.4,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
        ),
      ],
    );
  }
}

enum _OptionState { idle, correct, wrong, faded }

class _OptionTile extends StatelessWidget {
  const _OptionTile({
    required this.letter,
    required this.text,
    required this.state,
    required this.onTap,
  });

  final String letter;
  final String text;
  final _OptionState state;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final (bg, border, badge, badgeText) = switch (state) {
      _OptionState.idle => (
        AppColors.white,
        AppColors.mustard,
        AppColors.cloud,
        AppColors.ink,
      ),
      _OptionState.correct => (
        AppColors.leaf,
        AppColors.forest,
        AppColors.forest,
        AppColors.white,
      ),
      _OptionState.wrong => (
        AppColors.blush,
        AppColors.coral,
        AppColors.coral,
        AppColors.white,
      ),
      _OptionState.faded => (
        AppColors.white.withValues(alpha: 0.6),
        AppColors.cloud,
        AppColors.mist,
        AppColors.slate,
      ),
    };
    return Semantics(
      button: onTap != null,
      label: '$letter: $text',
      value: switch (state) {
        _OptionState.correct => 'correct answer',
        _OptionState.wrong => 'your answer, wrong',
        _ => null,
      },
      excludeSemantics: true,
      child: Pressable(
        onTap: onTap,
        scale: 0.97,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 260),
          curve: Curves.easeOutCubic,
          padding: const EdgeInsets.fromLTRB(6, 6, 16, 6),
          constraints: const BoxConstraints(minHeight: 52),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(26),
            border: Border.all(color: border, width: 2),
          ),
          child: Row(
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 260),
                width: 36,
                height: 36,
                alignment: Alignment.center,
                decoration: BoxDecoration(color: badge, shape: BoxShape.circle),
                child: Text(
                  letter,
                  style: TextStyle(
                    fontFamily: AppFonts.display,
                    fontWeight: FontWeight.w700,
                    fontSize: 17,
                    color: badgeText,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  text,
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 15,
                    height: 1.25,
                    color: state == _OptionState.faded
                        ? AppColors.slate.withValues(alpha: 0.7)
                        : AppColors.ink,
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

/// Mustard bar from the mockup: BACK, one dot per question, NEXT.
class _NavBar extends StatelessWidget {
  const _NavBar({
    required this.count,
    required this.index,
    required this.answers,
    required this.questions,
    required this.canBack,
    required this.canNext,
    required this.isLast,
    required this.onBack,
    required this.onNext,
  });

  final int count;
  final int index;
  final List<int?> answers;
  final List<QuizQuestion> questions;
  final bool canBack;
  final bool canNext;
  final bool isLast;
  final VoidCallback onBack;
  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 56,
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: AppColors.mustard,
        borderRadius: BorderRadius.circular(28),
      ),
      child: Row(
        children: [
          _NavButton(label: 'BACK', onTap: canBack ? onBack : null),
          Expanded(
            child: Semantics(
              label: 'Question ${index + 1} of $count',
              excludeSemantics: true,
              // Dots shrink to fit narrow screens and large text.
              child: LayoutBuilder(
                builder: (context, c) {
                  final size = (c.maxWidth / (count * 1.4 + 1)).clamp(
                    4.0,
                    12.0,
                  );
                  return Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      for (var i = 0; i < count; i++)
                        _Dot(
                          size: size,
                          current: i == index,
                          result: answers[i] == null
                              ? null
                              : answers[i] == questions[i].correct,
                        ),
                    ],
                  );
                },
              ),
            ),
          ),
          _NavButton(
            label: isLast ? 'FINISH' : 'NEXT',
            onTap: canNext ? onNext : null,
          ),
        ],
      ),
    );
  }
}

class _Dot extends StatelessWidget {
  const _Dot({required this.size, required this.current, required this.result});

  final double size;
  final bool current;
  final bool? result;

  @override
  Widget build(BuildContext context) {
    final fill = switch (result) {
      true => AppColors.forest,
      false => AppColors.coral,
      null => current ? AppColors.cloud : Colors.transparent,
    };
    return AnimatedContainer(
      duration: const Duration(milliseconds: 260),
      width: current ? size * 4 / 3 : size,
      height: current ? size * 4 / 3 : size,
      decoration: BoxDecoration(
        color: fill,
        shape: BoxShape.circle,
        border: Border.all(color: AppColors.olive, width: 1.4),
      ),
    );
  }
}

class _NavButton extends StatelessWidget {
  const _NavButton({required this.label, required this.onTap});

  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null;
    return Semantics(
      button: true,
      enabled: enabled,
      label: label,
      excludeSemantics: true,
      child: Pressable(
        onTap: onTap,
        scale: 0.9,
        child: AnimatedOpacity(
          duration: const Duration(milliseconds: 200),
          opacity: enabled ? 1 : 0.45,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: AppColors.olive,
              borderRadius: BorderRadius.circular(22),
            ),
            child: Text(
              label,
              style: const TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 13.5,
                color: AppColors.white,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Results extends StatelessWidget {
  const _Results({
    super.key,
    required this.questions,
    required this.answers,
    required this.score,
    required this.timedOut,
    required this.onAgain,
    required this.onDone,
  });

  final List<QuizQuestion> questions;
  final List<int?> answers;
  final int score;
  final bool timedOut;
  final VoidCallback onAgain;
  final VoidCallback onDone;

  @override
  Widget build(BuildContext context) {
    final total = questions.length;
    final ratio = score / total;
    final verdict = ratio >= 0.9
        ? 'Galing! Excellent signing.'
        : ratio >= 0.6
        ? 'Nice work! Keep practising.'
        : 'Good start. Review the lessons and try again.';

    return ListView(
      physics: const BouncingScrollPhysics(),
      padding: EdgeInsets.fromLTRB(
        16,
        16,
        16,
        24 + MediaQuery.paddingOf(context).bottom,
      ),
      children: [
        Container(
          padding: const EdgeInsets.fromLTRB(16, 18, 16, 18),
          decoration: BoxDecoration(
            color: AppColors.iceMint,
            borderRadius: BorderRadius.circular(36),
            border: Border.all(color: AppColors.seafoam, width: 2),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (timedOut)
                const Padding(
                  padding: EdgeInsets.only(bottom: 8),
                  child: Text(
                    'Time’s up!',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      color: AppColors.coral,
                    ),
                  ),
                ),
              Center(
                child: TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0, end: ratio),
                  duration: const Duration(milliseconds: 900),
                  curve: Curves.easeOutCubic,
                  builder: (context, v, _) => SizedBox(
                    width: 120,
                    height: 120,
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        CircularProgressIndicator(
                          value: v,
                          strokeWidth: 10,
                          strokeCap: StrokeCap.round,
                          backgroundColor: AppColors.white,
                          color: AppColors.forest,
                        ),
                        Center(
                          child: Text(
                            '$score/$total',
                            style: const TextStyle(
                              fontFamily: AppFonts.display,
                              fontWeight: FontWeight.w900,
                              fontSize: 30,
                              color: AppColors.ink,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                verdict,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontFamily: AppFonts.display,
                  fontWeight: FontWeight.w700,
                  fontSize: 18,
                  color: AppColors.teal,
                ),
              ),
              const SizedBox(height: 18),
              for (var i = 0; i < total; i++)
                Padding(
                  padding: const EdgeInsets.only(bottom: 14),
                  child: _ReviewRow(
                    number: i + 1,
                    question: questions[i],
                    answer: answers[i],
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        PrimaryButton(
          label: 'Play again',
          icon: Icons.replay_rounded,
          onPressed: onAgain,
        ),
        const SizedBox(height: 10),
        TextButton(
          onPressed: onDone,
          child: const Text(
            'Back to quizzes',
            style: TextStyle(color: AppColors.teal),
          ),
        ),
      ],
    );
  }
}

class _ReviewRow extends StatelessWidget {
  const _ReviewRow({
    required this.number,
    required this.question,
    required this.answer,
  });

  final int number;
  final QuizQuestion question;
  final int? answer;

  @override
  Widget build(BuildContext context) {
    final q = question;
    final right = answer == q.correct;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 36,
          height: 36,
          alignment: Alignment.center,
          decoration: const BoxDecoration(
            color: AppColors.seafoam,
            shape: BoxShape.circle,
          ),
          child: Text(
            '$number',
            style: const TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 16,
              color: AppColors.white,
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (answer == null)
                const _AnswerChip(text: 'No answer', right: false)
              else if (!right)
                _AnswerChip(text: q.options[answer!], right: false),
              const SizedBox(height: 4),
              _AnswerChip(text: q.options[q.correct], right: true),
            ],
          ),
        ),
      ],
    );
  }
}

class _AnswerChip extends StatelessWidget {
  const _AnswerChip({required this.text, required this.right});

  final String text;
  final bool right;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: '${right ? 'Correct answer' : 'Your answer'}: $text',
      excludeSemantics: true,
      child: Container(
        padding: const EdgeInsets.fromLTRB(4, 4, 12, 4),
        decoration: BoxDecoration(
          color: right ? AppColors.leaf : AppColors.blush,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: right ? AppColors.forest : AppColors.coral,
            width: 1.6,
          ),
        ),
        child: Row(
          children: [
            Icon(
              right ? Icons.check_circle_rounded : Icons.cancel_rounded,
              size: 20,
              color: right ? AppColors.forest : AppColors.coral,
            ),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                text,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: AppColors.ink,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
