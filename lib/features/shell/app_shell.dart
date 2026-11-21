import 'package:flutter/material.dart';

import '../../data/lesson_repository.dart';
import '../../data/photo_picker.dart';
import '../../data/study_repository.dart';
import '../../data/user_profile.dart';
import '../../data/user_repository.dart';
import '../../theme/app_colors.dart';
import '../../widgets/profile_avatar.dart';
import '../bookmarks/bookmarks_screen.dart';
import '../explore/explore_screen.dart';
import '../home/home_screen.dart';
import '../profile/edit_profile_screen.dart';
import '../profile/profile_screen.dart';
import '../game/memory_game_screen.dart';
import '../quiz/quiz_screen.dart';
import 'floating_nav_bar.dart';

/// Signed-in shell: the four tabs plus the floating nav bar. Every tab stays
/// alive (so Home keeps its scroll position) and the active one cross-fades in.
class AppShell extends StatefulWidget {
  const AppShell({
    super.key,
    required this.profile,
    required this.lessons,
    required this.study,
    required this.users,
    required this.photoPicker,
    required this.onProfileChanged,
  });

  final UserProfile profile;
  final LessonRepository lessons;
  final StudyRepository study;
  final UserRepository users;
  final PhotoPicker photoPicker;
  final ValueChanged<UserProfile> onProfileChanged;

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  static const home = 0, explore = 1;

  int _index = home;
  final _searchFocus = FocusNode();

  @override
  void dispose() {
    _searchFocus.dispose();
    super.dispose();
  }

  void _select(int i) {
    if (i == _index) return;
    if (_index == explore) _searchFocus.unfocus();
    setState(() => _index = i);
  }

  /// The home search bar jumps to Explore with the keyboard up.
  void _startSearch() {
    _select(explore);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _searchFocus.requestFocus();
    });
  }

  void _openQuiz() => Navigator.of(context).push(
    MaterialPageRoute(
      builder: (_) => QuizScreen(
        profile: widget.profile,
        lessons: widget.lessons,
        study: widget.study,
      ),
    ),
  );

  void _openGame() => Navigator.of(context).push(
    MaterialPageRoute(
      builder: (_) => MemoryGameScreen(
        profile: widget.profile,
        lessons: widget.lessons,
        study: widget.study,
      ),
    ),
  );

  Future<void> _editProfile() async {
    final saved = await Navigator.of(context).push<UserProfile>(
      MaterialPageRoute(
        builder: (_) => EditProfileScreen(
          profile: widget.profile,
          repository: widget.users,
          photoPicker: widget.photoPicker,
        ),
      ),
    );
    if (saved != null) widget.onProfileChanged(saved);
  }

  @override
  Widget build(BuildContext context) {
    final profile = widget.profile;
    final tabs = <Widget>[
      HomeScreen(
        profile: profile,
        lessons: widget.lessons,
        study: widget.study,
        onSearchTap: _startSearch,
        onQuizTap: _openQuiz,
        onGameTap: _openGame,
      ),
      ExploreScreen(
        lessons: widget.lessons,
        study: widget.study,
        searchFocus: _searchFocus,
      ),
      BookmarksScreen(
        lessons: widget.lessons,
        study: widget.study,
        onExplore: _startSearch,
      ),
      ProfileScreen(
        profile: profile,
        lessons: widget.lessons,
        study: widget.study,
        onEdit: _editProfile,
        onQuiz: _openQuiz,
      ),
    ];

    return PopScope(
      // Back on another tab returns to Home before leaving the app.
      canPop: _index == home,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _select(home);
      },
      child: Scaffold(
        backgroundColor: AppColors.white,
        extendBody: true,
        body: Stack(
          children: [
            for (var i = 0; i < tabs.length; i++)
              _TabLayer(active: i == _index, child: tabs[i]),
          ],
        ),
        bottomNavigationBar: SafeArea(
          minimum: const EdgeInsets.fromLTRB(20, 0, 20, 14),
          child: FloatingNavBar(
            currentIndex: _index,
            onTap: _select,
            items: [
              const NavItem(label: 'Home', icon: Icons.home_rounded),
              const NavItem(label: 'Explore', icon: Icons.search_rounded),
              const NavItem(label: 'Bookmark', icon: Icons.bookmark_rounded),
              NavItem(
                label: 'Profile',
                iconBuilder: (_) => ProfileAvatar(
                  nickname: profile.nickname,
                  photoPath: profile.photoPath,
                  size: 28,
                  ring: false,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Keeps a tab mounted (so it keeps its state) and cross-fades it in and out.
///
/// The fade lives *outside* the TickerMode: the layer's own animations must
/// keep running while it fades out, or it freezes fully visible on top of the
/// next tab. Once the fade-out ends the tab goes Offstage, which stops its
/// tickers (looping animations, tip timer) and skips painting it.
class _TabLayer extends StatefulWidget {
  const _TabLayer({required this.active, required this.child});

  final bool active;
  final Widget child;

  @override
  State<_TabLayer> createState() => _TabLayerState();
}

class _TabLayerState extends State<_TabLayer> {
  late bool _hidden = !widget.active;

  @override
  void didUpdateWidget(_TabLayer old) {
    super.didUpdateWidget(old);
    if (widget.active && _hidden) _hidden = false;
  }

  void _onFadeEnd() {
    if (!widget.active && !_hidden) setState(() => _hidden = true);
  }

  @override
  Widget build(BuildContext context) {
    final active = widget.active;
    return Offstage(
      offstage: _hidden,
      child: IgnorePointer(
        ignoring: !active,
        child: AnimatedOpacity(
          opacity: active ? 1 : 0,
          duration: const Duration(milliseconds: 280),
          curve: Curves.easeOut,
          onEnd: _onFadeEnd,
          child: AnimatedSlide(
            offset: active ? Offset.zero : const Offset(0, 0.02),
            duration: const Duration(milliseconds: 340),
            curve: Curves.easeOutCubic,
            child: ExcludeSemantics(excluding: !active, child: widget.child),
          ),
        ),
      ),
    );
  }
}
