import 'dart:io';
import 'dart:math';

import 'package:ekumpas_wikalinga/data/lesson_models.dart';
import 'package:ekumpas_wikalinga/data/user_profile.dart';
import 'package:ekumpas_wikalinga/features/game/memory_game.dart';
import 'package:ekumpas_wikalinga/features/game/memory_game_screen.dart';
import 'package:ekumpas_wikalinga/features/game/memory_levels.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fakes.dart';
import 'quiz_builder_test.dart' show realSigns;

/// Two-pair level for rules tests.
MemoryLevel _level(int pairs) => MemoryLevel(
  number: 1,
  title: 'Test',
  pairs: [
    for (var i = 0; i < pairs; i++)
      MemoryPair(
        sign: Sign(id: i, key: 'k$i', term: 'T$i', media: 'm$i.jpg'),
        label: 'T$i',
      ),
  ],
);

/// Indices of the two cards of [pair] in [game].
(int, int) _cardsOf(MemoryGame game, int pair) {
  final idx = [
    for (var i = 0; i < game.cards.length; i++)
      if (game.cards[i].pair == pair) i,
  ];
  return (idx[0], idx[1]);
}

/// A lesson repository whose signs have real bundled stills, for the screen.
class _MediaLessons extends FakeLessonRepository {
  @override
  Future<List<SignEntry>> allSigns() async => [
    for (final (i, l) in ['A', 'B', 'C'].indexed)
      SignEntry(
        sign: Sign(
          id: i,
          key: Sign.keyFor('foundation', 'Alphabet', 'Letter $l'),
          term: 'Letter $l',
          media:
              'assets/signs/foundation/alphabet__letter_${l.toLowerCase()}.jpg',
        ),
        categoryId: 'foundation',
        topicId: 1,
        topicTitle: 'Alphabet',
      ),
  ];
}

const _twoLevels = [
  (
    'Letters',
    [
      MemoryItem('foundation', 'Alphabet', 'Letter A'),
      MemoryItem('foundation', 'Alphabet', 'Letter B'),
    ],
  ),
  (
    'More letters',
    [
      MemoryItem('foundation', 'Alphabet', 'Letter B'),
      MemoryItem('foundation', 'Alphabet', 'Letter C'),
    ],
  ),
];

void main() {
  test('all six levels resolve to ten recorded pairs from the PDF', () {
    final levels = resolveMemoryLevels(realSigns());
    expect(levels, hasLength(6));
    for (final l in levels) {
      expect(l.pairs, hasLength(10), reason: l.title);
      expect(
        l.pairs.map((p) => p.label).toSet(),
        hasLength(10),
        reason: 'no two green cards say the same thing',
      );
      for (final p in l.pairs) {
        expect(File(p.sign.media!).existsSync(), isTrue, reason: p.label);
        expect(File(p.sign.poster!).existsSync(), isTrue, reason: p.label);
      }
    }
    // Every spec entry matched a real sign (none silently dropped).
    for (final (title, items) in memoryLevelSpecs) {
      expect(items, hasLength(10), reason: title);
    }
  });

  test('every clip has a poster frame next to it', () {
    for (final e in realSigns()) {
      if (e.sign.hasVideo) {
        expect(File(e.sign.poster!).existsSync(), isTrue, reason: e.sign.key);
      }
    }
  });

  group('MemoryGame', () {
    test('deals one sign and one meaning card per pair', () {
      final game = MemoryGame(_level(10), random: Random(1));
      expect(game.cards, hasLength(20));
      for (var p = 0; p < 10; p++) {
        final cards = game.cards.where((c) => c.pair == p);
        expect(cards.map((c) => c.isSign).toSet(), {true, false});
      }
    });

    test('a matching pair stays up', () {
      final game = MemoryGame(_level(2), random: Random(2));
      final (a, b) = _cardsOf(game, 0);
      expect(game.flip(a), FlipResult.flipped);
      expect(game.flip(a), FlipResult.ignored, reason: 'already up');
      expect(game.flip(b), FlipResult.matched);
      expect(game.isMatched(a) && game.isMatched(b), isTrue);
      expect(game.faceUp, isEmpty);
      expect(game.found, [0]);
      expect(game.flip(a), FlipResult.ignored, reason: 'already matched');
      expect(game.tries, 1);
    });

    test('a mismatch shows until hidden or the next flip', () {
      final game = MemoryGame(_level(3), random: Random(3));
      final (a0, _) = _cardsOf(game, 0);
      final (a1, b1) = _cardsOf(game, 1);
      final (a2, _) = _cardsOf(game, 2);

      expect(game.flip(a0), FlipResult.flipped);
      expect(game.flip(a1), FlipResult.mismatched);
      expect(game.hasMismatch, isTrue);
      expect(game.isFaceUp(a0) && game.isFaceUp(a1), isTrue);

      game.hideMismatch();
      expect(game.faceUp, isEmpty);

      game.flip(a0);
      game.flip(a2);
      // Flipping a third card puts the mismatch away and starts a new try.
      expect(game.flip(b1), FlipResult.flipped);
      expect(game.faceUp, [b1]);
      expect(game.flip(a1), FlipResult.matched);
      expect(game.tries, 3);
    });

    test('completes when every pair is found', () {
      final game = MemoryGame(_level(2), random: Random(4));
      for (var p = 0; p < 2; p++) {
        final (a, b) = _cardsOf(game, p);
        game.flip(a);
        game.flip(b);
      }
      expect(game.isComplete, isTrue);
      expect(game.flip(0), FlipResult.ignored);
    });
  });

  testWidgets('clearing a level saves the time and unlocks the next', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.75;
    addTearDown(tester.view.reset);

    final study = FakeStudyRepository();
    const seed = 9;
    await tester.pumpWidget(
      MaterialApp(
        home: MemoryGameScreen(
          profile: UserProfile(
            name: 'Test User',
            nickname: 'Tess',
            birthdate: DateTime(2000, 1, 1),
            age: 24,
            createdAt: DateTime(2024),
          ),
          lessons: _MediaLessons(),
          study: study,
          random: Random(seed),
          levelSpecs: _twoLevels,
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Level I'), findsOneWidget);
    expect(find.text('Tap a card to start the clock'), findsOneWidget);
    expect(find.text('Time Remaining: 2:00'), findsOneWidget);

    // The same seed deals the same board, so the test knows where pairs are.
    final levels = resolveMemoryLevels(
      await _MediaLessons().allSigns(),
      specs: _twoLevels,
    );
    final deal = MemoryGame(levels.first, random: Random(seed));
    Future<void> tap(int i) async {
      await tester.tap(find.byKey(ValueKey('memory-card-$i')));
      await tester.pump(const Duration(milliseconds: 500));
    }

    // A wrong pair turns back on its own.
    final (a0, b0) = _cardsOf(deal, 0);
    final (a1, b1) = _cardsOf(deal, 1);
    final wrong = deal.cards[a0].isSign == deal.cards[a1].isSign ? b1 : a1;
    await tap(a0);
    await tap(wrong);
    expect(find.textContaining('FOUND MATCHES  0/2'), findsOneWidget);
    await tester.pump(const Duration(seconds: 2));

    await tap(a0);
    await tap(b0);
    expect(find.textContaining('FOUND MATCHES  1/2'), findsOneWidget);
    await tap(a1);
    await tap(b1);
    await tester.pumpAndSettle();

    expect(find.text('Level I cleared!'), findsOneWidget);
    expect(study.levels.keys, [1]);
    expect(study.levels[1]!.inSeconds, lessThanOrEqualTo(5));

    await tester.tap(find.textContaining('Next: Level II'));
    await tester.pumpAndSettle();
    expect(find.text('Level II'), findsOneWidget);
    expect(find.text('Time Remaining: 2:00'), findsOneWidget);
  });

  testWidgets('long-press shows a face-up sign card large', (tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.75;
    addTearDown(tester.view.reset);

    const seed = 4;
    await tester.pumpWidget(
      MaterialApp(
        home: MemoryGameScreen(
          profile: UserProfile(
            name: 'Test User',
            nickname: 'Tess',
            birthdate: DateTime(2000, 1, 1),
            age: 24,
            createdAt: DateTime(2024),
          ),
          lessons: _MediaLessons(),
          study: FakeStudyRepository(),
          random: Random(seed),
          levelSpecs: _twoLevels,
        ),
      ),
    );
    await tester.pumpAndSettle();
    final levels = resolveMemoryLevels(
      await _MediaLessons().allSigns(),
      specs: _twoLevels,
    );
    final deal = MemoryGame(levels.first, random: Random(seed));
    final (a, b) = _cardsOf(deal, 0);
    final sign = deal.cards[a].isSign ? a : b;
    final meaning = sign == a ? b : a;
    Finder card(int i) => find.byKey(ValueKey('memory-card-$i'));

    // Face down: a long press does nothing special.
    await tester.longPress(card(sign));
    await tester.pumpAndSettle();
    expect(find.byType(Dialog), findsNothing);

    await tester.tap(card(sign));
    await tester.pumpAndSettle();
    await tester.longPress(card(sign));
    await tester.pumpAndSettle();
    expect(find.text('Which green card means this?'), findsOneWidget);
    await tester.tap(find.text('Close'));
    await tester.pumpAndSettle();

    await tester.tap(card(meaning));
    await tester.pumpAndSettle();
    await tester.longPress(card(sign));
    await tester.pumpAndSettle();
    expect(
      find.text('Letter A'),
      findsWidgets,
      reason: 'revealed once matched',
    );
    expect(find.text('Which green card means this?'), findsNothing);
  });

  testWidgets('running out of time ends the level', (tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.75;
    addTearDown(tester.view.reset);

    final study = FakeStudyRepository();
    await tester.pumpWidget(
      MaterialApp(
        home: MemoryGameScreen(
          profile: UserProfile(
            name: 'Test User',
            nickname: 'Tess',
            birthdate: DateTime(2000, 1, 1),
            age: 24,
            createdAt: DateTime(2024),
          ),
          lessons: _MediaLessons(),
          study: study,
          random: Random(1),
          levelSpecs: _twoLevels,
          timeLimit: const Duration(seconds: 3),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('memory-card-0')));
    await tester.pump(const Duration(seconds: 4));
    await tester.pumpAndSettle();
    expect(find.text('Time’s up'), findsOneWidget);
    expect(study.levels, isEmpty);

    await tester.tap(find.text('Try again'));
    await tester.pumpAndSettle();
    expect(find.text('Time Remaining: 0:03'), findsOneWidget);
  });

  test('level specs point at signs that exist in the lessons', () {
    final keys = {for (final e in realSigns()) e.sign.key};
    for (final (title, items) in memoryLevelSpecs) {
      for (final item in items) {
        expect(keys, contains(item.key), reason: '$title: ${item.term}');
      }
    }
  });
}
