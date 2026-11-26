import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../data/learning_content.dart';
import '../../data/lesson_models.dart';
import '../../data/lesson_repository.dart';
import '../../data/study_repository.dart';
import '../../data/user_profile.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_theme.dart';
import '../../widgets/pressable.dart';
import '../../widgets/profile_avatar.dart';
import '../../widgets/staggered_entrance.dart';
import '../lessons/sign_entry_tile.dart' show openTopic;
import '../onboarding/widgets/step_parts.dart' show formatLongDate;
import 'activity_log_screen.dart';

/// Profile tab from the mockup: photo with the nickname arched over it, the
/// learner's details, progress per category, recent topics and today's stats.
class ProfileScreen extends StatefulWidget {
  const ProfileScreen({
    super.key,
    required this.profile,
    required this.lessons,
    required this.study,
    required this.onEdit,
    required this.onQuiz,
    this.clock = DateTime.now,
  });

  final UserProfile profile;
  final LessonRepository lessons;
  final StudyRepository study;
  final VoidCallback onEdit;
  final VoidCallback onQuiz;
  final DateTime Function() clock;

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _Stats {
  const _Stats(this.progress, this.recents, this.today, this.quiz);
  final Map<String, CategoryProgress> progress;
  final List<RecentTopic> recents;
  final int today;
  final QuizStats? quiz;
}

class _ProfileScreenState extends State<ProfileScreen> {
  _Stats? _stats;

  @override
  void initState() {
    super.initState();
    widget.study.addListener(_load);
    _load();
  }

  @override
  void dispose() {
    widget.study.removeListener(_load);
    super.dispose();
  }

  Future<void> _load() async {
    final now = widget.clock();
    final s = widget.study;
    final results = await Future.wait([
      s.progress(),
      s.recentTopics(),
      s.signsViewedSince(DateTime(now.year, now.month, now.day)),
      s.quizStats(),
    ]);
    if (!mounted) return;
    setState(
      () => _stats = _Stats(
        results[0] as Map<String, CategoryProgress>,
        results[1] as List<RecentTopic>,
        results[2] as int,
        results[3] as QuizStats?,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.profile;
    final top = MediaQuery.paddingOf(context).top;
    final stats = _stats;
    const band = 210.0;
    const avatar = 168.0;

    return ColoredBox(
      color: AppColors.white,
      child: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: EdgeInsets.only(
          bottom: 120 + MediaQuery.paddingOf(context).bottom,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(
              height: top + band + avatar / 2,
              child: Stack(
                children: [
                  Positioned(
                    top: 0,
                    left: 0,
                    right: 0,
                    height: top + band,
                    child: ColoredBox(
                      color: AppColors.mist,
                      // Same faint photo as the Home header.
                      child: Opacity(
                        opacity: 0.25,
                        child: Image.asset(
                          'assets/art/home/header.jpg',
                          fit: BoxFit.cover,
                          errorBuilder: (_, _, _) => const SizedBox.shrink(),
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    top: top + 20,
                    left: 24,
                    child: Text(
                      'Profile',
                      style: Theme.of(context).textTheme.headlineLarge,
                    ),
                  ),
                  Positioned(
                    top: top + 14,
                    right: 16,
                    child: Semantics(
                      button: true,
                      label: 'Edit profile',
                      excludeSemantics: true,
                      child: Pressable(
                        onTap: widget.onEdit,
                        scale: 0.88,
                        child: Container(
                          width: 46,
                          height: 46,
                          decoration: BoxDecoration(
                            color: AppColors.white,
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: AppColors.ink.withValues(alpha: 0.1),
                                blurRadius: 12,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: const Icon(
                            Icons.edit_rounded,
                            color: AppColors.teal,
                          ),
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: 0,
                    child: Center(
                      child: SizedBox(
                        width: avatar + 90,
                        height: avatar + 60,
                        child: Stack(
                          alignment: Alignment.bottomCenter,
                          children: [
                            Positioned.fill(
                              child: ExcludeSemantics(
                                child: CustomPaint(
                                  painter: _ArcTextPainter(
                                    text: p.nickname.toUpperCase(),
                                    radius: avatar / 2 + 14,
                                    center: Offset(
                                      (avatar + 90) / 2,
                                      60 + avatar / 2,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            ProfileAvatar(
                              nickname: p.nickname,
                              photoPath: p.photoPath,
                              size: avatar,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 28, 20, 0),
              child: StaggeredEntrance(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                stagger: const Duration(milliseconds: 60),
                children: [
                  _InfoRow(label: 'NAME', value: p.name),
                  _InfoRow(label: 'AGE', value: '${p.currentAge} years old'),
                  _InfoRow(
                    label: 'BIRTHDAY',
                    value: formatLongDate(p.birthdate),
                  ),
                  const SizedBox(height: 18),
                  _ProgressCard(progress: stats?.progress),
                  const SizedBox(height: 14),
                  _TodayCard(
                    today: stats?.today,
                    quiz: stats?.quiz,
                    onQuiz: widget.onQuiz,
                  ),
                  const SizedBox(height: 14),
                  _RecentsCard(
                    recents: stats?.recents,
                    now: widget.clock(),
                    onOpen: (r) => openTopic(
                      context,
                      lessons: widget.lessons,
                      study: widget.study,
                      categoryId: r.categoryId,
                      topicId: r.topicId,
                    ),
                  ),
                  const SizedBox(height: 14),
                  _ActivityCard(
                    onOpen: () => Navigator.of(context).push(
                      MaterialPageRoute(
                        settings: const RouteSettings(name: 'Activity log'),
                        builder: (_) => ActivityLogScreen(study: widget.study),
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
}

/// Draws [text] along the upper-left of a circle, like the mockup's
/// nickname curving over the photo.
class _ArcTextPainter extends CustomPainter {
  _ArcTextPainter({
    required this.text,
    required this.radius,
    required this.center,
  });

  final String text;
  final double radius;
  final Offset center;

  static const _style = TextStyle(
    fontFamily: AppFonts.display,
    fontWeight: FontWeight.w900,
    fontSize: 26,
    color: Color(0xFF42927A),
  );

  @override
  void paint(Canvas canvas, Size size) {
    if (text.isEmpty) return;
    final glyphs = [
      for (final ch in text.characters)
        TextPainter(
          text: TextSpan(text: ch, style: _style),
          textDirection: TextDirection.ltr,
        )..layout(),
    ];
    const spacing = 2.0;
    final arcLength =
        glyphs.fold<double>(0, (sum, g) => sum + g.width + spacing) - spacing;
    final textRadius = radius + 6;
    // Centre the word on the upper-left at -135°, and cap it to a half circle.
    final sweep = math.min(arcLength / textRadius, math.pi);
    final scale = sweep / (arcLength / textRadius);
    var angle = -3 * math.pi / 4 - sweep / 2;

    for (final g in glyphs) {
      final w = (g.width + spacing) * scale;
      final mid = angle + (g.width * scale / 2) / textRadius;
      canvas.save();
      canvas.translate(
        center.dx + textRadius * math.cos(mid),
        center.dy + textRadius * math.sin(mid),
      );
      canvas.rotate(mid + math.pi / 2);
      canvas.scale(scale);
      g.paint(canvas, Offset(-g.width / 2, -g.height * 0.75));
      canvas.restore();
      angle += w / textRadius;
    }
  }

  @override
  bool shouldRepaint(_ArcTextPainter old) =>
      old.text != text || old.radius != radius || old.center != center;
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Container(
            width: 112,
            padding: const EdgeInsets.symmetric(vertical: 8),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: AppColors.butter,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              label,
              style: const TextStyle(
                fontFamily: AppFonts.display,
                fontWeight: FontWeight.w600,
                fontSize: 16,
                color: AppColors.teal,
              ),
            ),
          ),
          Expanded(
            child: Container(
              padding: const EdgeInsets.fromLTRB(12, 0, 4, 4),
              decoration: const BoxDecoration(
                border: Border(
                  bottom: BorderSide(color: AppColors.butter, width: 2),
                ),
              ),
              child: Text(
                value,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontFamily: AppFonts.display,
                  fontWeight: FontWeight.w700,
                  fontSize: 17,
                  color: AppColors.slate,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Card extends StatelessWidget {
  const _Card({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
      decoration: BoxDecoration(
        color: AppColors.butter,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontFamily: AppFonts.display,
              fontWeight: FontWeight.w700,
              fontSize: 17,
              color: AppColors.ink,
            ),
          ),
          const SizedBox(height: 10),
          child,
        ],
      ),
    );
  }
}

class _ActivityCard extends StatelessWidget {
  const _ActivityCard({required this.onOpen});

  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    return _Card(
      title: 'Activity log',
      child: Semantics(
        button: true,
        label: 'Open activity log',
        excludeSemantics: true,
        child: Pressable(
          onTap: onOpen,
          scale: 0.97,
          child: Container(
            padding: const EdgeInsets.fromLTRB(6, 6, 14, 6),
            decoration: BoxDecoration(
              color: AppColors.teal,
              borderRadius: BorderRadius.circular(28),
            ),
            child: const Row(
              children: [
                CircleAvatar(
                  radius: 22,
                  backgroundColor: AppColors.sage,
                  child: Icon(
                    Icons.history_rounded,
                    color: AppColors.white,
                    size: 24,
                  ),
                ),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'When the app was opened, and every lesson, sign, quiz '
                    'and game tapped',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 13.5,
                      color: AppColors.white,
                    ),
                  ),
                ),
                Icon(Icons.chevron_right_rounded, color: AppColors.white),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ProgressCard extends StatelessWidget {
  const _ProgressCard({required this.progress});

  final Map<String, CategoryProgress>? progress;

  @override
  Widget build(BuildContext context) {
    return _Card(
      title: 'Your Progress',
      child: Column(
        children: [
          for (final c in LearningContent.categories)
            _ProgressRow(category: c, progress: progress?[c.id]),
        ],
      ),
    );
  }
}

class _ProgressRow extends StatelessWidget {
  const _ProgressRow({required this.category, required this.progress});

  final LessonCategory category;
  final CategoryProgress? progress;

  @override
  Widget build(BuildContext context) {
    final f = progress?.fraction ?? 0;
    final pct = (f * 100).round();
    final detail = progress == null
        ? ''
        : '${progress!.viewed} of ${progress!.total} signs';
    return Semantics(
      label: '${category.title}: $pct percent, $detail',
      excludeSemantics: true,
      child: Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Row(
          children: [
            Container(
              width: 52,
              height: 38,
              decoration: BoxDecoration(
                color: category.color,
                borderRadius: BorderRadius.circular(19),
              ),
              child: Icon(category.icon, color: AppColors.white, size: 24),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          category.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.slate,
                          ),
                        ),
                      ),
                      Text(
                        '$pct%',
                        style: const TextStyle(
                          fontFamily: AppFonts.display,
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                          color: AppColors.ink,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: TweenAnimationBuilder<double>(
                      tween: Tween(begin: 0, end: f),
                      duration: const Duration(milliseconds: 800),
                      curve: Curves.easeOutCubic,
                      builder: (context, v, _) => LinearProgressIndicator(
                        value: v,
                        minHeight: 10,
                        backgroundColor: AppColors.cream,
                        color: AppColors.mint,
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
}

class _TodayCard extends StatelessWidget {
  const _TodayCard({
    required this.today,
    required this.quiz,
    required this.onQuiz,
  });

  final int? today;
  final QuizStats? quiz;
  final VoidCallback onQuiz;

  @override
  Widget build(BuildContext context) {
    final q = quiz;
    return _Card(
      title: 'Today',
      child: Row(
        children: [
          Expanded(
            child: _Stat(
              value: today == null ? '–' : '$today',
              label: today == 1 ? 'sign reviewed' : 'signs reviewed',
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Semantics(
              button: true,
              label: q == null
                  ? 'Take your first quiz'
                  : 'Best quiz score ${q.bestScore} of ${q.bestTotal}. '
                        'Take a quiz',
              excludeSemantics: true,
              child: Pressable(
                onTap: onQuiz,
                scale: 0.95,
                child: _Stat(
                  value: q == null ? 'Quiz' : '${q.bestScore}/${q.bestTotal}',
                  label: q == null ? 'take your first →' : 'best quiz →',
                  accent: true,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.value, required this.label, this.accent = false});

  final String value;
  final String label;
  final bool accent;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 10),
      decoration: BoxDecoration(
        color: accent ? AppColors.teal : AppColors.cream,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        children: [
          Text(
            value,
            style: TextStyle(
              fontFamily: AppFonts.display,
              fontWeight: FontWeight.w900,
              fontSize: 26,
              color: accent ? AppColors.white : AppColors.teal,
            ),
          ),
          Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 12,
              color: accent ? AppColors.white : AppColors.slate,
            ),
          ),
        ],
      ),
    );
  }
}

class _RecentsCard extends StatelessWidget {
  const _RecentsCard({
    required this.recents,
    required this.now,
    required this.onOpen,
  });

  final List<RecentTopic>? recents;
  final DateTime now;
  final ValueChanged<RecentTopic> onOpen;

  String _when(DateTime t) {
    final today = DateTime(now.year, now.month, now.day);
    final day = DateTime(t.year, t.month, t.day);
    final hm =
        '${t.hour.toString().padLeft(2, '0')}:'
        '${t.minute.toString().padLeft(2, '0')}';
    final days = today.difference(day).inDays;
    if (days <= 0) return hm;
    if (days == 1) return 'Yesterday';
    if (days < 7) return '$days days ago';
    return formatLongDate(t);
  }

  @override
  Widget build(BuildContext context) {
    final list = recents;
    return _Card(
      title: 'Recents',
      child: list == null
          ? const SizedBox(height: 40)
          : list.isEmpty
          ? const Padding(
              padding: EdgeInsets.symmetric(vertical: 6),
              child: Text(
                'Lessons you open will show up here.',
                style: TextStyle(fontSize: 13.5, color: AppColors.slate),
              ),
            )
          : Column(
              children: [
                for (final r in list)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: _RecentTile(
                      recent: r,
                      when: _when(r.lastViewed),
                      onTap: () => onOpen(r),
                    ),
                  ),
              ],
            ),
    );
  }
}

class _RecentTile extends StatelessWidget {
  const _RecentTile({
    required this.recent,
    required this.when,
    required this.onTap,
  });

  final RecentTopic recent;
  final String when;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = LearningContent.byId(recent.categoryId);
    return Semantics(
      button: true,
      label: '${recent.topicTitle}, ${c.title}, $when',
      excludeSemantics: true,
      child: Pressable(
        onTap: onTap,
        scale: 0.97,
        child: Container(
          padding: const EdgeInsets.fromLTRB(6, 6, 6, 6),
          decoration: BoxDecoration(
            color: AppColors.teal,
            borderRadius: BorderRadius.circular(28),
          ),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: c.color == AppColors.teal ? AppColors.sage : c.color,
                  shape: BoxShape.circle,
                ),
                child: Icon(c.icon, color: AppColors.white, size: 24),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      recent.topicTitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                        color: AppColors.white,
                      ),
                    ),
                    Text(
                      '${c.title} · $when',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.white.withValues(alpha: 0.8),
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(
                Icons.chevron_right_rounded,
                color: AppColors.white,
                size: 30,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
