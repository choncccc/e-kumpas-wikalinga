import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'real_content.dart';

/// The bundled quizzes.json, checked against the client's quiz document.
void main() {
  final sets = realQuizzes();

  test('two sets of five: General 10 items, Hypertension 15', () {
    expect(sets.map((s) => s.id), ['general', 'hypertension']);
    for (final (set, count) in [(sets[0], 10), (sets[1], 15)]) {
      expect(set.quizzes, hasLength(5), reason: set.id);
      for (final q in set.quizzes) {
        expect(q.items, hasLength(count), reason: q.id);
      }
    }
  });

  test('every question has four options and a valid answer', () {
    for (final s in sets) {
      for (final q in s.quizzes) {
        for (final item in q.items) {
          expect(item.options, hasLength(4), reason: q.id);
          expect(item.options.toSet(), hasLength(4), reason: q.id);
          expect(item.answer, inInclusiveRange(0, 3), reason: q.id);
        }
      }
    }
  });

  test('every clip is bundled; only Hypertension Quiz 1 awaits videos', () {
    for (final s in sets) {
      for (final q in s.quizzes) {
        for (final item in q.items.where((i) => i.media != null)) {
          expect(File(item.media!).existsSync(), isTrue, reason: item.media);
        }
        expect(q.isReady, q.id != 'hypertension_1', reason: q.id);
      }
    }
    expect(sets[1].quizzes.first.missingMedia, 6);
  });

  test('a few answers match the answer key', () {
    String answer(int set, int quiz, int item) {
      final i = sets[set].quizzes[quiz - 1].items[item - 1];
      return i.options[i.answer];
    }

    expect(answer(0, 1, 5), 'Green / Berde');
    expect(answer(0, 4, 10), 'Hospitalized / Naospital');
    expect(answer(1, 2, 11), 'Blurry vision / Malabong paningin');
    expect(answer(1, 5, 15), startsWith('Do not stop taking your medicine'));
  });
}
