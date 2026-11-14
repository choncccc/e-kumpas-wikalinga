import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// Keeps the profile picture inside the app's own documents folder. Files the
/// picker returns live in a cache the OS may clear, so they're copied here.
class AvatarStorage {
  AvatarStorage({Future<Directory> Function()? baseDir})
    : _baseDir = baseDir ?? getApplicationDocumentsDirectory;

  final Future<Directory> Function() _baseDir;

  Future<Directory> _dir() async {
    final dir = Directory(p.join((await _baseDir()).path, 'avatars'));
    if (!dir.existsSync()) await dir.create(recursive: true);
    return dir;
  }

  /// Copies [sourcePath] into app storage and returns the new path. A path
  /// that is already stored is returned as-is.
  Future<String> persist(String sourcePath) async {
    final dir = await _dir();
    if (p.isWithin(dir.path, sourcePath)) return sourcePath;
    final ext = p.extension(sourcePath).isEmpty
        ? '.jpg'
        : p.extension(sourcePath);
    // A fresh name each time so Flutter's image cache never shows the old photo.
    final target = p.join(
      dir.path,
      'avatar_${DateTime.now().microsecondsSinceEpoch}$ext',
    );
    await File(sourcePath).copy(target);
    return target;
  }

  /// Deletes every stored avatar except [keepPath].
  Future<void> deleteAllExcept(String? keepPath) async {
    final dir = await _dir();
    await for (final entity in dir.list()) {
      if (entity is File && entity.path != keepPath) {
        try {
          await entity.delete();
        } on FileSystemException {
          // Best effort; a leftover file is harmless.
        }
      }
    }
  }
}
