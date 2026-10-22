import '../../../core/error/result.dart';

enum PemsPhotoSource { gallery, camera }

abstract interface class PhotoRepository {
  Future<Result<String?>> pickAndStore({PemsPhotoSource source});
}

class PickProductPhoto {
  const PickProductPhoto(this.repository);
  final PhotoRepository repository;
  Future<Result<String?>> call({
    PemsPhotoSource source = PemsPhotoSource.gallery,
  }) => repository.pickAndStore(source: source);
}
