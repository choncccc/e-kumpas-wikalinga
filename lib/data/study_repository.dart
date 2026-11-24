import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';

import 'lesson_models.dart';
import 'lesson_repository.dart';

/// The learner's own study data: bookmarks, which signs they've looked at,
/// quiz scores and Memory Card Flip levels. Notifies listeners after every write so open screens
/// (Bookmarks, Profile) can refresh.
abstract class StudyRepository extends ChangeNotifier {
  Future<Set<String>> bookmarkedKeys();

  /// Bookmarked signs, newest first.
  Future<List<SignEntry>> bookmarks();
  Future<void> setBookmarked(String signKey, bool bookmarked);

  /// Records that the learner opened a sign.
  Future<void> markViewed(String signKey);

  /// Viewed and total signs per category id.
  Future<Map<String, CategoryProgress>> progress();
  Future<List<RecentTopic>> recentTopics({int limit = 3});

  /// Distinct signs viewed at or after [since].
  Future<int> signsViewedSince(DateTime since);

  /// Records a finished quiz. [quizId] names which one (e.g. "general_1").
  Future<void> saveQuizResult(int score, int total, {String? quizId});
  Future<QuizStats?> quizStats();

  /// Best score on each quiz, by quiz id.
  Future<Map<String, QuizScore>> bestQuizScores();

  /// Records a cleared Memory Card Flip level, keeping the fastest time.
  Future<void> saveGameLevel(int level, Duration time);

  /// Best clear time per cleared level (levels start at 1).
  Future<Map<int, Duration>> gameLevels();

  /// Adds a line to the activity log. Doesn't notify listeners: it is written
  /// on nearly every tap and nothing needs to redraw for it.
  Future<void> logActivity(String action, [String? detail]);

  /// The activity log, newest first.
  Future<List<ActivityEntry>> activity({int limit = 2000});
  Future<void> clearActivity();

  /// "Blood Pressure / BP · Vital Signs" for a sign key.
  static String describeSign(String signKey) {
    final parts = signKey.split('/');
    if (parts.length < 3) return signKey;
    return '${parts.sublist(2).join('/')} · ${parts[1]}';
  }
}

class SqliteStudyRepository extends StudyRepository {
  SqliteStudyRepository(this._lessons, {DateTime Function()? clock})
    : _clock = clock ?? DateTime.now;

  final SqliteLessonRepository _lessons;
  final DateTime Function() _clock;

  Future<Database> get _db => _lessons.seededDatabase;

  String _now() => _clock().toIso8601String();

  @override
  Future<Set<String>> bookmarkedKeys() async {
    final db = await _db;
    final rows = await db.query('bookmark', columns: ['sign_key']);
    return {for (final r in rows) r['sign_key'] as String};
  }

  @override
  Future<List<SignEntry>> bookmarks() async {
    final db = await _db;
    // Inner join: a bookmark whose sign was removed from the content is hidden.
    final rows = await db.rawQuery('''
      SELECT s.id, s.sign_key, s.term, s.tagalog, s.media, s.sign_order,
             s.facial_expression, s.topic_id, t.category_id,
             t.title AS topic_title
      FROM bookmark b
      JOIN sign s ON s.sign_key = b.sign_key
      JOIN lesson_topic t ON t.id = s.topic_id
      ORDER BY b.created_at DESC, s.id
    ''');
    return rows.map(SignEntry.fromRow).toList();
  }

  @override
  Future<void> setBookmarked(String signKey, bool bookmarked) async {
    logActivity(
      bookmarked ? 'Bookmarked sign' : 'Removed bookmark',
      StudyRepository.describeSign(signKey),
    );
    final db = await _db;
    if (bookmarked) {
      await db.insert('bookmark', {
        'sign_key': signKey,
        'created_at': _now(),
      }, conflictAlgorithm: ConflictAlgorithm.ignore);
    } else {
      await db.delete('bookmark', where: 'sign_key = ?', whereArgs: [signKey]);
    }
    notifyListeners();
  }

  @override
  Future<void> markViewed(String signKey) async {
    logActivity('Viewed sign', StudyRepository.describeSign(signKey));
    final db = await _db;
    final now = _now();
    // Insert-or-ignore then update, not an UPSERT: older Android SQLite
    // versions (before 3.24) don't support ON CONFLICT DO UPDATE.
    await db.transaction((txn) async {
      await txn.insert('sign_view', {
        'sign_key': signKey,
        'first_viewed_at': now,
        'last_viewed_at': now,
      }, conflictAlgorithm: ConflictAlgorithm.ignore);
      await txn.update(
        'sign_view',
        {'last_viewed_at': now},
        where: 'sign_key = ?',
        whereArgs: [signKey],
      );
    });
    notifyListeners();
  }

  @override
  Future<Map<String, CategoryProgress>> progress() async {
    final db = await _db;
    final rows = await db.rawQuery('''
      SELECT t.category_id AS category_id,
             COUNT(*) AS total,
             COUNT(v.sign_key) AS viewed
      FROM sign s
      JOIN lesson_topic t ON t.id = s.topic_id
      LEFT JOIN sign_view v ON v.sign_key = s.sign_key
      GROUP BY t.category_id
    ''');
    return {
      for (final r in rows)
        r['category_id'] as String: CategoryProgress(
          viewed: r['viewed'] as int,
          total: r['total'] as int,
        ),
    };
  }

  @override
  Future<List<RecentTopic>> recentTopics({int limit = 3}) async {
    final db = await _db;
    final rows = await db.rawQuery(
      '''
      SELECT t.id AS topic_id, t.title AS topic_title, t.category_id,
             MAX(v.last_viewed_at) AS last_viewed
      FROM sign_view v
      JOIN sign s ON s.sign_key = v.sign_key
      JOIN lesson_topic t ON t.id = s.topic_id
      GROUP BY t.id
      ORDER BY last_viewed DESC
      LIMIT ?
      ''',
      [limit],
    );
    return [
      for (final r in rows)
        RecentTopic(
          categoryId: r['category_id'] as String,
          topicId: r['topic_id'] as int,
          topicTitle: r['topic_title'] as String,
          lastViewed: DateTime.parse(r['last_viewed'] as String),
        ),
    ];
  }

  @override
  Future<int> signsViewedSince(DateTime since) async {
    final db = await _db;
    final rows = await db.rawQuery(
      'SELECT COUNT(*) AS n FROM sign_view WHERE last_viewed_at >= ?',
      [since.toIso8601String()],
    );
    return rows.first['n'] as int;
  }

  @override
  Future<void> saveQuizResult(int score, int total, {String? quizId}) async {
    final db = await _db;
    await db.insert('quiz_result', {
      'taken_at': _now(),
      'score': score,
      'total': total,
      'quiz_id': quizId,
    });
    notifyListeners();
  }

  @override
  Future<Map<String, QuizScore>> bestQuizScores() async {
    final db = await _db;
    final rows = await db.rawQuery(
      'SELECT quiz_id, score, total FROM quiz_result '
      'WHERE quiz_id IS NOT NULL '
      'ORDER BY CAST(score AS REAL) / total ASC',
    );
    // Ascending, so each quiz's best row is the one written last.
    return {
      for (final r in rows)
        r['quiz_id'] as String: QuizScore(r['score'] as int, r['total'] as int),
    };
  }

  @override
  Future<QuizStats?> quizStats() async {
    final db = await _db;
    final count =
        (await db.rawQuery('SELECT COUNT(*) AS n FROM quiz_result')).first['n']
            as int;
    if (count == 0) return null;
    // Best by percentage, so a different quiz length still compares fairly.
    final best = (await db.rawQuery(
      'SELECT score, total FROM quiz_result '
      'ORDER BY CAST(score AS REAL) / total DESC, taken_at DESC LIMIT 1',
    )).first;
    final last = (await db.rawQuery(
      'SELECT score, total FROM quiz_result ORDER BY id DESC LIMIT 1',
    )).first;
    return QuizStats(
      taken: count,
      bestScore: best['score'] as int,
      bestTotal: best['total'] as int,
      lastScore: last['score'] as int,
      lastTotal: last['total'] as int,
    );
  }

  @override
  Future<void> saveGameLevel(int level, Duration time) async {
    final secs = (time.inSeconds % 60).toString().padLeft(2, '0');
    logActivity(
      'Cleared memory game level',
      'Level $level in ${time.inMinutes}:$secs',
    );
    final db = await _db;
    final seconds = time.inSeconds;
    // Insert-or-ignore then keep the faster time (no UPSERT on old SQLite).
    await db.transaction((txn) async {
      await txn.insert('game_level', {
        'level': level,
        'best_seconds': seconds,
        'cleared_at': _now(),
      }, conflictAlgorithm: ConflictAlgorithm.ignore);
      await txn.rawUpdate(
        'UPDATE game_level SET best_seconds = ?, cleared_at = ? '
        'WHERE level = ? AND best_seconds > ?',
        [seconds, _now(), level, seconds],
      );
    });
    notifyListeners();
  }

  @override
  Future<Map<int, Duration>> gameLevels() async {
    final db = await _db;
    final rows = await db.query('game_level', orderBy: 'level');
    return {
      for (final r in rows)
        r['level'] as int: Duration(seconds: r['best_seconds'] as int),
    };
  }

  /// Oldest rows are dropped past this many, so the log can't grow forever.
  static const activityLimit = 10000;

  @override
  Future<void> logActivity(String action, [String? detail]) async {
    try {
      final db = await _db;
      await db.insert('activity_log', {
        'at': _now(),
        'action': action,
        'detail': detail,
      });
      if (action == 'App opened') {
        await db.rawDelete(
          'DELETE FROM activity_log WHERE id <= '
          '(SELECT MAX(id) FROM activity_log) - ?',
          [activityLimit],
        );
      }
    } catch (e) {
      // Callers don't wait on this; a failed log line must never break a tap.
      debugPrint('Activity log write failed: $e');
    }
  }

  @override
  Future<List<ActivityEntry>> activity({int limit = 2000}) async {
    final db = await _db;
    final rows = await db.query(
      'activity_log',
      orderBy: 'id DESC',
      limit: limit,
    );
    return [
      for (final r in rows)
        ActivityEntry(
          at: DateTime.parse(r['at'] as String),
          action: r['action'] as String,
          detail: r['detail'] as String?,
        ),
    ];
  }

  @override
  Future<void> clearActivity() async {
    final db = await _db;
    await db.delete('activity_log');
    notifyListeners();
  }
}
