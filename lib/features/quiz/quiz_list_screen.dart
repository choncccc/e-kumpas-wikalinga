import 'package:flutter/material.dart';

import '../../data/lesson_models.dart';
import '../../data/quiz_content.dart';
import '../../data/study_repository.dart';
import '../../data/user_profile.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_theme.dart';
import '../../widgets/pressable.dart';
import 'quiz_screen.dart';

/// Picks a quiz: the General and Hypertension sets, with
/// the learner's best score on every one.
class QuizListScreen extends StatefulWidget {
  const QuizListScreen({
    super.key,
    required this.profile,
    required this.study,
    this.quizzes = const AssetQuizRepository(),
  });

  final UserProfile profile;
  final StudyRepository study;
  final QuizRepository quizzes;

  @override
  State<QuizListScreen> createState() => _QuizListScreenState();
}

class _QuizListScreenState extends State<QuizListScreen> {
  late final Future<List<QuizSet>> _sets = widget.quizzes.sets();
  Map<String, QuizScore> _best = const {};

  @override
  void initState() {
    super.initState();
    widget.study.addListener(_loadScores);
    _loadScores();
  }

  @override
  void dispose() {
    widget.study.removeListener(_loadScores);
    super.dispose();
  }

  Future<void> _loadScores() async {
    final best = await widget.study.bestQuizScores();
    if (mounted) setState(() => _best = best);
  }

  void _open(QuizSet set, QuizDef quiz) => Navigator.of(context).push(
    MaterialPageRoute(
      settings: RouteSettings(
        name: 'Quiz',
        arguments: ['${set.title} ${quiz.number}', ?quiz.title].join(': '),
      ),
      builder: (_) => QuizScreen(
        profile: widget.profile,
        study: widget.study,
        quizSet: set,
        quiz: quiz,
      ),
    ),
  );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.white,
      body: Column(
        children: [
          QuizHeader(profile: widget.profile, title: 'Quiz'),
          Expanded(
            child: FutureBuilder<List<QuizSet>>(
              future: _sets,
              builder: (context, snap) {
                if (snap.hasError) {
                  return const Center(
                    child: Text('Couldn’t load the quizzes right now.'),
                  );
                }
                final sets = snap.data;
                if (sets == null) {
                  return const Center(
                    child: CircularProgressIndicator(color: AppColors.teal),
                  );
                }
                return ListView(
                  physics: const BouncingScrollPhysics(),
                  padding: EdgeInsets.fromLTRB(
                    16,
                    16,
                    16,
                    24 + MediaQuery.paddingOf(context).bottom,
                  ),
                  children: [
                    for (final set in sets) ...[
                      _SetHeading(set: set),
                      for (final quiz in set.quizzes)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: _QuizCard(
                            set: set,
                            quiz: quiz,
                            best: _best[quiz.id],
                            onTap: quiz.isReady ? () => _open(set, quiz) : null,
                          ),
                        ),
                      const SizedBox(height: 14),
                    ],
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _SetHeading extends StatelessWidget {
  const _SetHeading({required this.set});

  final QuizSet set;

  @override
  Widget build(BuildContext context) {
    final count = set.quizzes.isEmpty ? 0 : set.quizzes.first.items.length;
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 0, 4, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            set.title,
            style: const TextStyle(
              fontFamily: AppFonts.display,
              fontWeight: FontWeight.w700,
              fontSize: 22,
              color: AppColors.ink,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            '${set.subtitle} ${set.quizzes.length} quizzes, '
            '$count questions each.',
            style: const TextStyle(fontSize: 13, color: AppColors.slate),
          ),
        ],
      ),
    );
  }
}

class _QuizCard extends StatelessWidget {
  const _QuizCard({
    required this.set,
    required this.quiz,
    required this.best,
    required this.onTap,
  });

  final QuizSet set;
  final QuizDef quiz;
  final QuizScore? best;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final ready = quiz.isReady;
    final missing = quiz.missingMedia;
    final status = !ready
        ? 'Videos coming soon ($missing of ${quiz.items.length} still to '
              'record)'
        : best == null
        ? '${quiz.items.length} questions · not taken yet'
        : 'Best score ${best!.score}/${best!.total}';
    final name = '${set.title} ${quiz.number}';
    return Semantics(
      button: ready,
      enabled: ready,
      label: [name, ?quiz.title, status].join('. '),
      excludeSemantics: true,
      child: Pressable(
        onTap: onTap,
        scale: 0.97,
        child: Opacity(
          opacity: ready ? 1 : 0.6,
          child: Container(
            padding: const EdgeInsets.fromLTRB(10, 10, 14, 10),
            decoration: BoxDecoration(
              color: ready ? AppColors.iceMint : AppColors.mist,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: ready ? AppColors.seafoam : AppColors.cloud,
                width: 2,
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: ready ? AppColors.mustard : AppColors.cloud,
                    shape: BoxShape.circle,
                  ),
                  child: Text(
                    '${quiz.number}',
                    style: const TextStyle(
                      fontFamily: AppFonts.display,
                      fontWeight: FontWeight.w900,
                      fontSize: 20,
                      color: AppColors.ink,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        quiz.title ?? 'Quiz ${quiz.number}',
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 15,
                          color: AppColors.ink,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        status,
                        style: TextStyle(
                          fontSize: 12.5,
                          color: best != null && ready
                              ? AppColors.forest
                              : AppColors.slate,
                          fontWeight: best != null && ready
                              ? FontWeight.w600
                              : FontWeight.w400,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  ready ? Icons.play_circle_fill_rounded : Icons.videocam_off,
                  color: ready ? AppColors.teal : AppColors.slate,
                  size: 30,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
