import 'package:flutter/material.dart';

import '../../data/learning_content.dart';
import '../../data/lesson_models.dart';
import '../../data/lesson_repository.dart';
import '../../data/study_repository.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_theme.dart';
import '../../widgets/media_placeholder.dart';
import '../../widgets/pressable.dart';
import '../../widgets/staggered_entrance.dart';
import 'topic_screen.dart';

/// A category's topics, styled after the "Foundational Signs" mockup. The
/// header is the home tile, grown into place with a Hero.
class CategoryScreen extends StatefulWidget {
  const CategoryScreen({
    super.key,
    required this.category,
    required this.lessons,
    required this.study,
  });

  final LessonCategory category;
  final LessonRepository lessons;
  final StudyRepository study;

  @override
  State<CategoryScreen> createState() => _CategoryScreenState();
}

class _CategoryScreenState extends State<CategoryScreen> {
  late final Future<List<LessonTopic>> _topics = widget.lessons.topicsFor(
    widget.category.id,
  );

  @override
  Widget build(BuildContext context) {
    final category = widget.category;
    return Scaffold(
      backgroundColor: AppColors.white,
      body: SafeArea(
        bottom: false,
        child: CustomScrollView(
          physics: const BouncingScrollPhysics(),
          slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                child: Row(
                  children: [
                    LessonBackButton(
                      onTap: () => Navigator.of(context).maybePop(),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Hero(
                        tag: 'category-${category.id}',
                        child: Material(
                          color: category.color,
                          borderRadius: BorderRadius.circular(20),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 12,
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  category.icon,
                                  color: AppColors.white,
                                  size: 32,
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    category.fullTitle,
                                    style: const TextStyle(
                                      fontFamily: AppFonts.display,
                                      fontWeight: FontWeight.w700,
                                      fontSize: 18,
                                      color: AppColors.white,
                                      height: 1.15,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            FutureBuilder<List<LessonTopic>>(
              future: _topics,
              builder: (context, snap) {
                if (snap.hasError) {
                  return const SliverFillRemaining(
                    hasScrollBody: false,
                    child: Center(child: Text('Couldn’t load these lessons.')),
                  );
                }
                if (!snap.hasData) {
                  return const SliverFillRemaining(
                    hasScrollBody: false,
                    child: Center(
                      child: CircularProgressIndicator(color: AppColors.teal),
                    ),
                  );
                }
                final topics = snap.data!;
                return SliverPadding(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 40),
                  sliver: SliverToBoxAdapter(
                    child: StaggeredEntrance(
                      delay: const Duration(milliseconds: 120),
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        for (var i = 0; i < topics.length; i++)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 18),
                            child: _TopicCard(
                              topic: topics[i],
                              tint: _tints[i % _tints.length],
                              onTap: () => Navigator.of(context).push(
                                MaterialPageRoute(
                                  settings: RouteSettings(
                                    name: 'Topic',
                                    arguments: topics[i].title,
                                  ),
                                  builder: (_) => TopicScreen(
                                    category: category,
                                    topic: topics[i],
                                    study: widget.study,
                                  ),
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  // Card tints from the mockup's topic photos (sage, olive, seafoam, mist).
  static const _tints = [
    Color(0xFFC6D79C),
    Color(0xFFA3954A),
    AppColors.seafoam,
    AppColors.cloud,
  ];
}

class _TopicCard extends StatelessWidget {
  const _TopicCard({
    required this.topic,
    required this.tint,
    required this.onTap,
  });

  final LessonTopic topic;
  final Color tint;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final n = topic.signs.length;
    return Semantics(
      button: true,
      label: '${topic.title}, $n sign${n == 1 ? '' : 's'}',
      excludeSemantics: true,
      child: Pressable(
        onTap: onTap,
        scale: 0.97,
        child: Container(
          height: 124,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: AppColors.seafoam, width: 1.4),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(21),
            child: Stack(
              fit: StackFit.expand,
              children: [
                MediaPlaceholder(
                  color: tint,
                  compact: true,
                  iconAlignment: Alignment.topRight,
                ),
                Align(
                  alignment: const Alignment(0, 0.15),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 8,
                    ),
                    color: AppColors.white.withValues(alpha: 0.78),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          topic.title.toUpperCase(),
                          textAlign: TextAlign.center,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontFamily: AppFonts.display,
                            fontWeight: FontWeight.w700,
                            fontSize: 17,
                            letterSpacing: 3,
                            color: AppColors.ink,
                          ),
                        ),
                        Text(
                          '$n sign${n == 1 ? '' : 's'}',
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.slate,
                          ),
                        ),
                      ],
                    ),
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

/// Round back button shared by the lesson screens.
class LessonBackButton extends StatelessWidget {
  const LessonBackButton({super.key, required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'Back',
      child: Pressable(
        onTap: onTap,
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
          child: const Icon(Icons.arrow_back_rounded, color: AppColors.teal),
        ),
      ),
    );
  }
}
