import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;
import 'package:sqflite/sqflite.dart';

import 'app_database.dart';
import 'lesson_models.dart';

abstract class LessonRepository {
  /// Topics of a category in document order, each with its signs.
  Future<List<LessonTopic>> topicsFor(String categoryId);
}

/// Lessons live in SQLite, seeded from the bundled assets/content/lessons.json
/// (generated from the content PDF by tool/extract_content.py).
class SqliteLessonRepository implements LessonRepository {
  SqliteLessonRepository({
    AppDatabase? database,
    Future<String> Function()? loadJson,
  }) : _database = database ?? AppDatabase.instance,
       _loadJson = loadJson ?? (() => rootBundle.loadString(contentAsset));

  static const contentAsset = 'assets/content/lessons.json';

  /// Bump whenever lessons.json changes so installed apps reseed.
  static const contentVersion = '1';

  final AppDatabase _database;
  final Future<String> Function() _loadJson;
  Future<void>? _seeding;

  Future<Database> get _db async {
    final db = await _database.database;
    await (_seeding ??= _seedIfNeeded(db));
    return db;
  }

  Future<void> _seedIfNeeded(Database db) async {
    final row = await db.query(
      'app_meta',
      where: 'key = ?',
      whereArgs: ['content_version'],
    );
    if (row.isNotEmpty && row.first['value'] == contentVersion) return;

    final data = jsonDecode(await _loadJson()) as Map<String, dynamic>;
    await db.transaction((txn) async {
      await txn.delete('sign');
      await txn.delete('lesson_topic');
      await txn.delete('lesson_category');

      final categories = data['categories'] as List;
      for (var c = 0; c < categories.length; c++) {
        final cat = categories[c] as Map<String, dynamic>;
        await txn.insert('lesson_category', {
          'id': cat['id'],
          'position': c,
          'title': cat['title'],
        });
        final topics = cat['topics'] as List;
        for (var t = 0; t < topics.length; t++) {
          final topic = topics[t] as Map<String, dynamic>;
          final topicId = await txn.insert('lesson_topic', {
            'category_id': cat['id'],
            'position': t,
            'title': topic['title'],
          });
          final batch = txn.batch();
          final signs = topic['signs'] as List;
          for (var s = 0; s < signs.length; s++) {
            final sign = signs[s] as Map<String, dynamic>;
            batch.insert('sign', {
              'topic_id': topicId,
              'position': s,
              'term': sign['term'],
              'sign_order': sign['sign_order'],
              'facial_expression': sign['facial_expression'],
            });
          }
          await batch.commit(noResult: true);
        }
      }
      await txn.insert('app_meta', {
        'key': 'content_version',
        'value': contentVersion,
      }, conflictAlgorithm: ConflictAlgorithm.replace);
    });
  }

  @override
  Future<List<LessonTopic>> topicsFor(String categoryId) async {
    final db = await _db;
    final topics = await db.query(
      'lesson_topic',
      where: 'category_id = ?',
      whereArgs: [categoryId],
      orderBy: 'position',
    );
    if (topics.isEmpty) return const [];

    final ids = topics.map((t) => t['id'] as int).toList();
    final signs = await db.query(
      'sign',
      where: 'topic_id IN (${List.filled(ids.length, '?').join(',')})',
      whereArgs: ids,
      orderBy: 'topic_id, position',
    );
    final byTopic = <int, List<Sign>>{};
    for (final s in signs) {
      (byTopic[s['topic_id'] as int] ??= []).add(Sign.fromRow(s));
    }
    return [
      for (final t in topics)
        LessonTopic(
          id: t['id'] as int,
          title: t['title'] as String,
          signs: byTopic[t['id'] as int] ?? const [],
        ),
    ];
  }
}
