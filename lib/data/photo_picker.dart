import 'package:image_picker/image_picker.dart';

enum PhotoSource { camera, gallery }

/// Thrown when the user has blocked camera or photo access.
class PhotoPermissionDenied implements Exception {
  const PhotoPermissionDenied(this.source);
  final PhotoSource source;
}

/// Picks a profile picture. An interface so tests can swap in a fake.
abstract class PhotoPicker {
  /// Returns a temporary file path, or null if the user backed out.
  Future<String?> pick(PhotoSource source);
}

class DevicePhotoPicker implements PhotoPicker {
  DevicePhotoPicker([ImagePicker? picker]) : _picker = picker ?? ImagePicker();

  final ImagePicker _picker;

  @override
  Future<String?> pick(PhotoSource source) async {
    try {
      final file = await _picker.pickImage(
        source: source == PhotoSource.camera
            ? ImageSource.camera
            : ImageSource.gallery,
        preferredCameraDevice: CameraDevice.front,
        // An avatar never shows larger than ~400px; keep the file small.
        maxWidth: 800,
        maxHeight: 800,
        imageQuality: 85,
      );
      return file?.path;
    } on Exception catch (e) {
      final msg = e.toString();
      if (msg.contains('access_denied') || msg.contains('permission')) {
        throw PhotoPermissionDenied(source);
      }
      rethrow;
    }
  }
}
