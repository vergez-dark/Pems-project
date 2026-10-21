enum BackupStatus { local, uploaded, failed }

class BackupRecord {
  const BackupRecord({
    required this.id,
    required this.date,
    required this.size,
    required this.status,
    this.driveFileId,
    this.localPath,
  });
  final String id;
  final DateTime date;
  final int size;
  final BackupStatus status;
  final String? driveFileId;
  final String? localPath;
}
