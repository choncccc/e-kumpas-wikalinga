import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'data/lesson_repository.dart';
import 'data/photo_picker.dart';
import 'data/study_repository.dart';
import 'data/user_profile.dart';
import 'data/user_repository.dart';
import 'features/onboarding/onboarding_screen.dart';
import 'features/onboarding/steps/welcome_step.dart';
import 'features/shell/app_shell.dart';
import 'theme/app_colors.dart';
import 'theme/app_theme.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
    ),
  );
  final lessons = SqliteLessonRepository();
  runApp(
    EKumpasApp(
      repository: SqliteUserRepository(),
      lessons: lessons,
      study: SqliteStudyRepository(lessons),
      photoPicker: DevicePhotoPicker(),
    ),
  );
}

class EKumpasApp extends StatelessWidget {
  const EKumpasApp({
    super.key,
    required this.repository,
    required this.lessons,
    required this.study,
    required this.photoPicker,
  });

  final UserRepository repository;
  final LessonRepository lessons;
  final StudyRepository study;
  final PhotoPicker photoPicker;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'e-Kumpas Wikalinga',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      home: LaunchGate(
        repository: repository,
        lessons: lessons,
        study: study,
        photoPicker: photoPicker,
      ),
    );
  }
}

/// Reads the saved profile on launch and shows onboarding or home.
class LaunchGate extends StatefulWidget {
  const LaunchGate({
    super.key,
    required this.repository,
    required this.lessons,
    required this.study,
    required this.photoPicker,
  });

  final UserRepository repository;
  final LessonRepository lessons;
  final StudyRepository study;
  final PhotoPicker photoPicker;

  @override
  State<LaunchGate> createState() => _LaunchGateState();
}

enum _Phase { loading, onboarding, home }

class _LaunchGateState extends State<LaunchGate> {
  _Phase _phase = _Phase.loading;
  UserProfile? _profile;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    UserProfile? profile;
    try {
      profile = await widget.repository.getProfile();
    } catch (_) {
      profile = null; // Unreadable DB: fall back to sign-up rather than hang.
    }
    if (!mounted) return;
    setState(() {
      _profile = profile;
      _phase = profile == null ? _Phase.onboarding : _Phase.home;
    });
  }

  void _onSignedUp(UserProfile profile) => setState(() {
    _profile = profile;
    _phase = _Phase.home;
  });

  void _onProfileChanged(UserProfile profile) =>
      setState(() => _profile = profile);

  @override
  Widget build(BuildContext context) {
    final Widget child = switch (_phase) {
      _Phase.loading => const ColoredBox(
        key: ValueKey('loading'),
        color: AppColors.cream,
        child: Center(child: WavingHand(size: 96)),
      ),
      _Phase.onboarding => OnboardingScreen(
        key: const ValueKey('onboarding'),
        repository: widget.repository,
        onComplete: _onSignedUp,
        photoPicker: widget.photoPicker,
      ),
      _Phase.home => AppShell(
        key: const ValueKey('home'),
        profile: _profile!,
        lessons: widget.lessons,
        study: widget.study,
        users: widget.repository,
        photoPicker: widget.photoPicker,
        onProfileChanged: _onProfileChanged,
      ),
    };

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 700),
      switchInCurve: Curves.easeOutCubic,
      switchOutCurve: Curves.easeInCubic,
      transitionBuilder: (child, animation) => FadeTransition(
        opacity: animation,
        child: ScaleTransition(
          scale: Tween(begin: 0.94, end: 1.0).animate(animation),
          child: child,
        ),
      ),
      child: child,
    );
  }
}
