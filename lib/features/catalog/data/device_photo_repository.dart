import 'dart:io';

import 'package:image/image.dart' as img;
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

import '../../../core/error/result.dart';
import '../domain/photo_repository.dart';

class DevicePhotoRepository implements PhotoRepository {
  DevicePhotoRepository({ImagePicker? picker})
    : _picker = picker ?? ImagePicker();
  final ImagePicker _picker;

  @override
  Future<Result<String?>> pickAndStore() async {
    try {
      final picked = await _picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 88,
      );
      if (picked == null) return const Success(null);
      final decoded = img.decodeImage(await picked.readAsBytes());
      if (decoded == null) return const Failure(AppFailure('Image illisible.'));
      final resized = decoded.width > 1600
          ? img.copyResize(decoded, width: 1600)
          : decoded;
      final root = await getApplicationDocumentsDirectory();
      final directory = Directory(p.join(root.path, 'photos'));
      await directory.create(recursive: true);
      final target = File(p.join(directory.path, '${const Uuid().v4()}.jpg'));
      await target.writeAsBytes(
        img.encodeJpg(resized, quality: 82),
        flush: true,
      );
      return Success(target.path);
    } catch (error) {
      return Failure(
        AppFailure('Import de la photo impossible.', cause: error),
      );
    }
  }
}
