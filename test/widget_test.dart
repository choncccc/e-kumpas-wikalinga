import 'dart:io';

import 'package:ekumpas_wikalinga/data/avatar_storage.dart';
import 'package:ekumpas_wikalinga/data/lesson_models.dart';
import 'package:ekumpas_wikalinga/data/lesson_repository.dart';
import 'package:ekumpas_wikalinga/data/photo_picker.dart';
import 'package:ekumpas_wikalinga/data/user_profile.dart';
import 'package:ekumpas_wikalinga/data/user_repository.dart';
import 'package:ekumpas_wikalinga/features/onboarding/onboarding_draft.dart';
import 'package:ekumpas_wikalinga/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

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

class FakeLessonRepository implements LessonRepository {
  @override
  Future<List<LessonTopic>> topicsFor(String categoryId) async => const [
        LessonTopic(id: 1, title: 'Alphabet', signs: [
          Sign(id: 1, term: 'Letter A'),
          Sign(id: 2, term: 'Letter B'),
        ]),
        LessonTopic(id: 2, title: 'Questions', signs: [
          Sign(
            id: 3,
            term: 'What is your name?',
            signOrder: 'YOUR + NAME + WHAT?',
            facialExpression: 'WH question: furrow eyebrows',
          ),
        ]),
      ];
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
    OnboardingDraft draft() => OnboardingDraft(clock: () => DateTime(2026, 11, 14));

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

  testWidgets('full sign-up flow saves the profile and lands on home', (tester) async {
    final repo = FakeUserRepository();
    final picker = FakePhotoPicker('/tmp/picked.jpg');
    // A typical phone screen (360x780), not the 800x600 test default.
    tester.view.physicalSize = const Size(1080, 2340);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(EKumpasApp(repository: repo, lessons: FakeLessonRepository(), photoPicker: picker));
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

  testWidgets('returning user skips onboarding', (tester) async {
    final repo = FakeUserRepository(UserProfile(
      id: 1,
      name: 'Yesh Nin',
      nickname: 'Yesh',
      birthdate: DateTime(2000, 2, 29),
      age: 26,
      createdAt: DateTime(2026),
    ));
    final picker = FakePhotoPicker(null);
    tester.view.physicalSize = const Size(1080, 2340);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(EKumpasApp(repository: repo, lessons: FakeLessonRepository(), photoPicker: picker));
    await settle(tester);

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
    expect(find.textContaining('YOUR + NAME + WHAT?', findRichText: true), findsOneWidget);

    // Back to home, then the Explore tab via the search bar.
    await tester.tap(find.byIcon(Icons.arrow_back_rounded).last);
    await settle(tester);
    await tester.tap(find.byIcon(Icons.arrow_back_rounded).last);
    await settle(tester);
    await tester.tap(find.text('Search the terminology here…'));
    await settle(tester);
    expect(find.textContaining('Search every sign'), findsOneWidget);

    // Regression: returning to Home must actually show Home again, not leave
    // the previous tab frozen on top of it.
    await tester.tap(find.text('Home'));
    await settle(tester);
    expect(find.textContaining('Search every sign'), findsNothing);
    expect(find.text('Welcome!'), findsOneWidget);

    await tester.tap(find.text('Bookmark'));
    await settle(tester);
    expect(find.textContaining('Signs you save'), findsOneWidget);
    expect(find.text('Welcome!'), findsNothing);
    await tester.tap(find.text('Home'));
    await settle(tester);
    expect(find.textContaining('Signs you save'), findsNothing);
    expect(find.text('Welcome!'), findsOneWidget);
  });
}
