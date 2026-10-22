import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker/image_picker.dart';
import 'package:pasora/core/error/result.dart';
import 'package:pasora/core/security/external_activity_guard.dart';
import 'package:pasora/features/catalog/data/device_photo_repository.dart';
import 'package:pasora/features/catalog/domain/photo_repository.dart';

void main() {
  test(
    'appareil photo et galerie utilisent leurs sources respectives',
    () async {
      final picker = _FakeImagePicker();
      final guard = ExternalActivityGuard();
      final repository = DevicePhotoRepository(
        picker: picker,
        activityGuard: guard,
      );

      final cameraResult = repository.pickAndStore(
        source: PemsPhotoSource.camera,
      );
      expect(picker.lastSource, ImageSource.camera);
      expect(guard.isActive, isTrue);
      picker.complete();
      expect(await cameraResult, isA<Success<String?>>());
      expect(guard.isActive, isFalse);

      final galleryResult = repository.pickAndStore(
        source: PemsPhotoSource.gallery,
      );
      expect(picker.lastSource, ImageSource.gallery);
      expect(guard.isActive, isTrue);
      picker.complete();
      expect(await galleryResult, isA<Success<String?>>());
      expect(guard.isActive, isFalse);
    },
  );

  test('un échec du sélecteur libère aussi le verrou temporaire', () async {
    final picker = _FakeImagePicker();
    final guard = ExternalActivityGuard();
    final repository = DevicePhotoRepository(
      picker: picker,
      activityGuard: guard,
    );

    final result = repository.pickAndStore();
    picker.fail();
    expect(await result, isA<Failure<String?>>());
    expect(guard.isActive, isFalse);
  });
}

class _FakeImagePicker extends ImagePicker {
  Completer<XFile?>? _pending;
  ImageSource? lastSource;

  @override
  Future<XFile?> pickImage({
    required ImageSource source,
    double? maxWidth,
    double? maxHeight,
    int? imageQuality,
    CameraDevice preferredCameraDevice = CameraDevice.rear,
    bool requestFullMetadata = true,
  }) {
    lastSource = source;
    _pending = Completer<XFile?>();
    return _pending!.future;
  }

  void complete() => _pending!.complete();
  void fail() => _pending!.completeError(StateError('camera unavailable'));
}
