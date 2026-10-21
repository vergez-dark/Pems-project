import '../../../core/error/result.dart';

abstract interface class PhotoRepository {
  Future<Result<String?>> pickAndStore();
}

class PickProductPhoto {
  const PickProductPhoto(this.repository);
  final PhotoRepository repository;
  Future<Result<String?>> call() => repository.pickAndStore();
}
