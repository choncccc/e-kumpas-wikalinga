import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;

/// One multiple-choice question: watch the sign, pick what it means.
class QuizItem {
  const QuizItem({
    required this.options,
    required this.answer,
    required this.media,
  });

  factory QuizItem.fromJson(Map<String, dynamic> j) => QuizItem(
    options: [for (final o in j['options'] as List) o as String],
    answer: j['answer'] as int,
    media: j['media'] as String?,
  );

  /// Shown as A to D, in this order (the order of the client's answer key).
  final List<String> options;

  /// Index into [options].
  final int answer;

  /// Clip or still of the sign, or null while it hasn't been recorded.
  final String? media;
}

/// A fixed quiz, e.g. General Quiz 1: Foundational Vocabulary.
class QuizDef {
  const QuizDef({
    required this.id,
    required this.number,
    required this.title,
    required this.items,
  });

  factory QuizDef.fromJson(Map<String, dynamic> j) => QuizDef(
    id: j['id'] as String,
    number: j['number'] as int,
    title: j['title'] as String?,
    items: [
      for (final i in j['items'] as List)
        QuizItem.fromJson(i as Map<String, dynamic>),
    ],
  );

  /// Stable id ("general_1"), stored with each result.
  final String id;
  final int number;
  final String? title;
  final List<QuizItem> items;

  /// Questions still waiting for their sign recording.
  int get missingMedia => items.where((i) => i.media == null).length;

  /// Playable once every question has its sign.
  bool get isReady => missingMedia == 0;
}

/// General or Hypertension: five quizzes each.
class QuizSet {
  const QuizSet({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.secondsPerItem,
    required this.quizzes,
  });

  factory QuizSet.fromJson(Map<String, dynamic> j) => QuizSet(
    id: j['id'] as String,
    title: j['title'] as String,
    subtitle: j['subtitle'] as String,
    secondsPerItem: j['seconds_per_item'] as int,
    quizzes: [
      for (final q in j['quizzes'] as List)
        QuizDef.fromJson(q as Map<String, dynamic>),
    ],
  );

  final String id;
  final String title;
  final String subtitle;

  /// Time allowed per question; the timer is this times the question count.
  final int secondsPerItem;
  final List<QuizDef> quizzes;

  Duration timeLimitFor(QuizDef quiz) =>
      Duration(seconds: secondsPerItem * quiz.items.length);
}

abstract class QuizRepository {
  Future<List<QuizSet>> sets();
}

/// The quizzes bundled in assets/content/quizzes.json (built by
/// tool/build_quizzes.py).
class AssetQuizRepository implements QuizRepository {
  const AssetQuizRepository();

  static const asset = 'assets/content/quizzes.json';
  static Future<List<QuizSet>>? _cache;

  @override
  Future<List<QuizSet>> sets() => _cache ??= _load().then(
    (v) => v,
    onError: (Object e) {
      _cache = null; // Try again next time rather than caching the failure.
      throw e;
    },
  );

  // Decoded here rather than with loadString, which hands files over 50 KB
  // to a background isolate; this one is small enough to parse in place.
  static Future<List<QuizSet>> _load() async {
    final bytes = await rootBundle.load(asset);
    return parse(
      utf8.decode(
        bytes.buffer.asUint8List(bytes.offsetInBytes, bytes.lengthInBytes),
      ),
    );
  }

  static List<QuizSet> parse(String json) => [
    for (final s in (jsonDecode(json) as Map<String, dynamic>)['sets'] as List)
      QuizSet.fromJson(s as Map<String, dynamic>),
  ];
}
