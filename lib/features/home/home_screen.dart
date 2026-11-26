import 'package:flutter/material.dart';

import '../../data/learning_content.dart';
import '../../data/lesson_repository.dart';
import '../../data/study_repository.dart';
import '../../data/user_profile.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_theme.dart';
import '../../widgets/profile_avatar.dart';
import '../../widgets/staggered_entrance.dart';
import '../lessons/category_screen.dart';
import '../procedure/bp_procedure_screen.dart';
import 'widgets/card_art.dart';
import 'widgets/home_cards.dart';
import 'widgets/tips_card.dart';

/// Home dashboard from the mockup: greeting, search, the six lesson
/// categories, then the BP procedure / quiz / games cards beside the tips card.
class HomeScreen extends StatefulWidget {
  const HomeScreen({
    super.key,
    required this.profile,
    required this.lessons,
    required this.study,
    required this.onSearchTap,
    required this.onQuizTap,
    required this.onGameTap,
  });

  final UserProfile profile;
  final LessonRepository lessons;
  final StudyRepository study;
  final VoidCallback onSearchTap;
  final VoidCallback onQuizTap;
  final VoidCallback onGameTap;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _scroll = ScrollController();

  /// Height of the grey header band below the status bar.
  static const _headerHeight = 196.0;

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  void _openProcedure() => Navigator.of(context).push(
    MaterialPageRoute(
      settings: const RouteSettings(name: 'BP Procedure'),
      builder: (_) => const BpProcedureScreen(),
    ),
  );

  void _openCategory(LessonCategory c) {
    Navigator.of(context).push(
      MaterialPageRoute(
        settings: RouteSettings(name: 'Category', arguments: c.title),
        builder: (_) => CategoryScreen(
          category: c,
          lessons: widget.lessons,
          study: widget.study,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final topInset = MediaQuery.paddingOf(context).top;
    final profile = widget.profile;
    final categories = LearningContent.categories;

    return ColoredBox(
      color: AppColors.white,
      child: SingleChildScrollView(
        controller: _scroll,
        physics: const BouncingScrollPhysics(),
        // Room for the floating nav bar.
        padding: EdgeInsets.only(
          bottom: 120 + MediaQuery.paddingOf(context).bottom,
        ),
        child: Stack(
          children: [
            // Header band with a faint parallax photo behind the greeting.
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              height: topInset + _headerHeight,
              child: ClipRect(
                child: ListenableBuilder(
                  listenable: _scroll,
                  builder: (context, child) {
                    final offset = _scroll.hasClients ? _scroll.offset : 0.0;
                    return Transform.translate(
                      // Moves at half speed, so it lags behind the content.
                      offset: Offset(0, offset * 0.5),
                      child: child,
                    );
                  },
                  child: ColoredBox(
                    color: AppColors.mist,
                    // Faint, so the greeting stays readable over it.
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
              ),
            ),
            Padding(
              padding: EdgeInsets.fromLTRB(20, topInset + 20, 20, 0),
              child: StaggeredEntrance(
                delay: const Duration(milliseconds: 120),
                stagger: const Duration(milliseconds: 60),
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _Greeting(profile: profile),
                  const SizedBox(height: 18),
                  HomeSearchBar(onTap: widget.onSearchTap),
                  const SizedBox(height: 34),
                  for (var row = 0; row < categories.length; row += 2)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 14),
                      child: Row(
                        children: [
                          for (
                            var i = row;
                            i < row + 2 && i < categories.length;
                            i++
                          ) ...[
                            if (i > row) const SizedBox(width: 14),
                            Expanded(
                              child: AspectRatio(
                                aspectRatio: 1.75,
                                child: CategoryTile(
                                  category: categories[i],
                                  onTap: () => _openCategory(categories[i]),
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  const SizedBox(height: 12),
                  SizedBox(
                    height: 350,
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Expanded(
                          flex: 53,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Expanded(
                                flex: 4,
                                child: FeatureCard(
                                  semanticLabel:
                                      'BP Procedure: how to take blood '
                                      'pressure, step by step',
                                  image: 'assets/procedure/bp_cover.jpg',
                                  title: 'BP PROCEDURE',
                                  subtitle: 'How to take BP',
                                  placeholderColor: AppColors.aqua,
                                  onTap: _openProcedure,
                                ),
                              ),
                              const SizedBox(height: 12),
                              Expanded(
                                flex: 3,
                                child: FeatureCard(
                                  semanticLabel:
                                      'Quiz: Test, sign and learn. Sign it Right!',
                                  art: const CardArt(
                                    color: Color(0xFFC0B373),
                                    backdropIcon: Icons.quiz_rounded,
                                    motif: QuizMotif(),
                                  ),
                                  title: 'QUIZ: TEST, SIGN & LEARN',
                                  subtitle: 'Sign it Right!',
                                  placeholderColor: const Color(0xFFC0B373),
                                  onTap: widget.onQuizTap,
                                ),
                              ),
                              const SizedBox(height: 12),
                              Expanded(
                                flex: 3,
                                child: FeatureCard(
                                  semanticLabel: 'Games: Memory Card Flip',
                                  art: const CardArt(
                                    color: Color(0xFFD9CC45),
                                    backdropIcon: Icons.style_rounded,
                                    motif: MemoryMotif(),
                                  ),
                                  title: 'GAMES',
                                  subtitle: 'Memory Card Flip',
                                  placeholderColor: const Color(0xFFD9CC45),
                                  onTap: widget.onGameTap,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),
                        const Expanded(flex: 47, child: TipsCard()),
                      ],
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

class _Greeting extends StatelessWidget {
  const _Greeting({required this.profile});

  final UserProfile profile;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        ProfileAvatar(
          nickname: profile.nickname,
          photoPath: profile.photoPath,
          size: 72,
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
                  fontSize: 34,
                  color: AppColors.ink,
                  height: 1.05,
                ),
              ),
              Text(
                profile.nickname.toUpperCase(),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 18,
                  color: AppColors.teal,
                  letterSpacing: 0.6,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
