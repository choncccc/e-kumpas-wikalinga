import 'dart:io';

import 'package:ekumpas_wikalinga/data/app_database.dart';
import 'package:ekumpas_wikalinga/data/lesson_repository.dart';
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
    expect(foundation.map((t) => t.title), ['Alphabet', 'Numbers', 'Time', 'Dates', 'Colors']);
    expect(foundation.first.signs, hasLength(26));
    expect(foundation.first.signs.first.term, 'Letter A');

    final basic = await repo.topicsFor('basic');
    final name = basic.last.signs.firstWhere((s) => s.term == 'What is your name?');
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
    final old = await databaseFactory.openDatabase(path,
        options: OpenDatabaseOptions(
          version: 2,
          onCreate: (db, _) => db.execute('''
            CREATE TABLE user_profile (
              id INTEGER PRIMARY KEY AUTOINCREMENT, name TEXT NOT NULL,
              nickname TEXT NOT NULL, birthdate TEXT NOT NULL, age INTEGER NOT NULL,
              created_at TEXT NOT NULL, photo_path TEXT)'''),
        ));
    await old.insert('user_profile', {
      'name': 'Yesh Nin', 'nickname': 'Yesh', 'birthdate': '2000-02-29',
      'age': 26, 'created_at': '2026-11-14T00:00:00.000',
    });
    await old.close();

    final repo = repoAt(path);
    expect(await repo.topicsFor('nutrition'), hasLength(3));
    final db = await open(path).database;
    expect(await db.query('user_profile'), hasLength(1));
    expect(await db.getVersion(), AppDatabase.version);
  });
}
