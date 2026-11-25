import 'dart:io';

import 'package:ekumpas_wikalinga/data/avatar_storage.dart';
import 'package:ekumpas_wikalinga/data/photo_picker.dart';
import 'package:ekumpas_wikalinga/data/user_profile.dart';
import 'package:ekumpas_wikalinga/data/user_repository.dart';
import 'package:ekumpas_wikalinga/features/onboarding/onboarding_draft.dart';
import 'package:ekumpas_wikalinga/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fakes.dart';

class FakeUserRepository implements UserRepository {
  FakeUserRepository([this.saved]);
  UserProfile? saved;

  @override
  Future<UserProfile?> getProfile() async => saved;

  @override
  Future<UserProfile> saveProfile(UserProfile profile) async {
    saved = UserProfile.fromMap({...profile.toMap(), 'id': 1});
    return saved!;
  }
}

class FakePhotoPicker implements PhotoPicker {
  FakePhotoPicker(this.result);
  final String? result;
  final calls = <PhotoSource>[];

  @override
  Future<String?> pick(PhotoSource source) async {
    calls.add(source);
    return result;
  }
}

/// The app has looping background animations, so pumpAndSettle never settles.
Future<void> settle(WidgetTester tester) async {
  for (var i = 0; i < 12; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

void main() {
  group('UserProfile.ageOn', () {
    test('counts only completed birthdays', () {
      final b = DateTime(2000, 6, 15);
      expect(UserProfile.ageOn(b, DateTime(2026, 6, 14)), 25);
      expect(UserProfile.ageOn(b, DateTime(2026, 6, 15)), 26);
    });

    test('round-trips through a DB map', () {
      final p = UserProfile(
        id: 3,
        name: 'Yesh Nin',
        nickname: 'Yesh',
        birthdate: DateTime(2000, 2, 29),
        age: 26,
        createdAt: DateTime(2026, 11, 14, 9),
      );
      final back = UserProfile.fromMap(p.toMap());
      expect(p.toMap()['birthdate'], '2000-02-29');
      expect(back.birthdate, DateTime(2000, 2, 29));
      expect(back.nickname, 'Yesh');
    });
  });

  group('OnboardingDraft validation', () {
    OnboardingDraft draft() =>
        OnboardingDraft(clock: () => DateTime(2026, 11, 14));

    test('name', () {
      final d = draft();
      expect(d.nameError, isNotNull);
      d.name = 'J';
      expect(d.nameError, isNotNull);
      d.name = 'Ma. Teresa Dela Cruz-Peña';
      expect(d.nameError, isNull);
      d.name = 'R2D2';
      expect(d.nameError, isNotNull);
    });

    test('age is calculated from the birthdate', () {
      final d = draft();
      expect(d.age, isNull);
      d.birthdate = DateTime(2000, 12, 1);
      expect(d.age, 25, reason: 'birthday not reached yet on 2026-11-14');
      d.birthdate = DateTime(2000, 11, 14);
      expect(d.age, 26);
    });

    test('rejects future and too-young birthdates', () {
      final d = draft()..birthdate = DateTime(2027);
      expect(d.birthdateError, isNotNull);
      d.birthdate = DateTime(2025);
      expect(d.birthdateError, isNotNull);
    });

    test('suggests first name as nickname', () {
      final d = draft()..name = '  Yesh  Nin ';
      expect(d.suggestedNickname, 'Yesh');
    });
  });

  testWidgets('full sign-up flow saves the profile and lands on home', (
    tester,
  ) async {
    final repo = FakeUserRepository();
    final picker = FakePhotoPicker('/tmp/picked.jpg');
    // A typical phone screen (360x780), not the 800x600 test default.
    tester.view.physicalSize = const Size(1080, 2340);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      EKumpasApp(
        repository: repo,
        lessons: FakeLessonRepository(),
        study: FakeStudyRepository(),
        photoPicker: picker,
      ),
    );
    await settle(tester);

    expect(find.text('Kumusta!'), findsOneWidget);
    await tester.tap(find.text('Get started'));
    await settle(tester);

    await tester.enterText(find.byType(TextField), 'Yesh Nin');
    await settle(tester);
    await tester.tap(find.text('Continue'));
    await settle(tester);

    // Suggestion chip fills the nickname.
    await tester.tap(find.text('Use “Yesh”'));
    await settle(tester);
    await tester.tap(find.text('Continue'));
    await settle(tester);

    // Photo step is optional: the button reads "Skip" until a photo is added.
    expect(find.text('Add a profile picture'), findsOneWidget);
    expect(find.text('Skip for now'), findsOneWidget);
    await tester.tap(find.text('Gallery'));
    await settle(tester);
    expect(picker.calls, [PhotoSource.gallery]);
    expect(find.text('Remove photo'), findsOneWidget);
    await tester.tap(find.text('Continue'));
    await settle(tester);

    // Birthday defaults to Jan 1, 2000.
    expect(find.textContaining('That makes you'), findsOneWidget);
    await tester.tap(find.text('Continue'));
    await settle(tester);

    expect(find.text('Does this look right?'), findsOneWidget);
    expect(find.text('January 1, 2000'), findsOneWidget);
    await tester.tap(find.text('Let’s start signing!'));
    await settle(tester);

    expect(repo.saved?.name, 'Yesh Nin');
    expect(repo.saved?.nickname, 'Yesh');
    expect(repo.saved?.birthdate, DateTime(2000));
    expect(repo.saved?.photoPath, '/tmp/picked.jpg');
    expect(repo.saved?.age, UserProfile.ageOn(DateTime(2000), DateTime.now()));
    expect(find.text('Welcome!'), findsOneWidget);
    expect(find.text('YESH'), findsOneWidget);
    expect(find.text('Foundation'), findsOneWidget);
  });

  group('AvatarStorage', () {
    late Directory root;
    setUp(() => root = Directory.systemTemp.createTempSync('avatar_test'));
    tearDown(() => root.deleteSync(recursive: true));

    test('copies into app storage and cleans up old photos', () async {
      final storage = AvatarStorage(baseDir: () async => root);
      final src = File('${root.path}/picked.png')..writeAsBytesSync([1, 2, 3]);

      final first = await storage.persist(src.path);
      expect(first, isNot(src.path));
      expect(File(first).readAsBytesSync(), [1, 2, 3]);
      expect(await storage.persist(first), first, reason: 'already stored');

      final second = await storage.persist(src.path);
      await storage.deleteAllExcept(second);
      expect(File(first).existsSync(), isFalse);
      expect(File(second).existsSync(), isTrue);

      await storage.deleteAllExcept(null);
      expect(File(second).existsSync(), isFalse);
    });
  });

  UserProfile yesh() => UserProfile(
    id: 1,
    name: 'Yesh Nin',
    nickname: 'Yesh',
    birthdate: DateTime(2000, 2, 29),
    age: 26,
    createdAt: DateTime(2026),
  );

  Future<FakeStudyRepository> launchSignedIn(
    WidgetTester tester, {
    FakeUserRepository? repo,
  }) async {
    final study = FakeStudyRepository();
    tester.view.physicalSize = const Size(1080, 2340);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      EKumpasApp(
        repository: repo ?? FakeUserRepository(yesh()),
        lessons: FakeLessonRepository(),
        study: study,
        photoPicker: FakePhotoPicker(null),
      ),
    );
    await settle(tester);
    return study;
  }

  testWidgets('returning user: lessons, bookmarks, search and tabs', (
    tester,
  ) async {
    final study = await launchSignedIn(tester);

    expect(find.text('Kumusta!'), findsNothing);
    expect(find.text('YESH'), findsOneWidget);

    // Category tile → topics → signs accordion.
    await tester.tap(find.text('Foundation'));
    await settle(tester);
    expect(find.text('Foundational Vocabulary'), findsOneWidget);
    expect(find.text('ALPHABET'), findsOneWidget);
    await tester.tap(find.text('QUESTIONS'));
    await settle(tester);
    expect(find.text('What is your name?'), findsOneWidget);
    expect(
      find.textContaining('YOUR + NAME + WHAT?', findRichText: true),
      findsOneWidget,
    );
    // The first sign opens by itself and counts as studied.
    expect(study.viewed.keys, ['foundation/t/What is your name?']);

    await tester.tap(find.bySemanticsLabel('Bookmark What is your name?'));
    await settle(tester);
    // The sign stays open: the bookmark tap doesn't toggle the accordion.
    expect(
      find.textContaining('YOUR + NAME + WHAT?', findRichText: true),
      findsOneWidget,
    );
    expect(study.bookmarked, ['foundation/t/What is your name?']);
    expect(
      find.bySemanticsLabel('Remove What is your name? from bookmarks'),
      findsOneWidget,
    );

    // Back to home, then the Explore tab via the search bar.
    await tester.tap(find.byIcon(Icons.arrow_back_rounded).last);
    await settle(tester);
    await tester.tap(find.byIcon(Icons.arrow_back_rounded).last);
    await settle(tester);
    await tester.tap(find.text('Search the terminology here…').first);
    await settle(tester);
    expect(find.text('Find any sign, phrase or medical term.'), findsOneWidget);
    // Empty search browses topics.
    expect(find.bySemanticsLabel('Alphabet, 2 signs'), findsWidgets);

    await tester.enterText(find.byType(TextField), 'letter');
    await settle(tester);
    expect(find.text('2 signs'), findsOneWidget);
    expect(find.text('Letter B', findRichText: true), findsOneWidget);

    // A result opens its topic with that sign expanded.
    await tester.tap(find.text('Letter B', findRichText: true));
    await settle(tester);
    expect(find.bySemanticsLabel('Letter B'), findsOneWidget);
    expect(study.viewed.keys, contains('foundation/t/Letter B'));
    await tester.tap(find.byIcon(Icons.arrow_back_rounded).last);
    await settle(tester);

    await tester.enterText(find.byType(TextField), 'zzz');
    await settle(tester);
    expect(find.textContaining('No signs match'), findsOneWidget);

    // Regression: returning to Home must actually show Home again, not leave
    // the previous tab frozen on top of it.
    await tester.tap(find.text('Home'));
    await settle(tester);
    expect(find.textContaining('No signs match'), findsNothing);
    expect(find.text('Welcome!'), findsOneWidget);

    await tester.tap(find.text('Bookmark'));
    await settle(tester);
    expect(find.text('1 saved sign'), findsOneWidget);
    expect(find.text('What is your name?', findRichText: true), findsOneWidget);
    expect(find.text('Welcome!'), findsNothing);

    // Removing it from the list offers an undo.
    await tester.tap(
      find.bySemanticsLabel('Remove What is your name? from bookmarks'),
    );
    await settle(tester);
    expect(study.bookmarked, isEmpty);
    expect(find.text('Nothing saved yet'), findsOneWidget);
    await tester.tap(find.text('Undo'));
    await settle(tester);
    expect(study.bookmarked, ['foundation/t/What is your name?']);
    expect(find.text('1 saved sign'), findsOneWidget);

    await tester.tap(find.text('Home'));
    await settle(tester);
    expect(find.text('1 saved sign'), findsNothing);
    expect(find.text('Welcome!'), findsOneWidget);
  });

  testWidgets('profile shows details and progress, and can be edited', (
    tester,
  ) async {
    final repo = FakeUserRepository(yesh());
    final study = await launchSignedIn(tester, repo: repo);
    await study.markViewed('foundation/t/Letter A');
    await tester.tap(find.text('Profile'));
    await settle(tester);

    expect(find.text('Yesh Nin'), findsOneWidget);
    expect(find.text('${yesh().currentAge} years old'), findsOneWidget);
    expect(find.text('February 29, 2000'), findsOneWidget);
    expect(find.text('Your Progress'), findsOneWidget);
    expect(
      find.text('25%'),
      findsOneWidget,
      reason: '1 of 4 fake signs viewed',
    );
    expect(find.text('Alphabet'), findsOneWidget, reason: 'recent topic');
    expect(find.text('signs reviewed'), findsNothing);
    expect(find.text('sign reviewed'), findsOneWidget);

    await tester.tap(find.bySemanticsLabel('Edit profile'));
    await settle(tester);
    expect(find.text('Edit profile'), findsOneWidget);
    await tester.enterText(find.byType(TextField).at(1), '');
    await settle(tester);
    expect(find.text('Enter a nickname.'), findsOneWidget);
    await tester.enterText(find.byType(TextField).at(1), 'Yeshy');
    await settle(tester);
    await tester.tap(find.text('Save changes'));
    await settle(tester);

    expect(repo.saved?.nickname, 'Yeshy');
    expect(repo.saved?.name, 'Yesh Nin');
    expect(repo.saved?.createdAt, DateTime(2026));
    expect(find.text('Edit profile'), findsNothing);
    await tester.tap(find.text('Home'));
    await settle(tester);
    expect(find.text('YESHY'), findsOneWidget);
  });

  testWidgets('General Quiz 1 runs its ten questions and saves the score', (
    tester,
  ) async {
    final study = await launchSignedIn(tester);
    final quizCard = find.bySemanticsLabel(
      'Quiz: Test, sign and learn. Sign it Right!',
    );
    await tester.drag(
      find.byType(SingleChildScrollView).first,
      const Offset(0, -400),
    );
    await settle(tester);
    await tester.tap(quizCard);
    await settle(tester);
    expect(find.text('SIGN IT RIGHT'), findsOneWidget);
    expect(find.text('General Quiz'), findsOneWidget);
    // Every quiz has its recordings now, Hypertension Quiz 1 included.
    await tester.scrollUntilVisible(find.text('Hypertension Quiz'), 300);
    expect(find.textContaining('Videos coming soon'), findsNothing);
    await tester.drag(find.byType(ListView), const Offset(0, 3000));
    await settle(tester);

    await tester.tap(find.text('Foundational Vocabulary'));
    await settle(tester);
    expect(find.text('General Quiz 1'), findsOneWidget);

    const total = 10;
    for (var i = 0; i < total; i++) {
      expect(
        find.bySemanticsLabel('Question ${i + 1} of $total'),
        findsOneWidget,
      );
      final next = find.text(i == total - 1 ? 'FINISH' : 'NEXT');
      // Next does nothing until the question is answered.
      await tester.tap(next);
      await settle(tester);
      expect(
        find.bySemanticsLabel('Question ${i + 1} of $total'),
        findsOneWidget,
      );

      final optionA = find.bySemanticsLabel(RegExp(r'^A: '));
      await tester.ensureVisible(optionA);
      await tester.tap(optionA);
      await settle(tester);
      expect(
        find.textContaining(
          RegExp(r'^(Correct!|Not quite\.)'),
          findRichText: true,
        ),
        findsOneWidget,
      );
      await tester.tap(next);
      await settle(tester);
    }

    expect(study.quizzes, hasLength(1));
    final (score, outOf, quizId) = study.quizzes.single;
    expect((outOf, quizId), (total, 'general_1'));
    expect(find.text('$score/$total'), findsOneWidget);
    // Every question is reviewed, then the replay button.
    await tester.scrollUntilVisible(find.text('Play again'), 300);
    expect(find.text('$total'), findsOneWidget);

    // Back on the list, the quiz shows its best score.
    await tester.scrollUntilVisible(find.text('Back to quizzes'), 300);
    await tester.tap(find.text('Back to quizzes'));
    await settle(tester);
    expect(find.text('Best score $score/$total'), findsOneWidget);

    // Every step landed in the activity log.
    final actions = study.log.map((e) => e.action).toList();
    expect(actions.first, 'App opened');
    expect(actions, containsAllInOrder(['Opened Quiz list', 'Opened Quiz']));
    expect(
      study.log.firstWhere((e) => e.action == 'Opened Quiz').detail,
      'General Quiz 1: Foundational Vocabulary',
    );
    expect(
      actions.where((a) => a == 'Answered quiz question'),
      hasLength(total),
    );
    expect(
      study.log.lastWhere((e) => e.action == 'Finished quiz').detail,
      'General Quiz 1: $score/$total',
    );
  });

  testWidgets('the activity log opens from the Profile tab', (tester) async {
    final study = await launchSignedIn(tester);
    await tester.tap(find.text('Profile'));
    await settle(tester);
    expect(study.log.last.action, 'Switched tab');
    expect(study.log.last.detail, 'Profile');

    final card = find.bySemanticsLabel('Open activity log');
    await tester.scrollUntilVisible(card, 300);
    await tester.tap(card);
    await settle(tester);
    expect(find.text('Activity log'), findsOneWidget);
    expect(find.text('Today'), findsOneWidget);
    expect(find.text('App opened'), findsOneWidget);
    expect(find.text('Switched tab'), findsOneWidget);
    expect(find.text('Opened Activity log'), findsOneWidget);

    await tester.tap(find.byTooltip('Clear log'));
    await settle(tester);
    await tester.tap(find.text('Clear'));
    await settle(tester);
    expect(study.log, isEmpty);
    expect(find.textContaining('Nothing logged yet'), findsOneWidget);
  });
}
