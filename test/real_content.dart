import 'dart:convert';
import 'dart:io';

import 'package:ekumpas_wikalinga/data/lesson_models.dart';
import 'package:ekumpas_wikalinga/data/quiz_content.dart';

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

/// The bundled quizzes.json.
List<QuizSet> realQuizzes() => AssetQuizRepository.parse(
  File(AssetQuizRepository.asset).readAsStringSync(),
);

/// Bundled quizzes as an in-memory repository.
class FileQuizRepository implements QuizRepository {
  @override
  Future<List<QuizSet>> sets() async => realQuizzes();
}
