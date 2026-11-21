import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;
import 'package:sqflite/sqflite.dart';

import 'app_database.dart';
import 'lesson_models.dart';

abstract class LessonRepository {
  /// Topics of a category in document order, each with its signs.
  Future<List<LessonTopic>> topicsFor(String categoryId);

  /// One topic with its signs, or null if it no longer exists.
  Future<LessonTopic?> topic(int topicId);

  /// Signs whose term, Tagalog, sign order or topic contains every word of
  /// [query],
  /// best matches first.
  Future<List<SignEntry>> search(String query, {int limit = 60});

  /// Every sign in document order.
  Future<List<SignEntry>> allSigns();
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
  /// 2: adds sign_key. 3: adds Tagalog and sign media.
  static const contentVersion = '3';

  final AppDatabase _database;
  final Future<String> Function() _loadJson;
  Future<void>? _seeding;

  /// The database, once lesson content is loaded. Other repositories that
  /// join against the sign table go through this.
  Future<Database> get seededDatabase async {
    final db = await _database.database;
    await (_seeding ??= _seedIfNeeded(db));
    return db;
  }

  Future<Database> get _db => seededDatabase;

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
          final topicTitle = topic['title'] as String;
          final topicId = await txn.insert('lesson_topic', {
            'category_id': cat['id'],
            'position': t,
            'title': topic['title'],
            'tagalog': topic['tagalog'],
          });
          final batch = txn.batch();
          final signs = topic['signs'] as List;
          for (var s = 0; s < signs.length; s++) {
            final sign = signs[s] as Map<String, dynamic>;
            batch.insert('sign', {
              'topic_id': topicId,
              'position': s,
              'term': sign['term'],
              'tagalog': sign['tagalog'],
              'media': sign['media'],
              'sign_order': sign['sign_order'],
              'facial_expression': sign['facial_expression'],
              'sign_key': Sign.keyFor(
                cat['id'] as String,
                topicTitle,
                sign['term'] as String,
              ),
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
          tagalog: t['tagalog'] as String?,
          signs: byTopic[t['id'] as int] ?? const [],
        ),
    ];
  }

  @override
  Future<LessonTopic?> topic(int topicId) async {
    final db = await _db;
    final rows = await db.query(
      'lesson_topic',
      where: 'id = ?',
      whereArgs: [topicId],
    );
    if (rows.isEmpty) return null;
    final signs = await db.query(
      'sign',
      where: 'topic_id = ?',
      whereArgs: [topicId],
      orderBy: 'position',
    );
    return LessonTopic(
      id: topicId,
      title: rows.first['title'] as String,
      tagalog: rows.first['tagalog'] as String?,
      signs: signs.map(Sign.fromRow).toList(),
    );
  }

  static const _entryColumns = '''
    s.id, s.sign_key, s.term, s.tagalog, s.media, s.sign_order,
    s.facial_expression,
    s.topic_id, t.category_id, t.title AS topic_title
  ''';

  static const _entryFrom = '''
    FROM sign s
    JOIN lesson_topic t ON t.id = s.topic_id
    JOIN lesson_category c ON c.id = t.category_id
  ''';

  @override
  Future<List<SignEntry>> search(String query, {int limit = 60}) async {
    final words = query
        .trim()
        .toLowerCase()
        .split(RegExp(r'\s+'))
        .where((w) => w.isNotEmpty)
        .toList();
    if (words.isEmpty) return const [];

    final where = <String>[];
    final args = <Object>[];
    for (final w in words) {
      final like = '%${_escapeLike(w)}%';
      where.add(
        r"(s.term LIKE ? ESCAPE '\' OR s.tagalog LIKE ? ESCAPE '\' "
        r"OR s.sign_order LIKE ? ESCAPE '\' OR t.title LIKE ? ESCAPE '\' "
        r"OR t.tagalog LIKE ? ESCAPE '\')",
      );
      args.addAll([like, like, like, like, like]);
    }
    final phrase = _escapeLike(words.join(' '));
    final db = await _db;
    // Rank by how well the English term or its Tagalog matches the phrase:
    // exact, then prefix, then anywhere, then matches elsewhere.
    final rows = await db.rawQuery(
      '''
      SELECT $_entryColumns $_entryFrom
      WHERE ${where.join(' AND ')}
      ORDER BY
        CASE
          WHEN s.term LIKE ? ESCAPE '\\' OR s.tagalog LIKE ? ESCAPE '\\'
            THEN 0
          WHEN s.term LIKE ? ESCAPE '\\' OR s.tagalog LIKE ? ESCAPE '\\'
            THEN 1
          WHEN s.term LIKE ? ESCAPE '\\' OR s.tagalog LIKE ? ESCAPE '\\'
            THEN 2
          ELSE 3
        END,
        length(s.term), c.position, t.position, s.position
      LIMIT ?
      ''',
      [
        ...args,
        for (final p in [phrase, '$phrase%', '%$phrase%']) ...[p, p],
        limit,
      ],
    );
    return rows.map(SignEntry.fromRow).toList();
  }

  @override
  Future<List<SignEntry>> allSigns() async {
    final db = await _db;
    final rows = await db.rawQuery(
      'SELECT $_entryColumns $_entryFrom '
      'ORDER BY c.position, t.position, s.position',
    );
    return rows.map(SignEntry.fromRow).toList();
  }

  static String _escapeLike(String s) =>
      s.replaceAllMapped(RegExp(r'[\\%_]'), (m) => '\\${m[0]}');
}
