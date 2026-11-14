import 'app_database.dart';
import 'avatar_storage.dart';
import 'user_profile.dart';

abstract class UserRepository {
  Future<UserProfile?> getProfile();
  Future<UserProfile> saveProfile(UserProfile profile);
}

class SqliteUserRepository implements UserRepository {
  SqliteUserRepository({AppDatabase? database, AvatarStorage? avatars})
    : _database = database ?? AppDatabase.instance,
      _avatars = avatars ?? AvatarStorage();

  final AppDatabase _database;
  final AvatarStorage _avatars;
  static const _table = 'user_profile';

  @override
  Future<UserProfile?> getProfile() async {
    final db = await _database.database;
    final rows = await db.query(_table, orderBy: 'id DESC', limit: 1);
    return rows.isEmpty ? null : UserProfile.fromMap(rows.first);
  }

  /// The app holds one learner per device, so saving replaces any earlier row.
  /// A picked photo is copied into app storage first, and older photos are
  /// cleaned up once the new row is committed.
  @override
  Future<UserProfile> saveProfile(UserProfile profile) async {
    final photo = profile.photoPath == null
        ? null
        : await _avatars.persist(profile.photoPath!);
    final toSave = profile.copyWith(photoPath: photo);

    final db = await _database.database;
    final saved = await db.transaction((txn) async {
      await txn.delete(_table);
      final id = await txn.insert(_table, toSave.toMap()..remove('id'));
      return UserProfile.fromMap({...toSave.toMap(), 'id': id});
    });

    await _avatars.deleteAllExcept(saved.photoPath);
    return saved;
  }
}
