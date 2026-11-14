import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

/// Single on-device SQLite database for the app. Everything stays offline.
class AppDatabase {
  AppDatabase._([this._path]);
  static final AppDatabase instance = AppDatabase._();

  /// A database at an explicit path, e.g. a temp file or
  /// `inMemoryDatabasePath` in tests.
  @visibleForTesting
  factory AppDatabase.at(String path) => AppDatabase._(path);

  final String? _path;

  static const _fileName = 'ekumpas_wikalinga.db';
  static const version = 3;

  Database? _db;

  Future<Database> get database async => _db ??= await _open();

  Future<void> close() async {
    await _db?.close();
    _db = null;
  }

  Future<Database> _open() async {
    final path = _path ?? p.join(await getDatabasesPath(), _fileName);
    return openDatabase(
      path,
      version: version,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE user_profile (
            id         INTEGER PRIMARY KEY AUTOINCREMENT,
            name       TEXT    NOT NULL,
            nickname   TEXT    NOT NULL,
            birthdate  TEXT    NOT NULL,
            age        INTEGER NOT NULL,
            created_at TEXT    NOT NULL,
            photo_path TEXT
          )
        ''');
        await _createLessonTables(db);
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          await db.execute(
            'ALTER TABLE user_profile ADD COLUMN photo_path TEXT',
          );
        }
        if (oldVersion < 3) await _createLessonTables(db);
      },
    );
  }

  /// Lesson content, seeded from the bundled JSON by SqliteLessonRepository.
  /// `app_meta.content_version` records which copy of the content is loaded.
  static Future<void> _createLessonTables(Database db) async {
    await db.execute('''
      CREATE TABLE app_meta (
        key   TEXT PRIMARY KEY,
        value TEXT NOT NULL
      )
    ''');
    await db.execute('''
      CREATE TABLE lesson_category (
        id       TEXT    PRIMARY KEY,
        position INTEGER NOT NULL,
        title    TEXT    NOT NULL
      )
    ''');
    await db.execute('''
      CREATE TABLE lesson_topic (
        id          INTEGER PRIMARY KEY AUTOINCREMENT,
        category_id TEXT    NOT NULL REFERENCES lesson_category(id),
        position    INTEGER NOT NULL,
        title       TEXT    NOT NULL
      )
    ''');
    await db.execute('''
      CREATE TABLE sign (
        id                INTEGER PRIMARY KEY AUTOINCREMENT,
        topic_id          INTEGER NOT NULL REFERENCES lesson_topic(id),
        position          INTEGER NOT NULL,
        term              TEXT    NOT NULL,
        sign_order        TEXT,
        facial_expression TEXT
      )
    ''');
    await db.execute(
      'CREATE INDEX idx_topic_category ON lesson_topic(category_id, position)',
    );
    await db.execute('CREATE INDEX idx_sign_topic ON sign(topic_id, position)');
    await db.execute('CREATE INDEX idx_sign_term ON sign(term COLLATE NOCASE)');
  }
}
