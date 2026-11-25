import 'dart:io';
import 'dart:math';

import 'package:ekumpas_wikalinga/features/quiz/quiz_question.dart';

import 'package:flutter_test/flutter_test.dart';

import 'real_content.dart';

/// The bundled quizzes.json, checked against the client's quiz document.
void main() {
  final sets = realQuizzes();

  test('General: six of 10 items (one per category); Hypertension: five of '
      '15', () {
    expect(sets.map((s) => s.id), ['general', 'hypertension']);
    for (final (set, quizzes, count) in [(sets[0], 6, 10), (sets[1], 5, 15)]) {
      expect(set.quizzes, hasLength(quizzes), reason: set.id);
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

  test('every question has its clip, and it is bundled', () {
    for (final s in sets) {
      for (final q in s.quizzes) {
        expect(q.isReady, isTrue, reason: q.id);
        for (final item in q.items) {
          expect(File(item.media!).existsSync(), isTrue, reason: item.media);
        }
      }
    }
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
    // Revised Hypertension Quiz 1 (Nov 2026).
    expect(answer(1, 1, 3), 'Severe Dizziness / Lubhang pagkahilo');
    expect(answer(1, 1, 12), 'Get enough sleep / Matulog nang sapat');
    expect(sets[0].quizzes.last.title, 'Procedures & Health Advice');
  });

  test('shuffled options keep the right answer, and retakes reorder', () {
    final item = sets[1].quizzes.first.items[2];
    final key = item.options[item.answer];
    final random = Random(7);
    final orders = <String>{};
    for (var i = 0; i < 10; i++) {
      final q = QuizQuestion.fromItem(item, random: random);
      expect(q.options.toSet(), item.options.toSet());
      expect(q.options[q.correct], key);
      orders.add(q.options.join('|'));
    }
    expect(orders.length, greaterThan(1));
    // Without a random source the answer key's order is kept.
    expect(QuizQuestion.fromItem(item).options, item.options);
  });
}
