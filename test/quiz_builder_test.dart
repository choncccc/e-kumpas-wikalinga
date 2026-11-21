import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:ekumpas_wikalinga/data/lesson_models.dart';
import 'package:ekumpas_wikalinga/features/quiz/quiz_builder.dart';
import 'package:flutter_test/flutter_test.dart';

/// Every sign in the bundled lessons.json, without going through SQLite.
List<SignEntry> realSigns() {
  final data =
      jsonDecode(File('assets/content/lessons.json').readAsStringSync())
          as Map<String, dynamic>;
  var id = 0;
  return [
    for (final c in data['categories'] as List)
      for (final t in c['topics'] as List)
        for (final s in t['signs'] as List)
          SignEntry(
            sign: Sign(
              id: ++id,
              key: Sign.keyFor(c['id'], t['title'], s['term']),
              term: s['term'],
              tagalog: s['tagalog'],
              signOrder: s['sign_order'],
              facialExpression: s['facial_expression'],
              media: s['media'],
            ),
            categoryId: c['id'],
            topicId: 0,
            topicTitle: t['title'],
          ),
  ];
}

void main() {
  final signs = realSigns();

  test('builds ten well-formed, mixed questions from the real content', () {
    for (var seed = 0; seed < 50; seed++) {
      final quiz = QuizBuilder(signs, random: Random(seed)).build();
      expect(quiz, hasLength(10));
      final kinds = quiz.map((q) => q.kind).toList();
      expect(kinds.where((k) => k == QuestionKind.watchSign), hasLength(4));
      expect(kinds.where((k) => k == QuestionKind.signOrder), hasLength(2));
      expect(
        kinds.where((k) => k == QuestionKind.facialExpression),
        hasLength(2),
      );
      expect(kinds.where((k) => k == QuestionKind.grammar), hasLength(2));

      for (final q in quiz) {
        expect(q.options.length, inInclusiveRange(3, 4), reason: q.prompt);
        expect(
          q.options.toSet(),
          hasLength(q.options.length),
          reason: 'no duplicate options',
        );
        expect(q.correct, inInclusiveRange(0, q.options.length - 1));
      }
      expect(
        quiz.map((q) => q.about ?? q.prompt).toSet(),
        hasLength(10),
        reason: 'never two questions about the same phrase',
      );
    }
  });

  test(
    'sign order answers match the content and distractors reuse its signs',
    () {
      final bySubject = {for (final e in signs) e.sign.term: e.sign};
      final quiz = QuizBuilder(signs, random: Random(7)).build(count: 40);
      for (final q in quiz.where((q) => q.kind == QuestionKind.signOrder)) {
        final answer = q.options[q.correct];
        expect(answer, bySubject[q.subject]!.signOrder);
        List<String> sorted(String o) =>
            (o.replaceAll('?', '').split(' + ')..sort());
        for (final o in q.options) {
          expect(
            sorted(o),
            sorted(answer),
            reason: 'same signs, different order',
          );
        }
      }
    },
  );

  test('facial expression answers follow the content', () {
    final quiz = QuizBuilder(signs, random: Random(3)).build(count: 40);
    final faces = quiz.where((q) => q.kind == QuestionKind.facialExpression);
    expect(faces, isNotEmpty);
    final bySubject = {for (final e in signs) e.sign.term: e.sign};
    for (final q in faces) {
      final expr = bySubject[q.subject]!.facialExpression!.toLowerCase();
      expect(
        q.options[q.correct],
        expr.contains('wh') ? QuizBuilder.furrow : QuizBuilder.raise,
      );
    }
  });

  test('watch questions show a real clip and offer look-alike terms', () {
    final byTerm = {for (final e in signs) e.sign.term: e};
    final quiz = QuizBuilder(signs, random: Random(5)).build(count: 40);
    final watch = quiz.where((q) => q.kind == QuestionKind.watchSign);
    expect(watch, isNotEmpty);
    for (final q in watch) {
      final answer = byTerm[q.options[q.correct]]!;
      expect(q.media, answer.sign.media);
      expect(File(q.media!).existsSync(), isTrue, reason: q.media);
      expect(q.subject, isNull, reason: 'the answer must not be shown');
      expect(q.options, hasLength(4));
      for (final o in q.options) {
        expect(
          byTerm[o]!.topicTitle,
          answer.topicTitle,
          reason: 'distractors come from the same topic',
        );
      }
    }
  });

  test('every bundled media path exists and is listed in pubspec', () {
    final pubspec = File('pubspec.yaml').readAsStringSync();
    final withMedia = signs.where((e) => e.sign.media != null).toList();
    expect(withMedia.length, greaterThan(250));
    for (final e in withMedia) {
      final path = e.sign.media!;
      expect(File(path).existsSync(), isTrue, reason: path);
      final dir = path.substring(0, path.lastIndexOf('/') + 1);
      expect(pubspec, contains('- $dir'), reason: dir);
    }
  });

  test('tops up from other pools when content is thin', () {
    // Text-only content: no media, so no watch questions.
    final textOnly = [
      for (final e in signs.take(30))
        SignEntry(
          sign: Sign(id: e.sign.id, key: e.sign.key, term: e.sign.term),
          categoryId: e.categoryId,
          topicId: e.topicId,
          topicTitle: e.topicTitle,
        ),
    ];
    final quiz = QuizBuilder(textOnly, random: Random(1)).build();
    // The first 30 signs (alphabet, numbers) have no order or face data.
    expect(quiz, hasLength(6), reason: 'only the six grammar questions exist');
    expect(quiz.every((q) => q.kind == QuestionKind.grammar), isTrue);
  });
}
