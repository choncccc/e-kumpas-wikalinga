import 'package:flutter/material.dart';

import '../../data/lesson_repository.dart';
import '../../data/user_profile.dart';
import '../../theme/app_colors.dart';
import '../../widgets/profile_avatar.dart';
import '../home/home_screen.dart';
import 'coming_soon_tab.dart';
import 'floating_nav_bar.dart';

/// Signed-in shell: the four tabs plus the floating nav bar. Every tab stays
/// alive (so Home keeps its scroll position) and the active one cross-fades in.
class AppShell extends StatefulWidget {
  const AppShell({super.key, required this.profile, required this.lessons});

  final UserProfile profile;
  final LessonRepository lessons;

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  static const home = 0, explore = 1;

  int _index = home;

  void _select(int i) {
    if (i == _index) return;
    setState(() => _index = i);
  }

  @override
  Widget build(BuildContext context) {
    final profile = widget.profile;
    final tabs = <Widget>[
      HomeScreen(
        profile: profile,
        lessons: widget.lessons,
        onSearchTap: () => _select(explore),
      ),
      const ComingSoonTab(
        icon: Icons.search_rounded,
        title: 'Explore',
        message: 'Search every sign and medical term here. Coming soon.',
      ),
      const ComingSoonTab(
        icon: Icons.bookmark_rounded,
        title: 'Bookmarks',
        message: 'Signs you save will show up here. Coming soon.',
      ),
      const ComingSoonTab(
        icon: Icons.person_rounded,
        title: 'Profile',
        message: 'Your progress and recent lessons. Coming soon.',
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
