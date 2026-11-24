import 'dart:io';

import 'package:ekumpas_wikalinga/data/app_database.dart';
import 'package:ekumpas_wikalinga/data/lesson_repository.dart';
import 'package:ekumpas_wikalinga/data/study_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// Real SQLite (desktop driver) against the real bundled lessons.json.
void main() {
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  late Directory dir;
  final opened = <AppDatabase>[];
  setUp(() => dir = Directory.systemTemp.createTempSync('ekumpas_db'));
  tearDown(() async {
    // Windows won't delete a database file that is still open.
    for (final db in opened) {
      await db.close();
    }
    opened.clear();
    dir.deleteSync(recursive: true);
  });

  AppDatabase open(String path) {
    final db = AppDatabase.at(path);
    opened.add(db);
    return db;
  }

  SqliteLessonRepository repoAt(String path, {void Function()? onLoad}) =>
      SqliteLessonRepository(
        database: open(path),
        loadJson: () async {
          onLoad?.call();
          return File(SqliteLessonRepository.contentAsset).readAsString();
        },
      );

  test('seeds every category from lessons.json once', () async {
    final path = '${dir.path}/a.db';
    var loads = 0;
    final repo = repoAt(path, onLoad: () => loads++);

    final foundation = await repo.topicsFor('foundation');
    expect(foundation.map((t) => t.title), [
      'Alphabet',
      'Numbers',
      'Time',
      'Dates',
      'Colors',
    ]);
    expect(foundation.first.signs, hasLength(26));
    expect(foundation.first.signs.first.term, 'Letter A');

    final basic = await repo.topicsFor('basic');
    final name = basic.last.signs.firstWhere(
      (s) => s.term == 'What is your name?',
    );
    expect(name.signOrder, 'YOUR + NAME + WHAT?');
    expect(name.facialExpression, 'WH question: furrow eyebrows');

    for (final id in ['triage', 'medical_family', 'nutrition', 'procedures']) {
      expect(await repo.topicsFor(id), isNotEmpty, reason: id);
    }

    // A second launch on the same file must not reseed.
    await repoAt(path, onLoad: () => loads++).topicsFor('basic');
    expect(loads, 1);
  });

  test('upgrades a v2 database without losing the profile', () async {
    final path = '${dir.path}/old.db';
    final old = await databaseFactory.openDatabase(
      path,
      options: OpenDatabaseOptions(
        version: 2,
        onCreate: (db, _) => db.execute('''
            CREATE TABLE user_profile (
              id INTEGER PRIMARY KEY AUTOINCREMENT, name TEXT NOT NULL,
              nickname TEXT NOT NULL, birthdate TEXT NOT NULL, age INTEGER NOT NULL,
              created_at TEXT NOT NULL, photo_path TEXT)'''),
      ),
    );
    await old.insert('user_profile', {
      'name': 'Yesh Nin',
      'nickname': 'Yesh',
      'birthdate': '2000-02-29',
      'age': 26,
      'created_at': '2026-11-14T00:00:00.000',
    });
    await old.close();

    final repo = repoAt(path);
    expect(await repo.topicsFor('nutrition'), hasLength(3));
    final db = await open(path).database;
    expect(await db.query('user_profile'), hasLength(1));
    expect(await db.getVersion(), AppDatabase.version);
  });

  test(
    'search ranks exact and prefix matches first and escapes wildcards',
    () async {
      final repo = repoAt('${dir.path}/s.db');

      final pain = await repo.search('pain');
      expect(pain, isNotEmpty);
      expect(pain.first.sign.term.toLowerCase(), startsWith('pain'));
      expect(pain.first.categoryId, 'triage');

      // Every word must match somewhere (term, sign order or topic).
      final both = await repo.search('salty food');
      expect(both, isNotEmpty);
      for (final e in both) {
        final hay = '${e.sign.term} ${e.sign.signOrder} ${e.topicTitle}'
            .toLowerCase();
        expect(hay, allOf(contains('salty'), contains('food')));
      }

      // Sign order and topic titles are searchable too.
      expect(
        (await repo.search('HOW-MANY')).map((e) => e.sign.term),
        contains('How old are you?'),
      );
      expect(await repo.search('alphabet'), hasLength(26));

      // Tagalog terms and topic titles are searchable, and rank like English.
      final masakit = await repo.search('saan ang masakit');
      expect(masakit.first.sign.term, 'Where does it hurt?');
      expect(masakit.first.sign.tagalog, 'Saan ang masakit?');
      expect((await repo.search('lunes')).first.sign.term, 'Monday');
      expect(
        (await repo.search('mga gamot')).map((e) => e.sign.term),
        contains('Vitamins'),
      );

      expect(await repo.search('%'), isEmpty);
      expect(await repo.search('_'), isEmpty);
      expect(await repo.search('   '), isEmpty);

      final all = await repo.allSigns();
      expect(all, hasLength(307));
      expect(all.map((e) => e.sign.key).toSet(), hasLength(307));
      expect(all.first.sign.key, 'foundation/Alphabet/Letter A');

      final topic = await repo.topic(all.first.topicId);
      expect(topic?.title, 'Alphabet');
      expect(topic?.signs, hasLength(26));
      expect(await repo.topic(-1), isNull);
    },
  );

  test('memory game keeps the best time per level', () async {
    final lessons = repoAt('${dir.path}/g.db');
    final study = SqliteStudyRepository(lessons);
    expect(await study.gameLevels(), isEmpty);
    await study.saveGameLevel(1, const Duration(seconds: 80));
    await study.saveGameLevel(1, const Duration(seconds: 95));
    await study.saveGameLevel(2, const Duration(seconds: 70));
    expect(await study.gameLevels(), {
      1: const Duration(seconds: 80),
      2: const Duration(seconds: 70),
    });
    await study.saveGameLevel(1, const Duration(seconds: 61));
    expect((await study.gameLevels())[1], const Duration(seconds: 61));
    study.dispose();
  });

  test('study data survives a content reseed', () async {
    final path = '${dir.path}/study.db';
    var now = DateTime(2026, 11, 15, 9);
    final lessons = repoAt(path);
    final study = SqliteStudyRepository(lessons, clock: () => now);
    var notified = 0;
    study.addListener(() => notified++);

    const a = 'foundation/Alphabet/Letter A';
    const pain = 'triage/Chief Complaints/Pain / Ache';
    await study.setBookmarked(a, true);
    now = now.add(const Duration(minutes: 1));
    await study.setBookmarked(pain, true);
    await study.setBookmarked(pain, true); // idempotent
    expect((await study.bookmarks()).map((e) => e.sign.key), [pain, a]);

    await study.markViewed(a);
    now = now.add(const Duration(minutes: 1));
    await study.markViewed('foundation/Alphabet/Letter B');
    await study.markViewed(a); // repeat view: same sign, newer time
    now = now.add(const Duration(minutes: 1));
    await study.markViewed(pain);

    final progress = await study.progress();
    expect(progress['foundation']!.viewed, 2);
    expect(progress['foundation']!.total, 104);
    expect(progress['triage']!.viewed, 1);
    expect(progress['procedures']!.viewed, 0);

    final recents = await study.recentTopics();
    expect(recents.map((r) => r.topicTitle), ['Chief Complaints', 'Alphabet']);
    expect(await study.signsViewedSince(DateTime(2026, 11, 15)), 3);
    expect(await study.signsViewedSince(DateTime(2026, 11, 16)), 0);

    expect(await study.quizStats(), isNull);
    expect(await study.bestQuizScores(), isEmpty);
    await study.saveQuizResult(6, 10, quizId: 'general_1');
    await study.saveQuizResult(9, 10, quizId: 'general_1');
    await study.saveQuizResult(4, 10, quizId: 'general_2');
    final best = await study.bestQuizScores();
    expect(best.keys, unorderedEquals(['general_1', 'general_2']));
    expect((best['general_1']!.score, best['general_1']!.total), (9, 10));
    expect((best['general_2']!.score, best['general_2']!.total), (4, 10));
    final stats = (await study.quizStats())!;
    expect((stats.taken, stats.bestScore, stats.lastScore), (3, 9, 4));
    expect(notified, greaterThan(0));

    // Force a reseed: row ids change, keys don't.
    final oldId = (await study.bookmarks()).last.sign.id;
    final db = await open(path).database;
    await db.delete('app_meta');
    final reseeded = SqliteStudyRepository(repoAt(path), clock: () => now);
    final after = await reseeded.bookmarks();
    expect(after.map((e) => e.sign.key), [pain, a]);
    expect(after.last.sign.id, isNot(oldId));
    expect((await reseeded.progress())['foundation']!.viewed, 2);
    study.dispose();
    reseeded.dispose();
  });

  test('upgrades a v3 database: adds sign keys and study tables', () async {
    final path = '${dir.path}/v3.db';
    final old = await databaseFactory.openDatabase(
      path,
      options: OpenDatabaseOptions(
        version: 3,
        onCreate: (db, _) async {
          await db.execute('''CREATE TABLE user_profile (
              id INTEGER PRIMARY KEY AUTOINCREMENT, name TEXT NOT NULL,
              nickname TEXT NOT NULL, birthdate TEXT NOT NULL, age INTEGER NOT NULL,
              created_at TEXT NOT NULL, photo_path TEXT)''');
          await db.execute(
            'CREATE TABLE app_meta (key TEXT PRIMARY KEY, value TEXT NOT NULL)',
          );
          await db.execute(
            'CREATE TABLE lesson_category (id TEXT PRIMARY KEY, position INTEGER NOT NULL, title TEXT NOT NULL)',
          );
          await db.execute(
            '''CREATE TABLE lesson_topic (id INTEGER PRIMARY KEY AUTOINCREMENT,
              category_id TEXT NOT NULL, position INTEGER NOT NULL, title TEXT NOT NULL)''',
          );
          await db.execute(
            '''CREATE TABLE sign (id INTEGER PRIMARY KEY AUTOINCREMENT,
              topic_id INTEGER NOT NULL, position INTEGER NOT NULL, term TEXT NOT NULL,
              sign_order TEXT, facial_expression TEXT)''',
          );
        },
      ),
    );
    await old.insert('lesson_category', {
      'id': 'foundation',
      'position': 0,
      'title': 'Old',
    });
    await old.insert('lesson_topic', {
      'category_id': 'foundation',
      'position': 0,
      'title': 'Old',
    });
    await old.insert('sign', {
      'topic_id': 1,
      'position': 0,
      'term': 'Old sign',
    });
    await old.insert('app_meta', {'key': 'content_version', 'value': '1'});
    await old.close();

    final lessons = repoAt(path);
    final study = SqliteStudyRepository(lessons);
    final all = await lessons.allSigns();
    expect(all, hasLength(307));
    expect(all.every((e) => e.sign.key.isNotEmpty), isTrue);
    // v5 columns were added and filled by the reseed.
    final arm = all.firstWhere((e) => e.sign.term == 'Arm');
    expect(arm.sign.tagalog, 'Braso');
    expect(arm.sign.media, endsWith('.mp4'));
    expect(arm.sign.hasVideo, isTrue);
    final topic = await lessons.topic(arm.topicId);
    expect(
      topic!.signs.firstWhere((s) => s.term == 'Arm').media,
      arm.sign.media,
    );
    final numbers = await lessons.topicsFor('foundation');
    expect(numbers.firstWhere((t) => t.title == 'Numbers').tagalog, 'Numero');
    await study.setBookmarked(all[5].sign.key, true);
    expect(await study.bookmarks(), hasLength(1));
    await study.saveQuizResult(7, 15, quizId: 'hypertension_2');
    expect((await study.bestQuizScores()).keys, ['hypertension_2']);
    study.dispose();
  });

  test('upgrades a v6 database: quiz results gain a quiz id', () async {
    final path = '${dir.path}/v6.db';
    final old = await databaseFactory.openDatabase(
      path,
      options: OpenDatabaseOptions(
        version: 6,
        onCreate: (db, _) => db.execute('''CREATE TABLE quiz_result (
            id INTEGER PRIMARY KEY AUTOINCREMENT, taken_at TEXT NOT NULL,
            score INTEGER NOT NULL, total INTEGER NOT NULL)'''),
      ),
    );
    await old.insert('quiz_result', {
      'taken_at': '2026-11-01T09:00:00',
      'score': 8,
      'total': 10,
    });
    await old.close();

    final db = await open(path).database;
    expect(await db.getVersion(), AppDatabase.version);
    final rows = await db.query('quiz_result');
    expect(rows.single['score'], 8);
    expect(rows.single.containsKey('quiz_id'), isTrue);
    expect(rows.single['quiz_id'], isNull);
  });

  test('activity log: newest first, capped, cleared', () async {
    final path = '${dir.path}/log.db';
    var now = DateTime(2026, 11, 22, 9);
    final study = SqliteStudyRepository(repoAt(path), clock: () => now);
    await study.logActivity('App opened');
    now = now.add(const Duration(seconds: 5));
    await study.markViewed('triage/Vital Signs/Blood Pressure / BP');
    await study.setBookmarked('triage/Vital Signs/Blood Pressure / BP', true);

    final log = await study.activity();
    expect(log.map((e) => e.action), [
      'Bookmarked sign',
      'Viewed sign',
      'App opened',
    ]);
    expect(log.first.detail, 'Blood Pressure / BP · Vital Signs');
    expect(log.first.at, now);
    expect(await study.activity(limit: 1), hasLength(1));

    await study.clearActivity();
    expect(await study.activity(), isEmpty);
    study.dispose();
  });

  test('upgrades a v7 database: adds the activity log', () async {
    final path = '${dir.path}/v7.db';
    final old = await databaseFactory.openDatabase(
      path,
      options: OpenDatabaseOptions(
        version: 7,
        onCreate: (db, _) => db.execute(
          'CREATE TABLE app_meta (key TEXT PRIMARY KEY, value TEXT NOT NULL)',
        ),
      ),
    );
    await old.close();

    final db = await open(path).database;
    expect(await db.getVersion(), AppDatabase.version);
    await db.insert('activity_log', {'at': '2026-11-22', 'action': 'x'});
    expect(await db.query('activity_log'), hasLength(1));
  });
}
