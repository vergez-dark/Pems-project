import '../../../core/error/result.dart';
import 'backup_record.dart';

abstract interface class BackupRepository {
  Future<Result<BackupRecord>> create({bool uploadToDrive = true});
  Future<Result<List<BackupRecord>>> list();
  Future<Result<void>> restore(BackupRecord record);
}

class CreateBackup {
  const CreateBackup(this.repository);
  final BackupRepository repository;
  Future<Result<BackupRecord>> call({bool uploadToDrive = true}) =>
      repository.create(uploadToDrive: uploadToDrive);
}

class ListBackups {
  const ListBackups(this.repository);
  final BackupRepository repository;
  Future<Result<List<BackupRecord>>> call() => repository.list();
}

class RestoreBackup {
  const RestoreBackup(this.repository);
  final BackupRepository repository;
  Future<Result<void>> call(BackupRecord record) => repository.restore(record);
}
