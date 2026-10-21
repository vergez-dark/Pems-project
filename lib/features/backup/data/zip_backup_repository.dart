import 'dart:convert';
import 'dart:io';

import 'package:archive/archive_io.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';

import '../../../core/database/app_database.dart';
import '../../../core/error/result.dart';
import '../domain/backup_record.dart';
import '../domain/backup_repository.dart';
import 'google_drive_gateway.dart';

class ZipBackupRepository implements BackupRepository {
  const ZipBackupRepository(this.database, this.drive);
  final AppDatabase database;
  final GoogleDriveGateway drive;

  Future<Directory> get _backupDirectory async {
    final root = await getApplicationDocumentsDirectory();
    final directory = Directory(p.join(root.path, 'backups'));
    await directory.create(recursive: true);
    return directory;
  }

  @override
  Future<Result<BackupRecord>> create({bool uploadToDrive = true}) async {
    try {
      final now = DateTime.now();
      final id = const Uuid().v4();
      final name =
          'pasora-backup-${now.toUtc().toIso8601String().replaceAll(':', '-')}.zip';
      final destination = File(p.join((await _backupDirectory).path, name));
      final db = await database.instance;
      await db.rawQuery('PRAGMA wal_checkpoint(FULL)');
      final metadata = jsonEncode({
        'schemaVersion': AppDatabase.schemaVersion,
        'createdAt': now.toUtc().toIso8601String(),
        'appVersion': '1.0.0',
      });
      final encoder = ZipFileEncoder()..create(destination.path);
      await encoder.addFile(File(await database.path), 'pasora.sqlite');
      encoder.addArchiveFile(ArchiveFile.string('metadata.json', metadata));
      final photos = Directory(
        p.join((await getApplicationDocumentsDirectory()).path, 'photos'),
      );
      if (await photos.exists()) {
        await encoder.addDirectory(photos, includeDirName: true);
      }
      await encoder.close();
      String? driveId;
      var status = BackupStatus.local;
      if (uploadToDrive) {
        driveId = await drive.upload(destination, name);
        status = BackupStatus.uploaded;
      }
      final record = BackupRecord(
        id: id,
        date: now,
        size: await destination.length(),
        status: status,
        driveFileId: driveId,
        localPath: destination.path,
      );
      await db.insert(
        'backup_records',
        _toMap(record),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
      return Success(record);
    } catch (error) {
      return Failure(
        AppFailure(
          uploadToDrive
              ? 'Sauvegarde impossible. Vérifiez la configuration Google Drive.'
              : 'Sauvegarde locale impossible.',
          cause: error,
        ),
      );
    }
  }

  @override
  Future<Result<List<BackupRecord>>> list() async {
    try {
      final db = await database.instance;
      final rows = await db.query('backup_records', orderBy: 'date DESC');
      final local = rows.map(_fromMap).toList();
      try {
        final remote = await drive.list();
        final knownIds = local.map((item) => item.driveFileId).toSet();
        for (final file in remote) {
          if (file.id == null || knownIds.contains(file.id)) continue;
          local.add(
            BackupRecord(
              id: 'drive-${file.id}',
              date: file.createdTime ?? DateTime.now(),
              size: int.tryParse(file.size ?? '') ?? 0,
              status: BackupStatus.uploaded,
              driveFileId: file.id,
            ),
          );
        }
      } catch (_) {
        // Les sauvegardes locales restent utilisables hors connexion.
      }
      local.sort((a, b) => b.date.compareTo(a.date));
      return Success(local);
    } catch (error) {
      return Failure(
        AppFailure('Historique des sauvegardes indisponible.', cause: error),
      );
    }
  }

  @override
  Future<Result<void>> restore(BackupRecord record) async {
    try {
      var archiveFile = record.localPath == null
          ? null
          : File(record.localPath!);
      if (archiveFile == null || !await archiveFile.exists()) {
        if (record.driveFileId == null) {
          throw StateError('Fichier de sauvegarde introuvable.');
        }
        archiveFile = File(
          p.join((await _backupDirectory).path, '${record.id}.zip'),
        );
        await drive.download(record.driveFileId!, archiveFile);
      }
      final archive = ZipDecoder().decodeBytes(
        await archiveFile.readAsBytes(),
        verify: true,
      );
      final metadataEntry = archive.findFile('metadata.json');
      final databaseEntry = archive.findFile('pasora.sqlite');
      if (metadataEntry == null || databaseEntry == null) {
        throw const FormatException('Archive incomplète.');
      }
      final metadata = jsonDecode(
        utf8.decode(metadataEntry.content),
      ) as Map<String, dynamic>;
      final version = metadata['schemaVersion'] as int? ?? 0;
      if (version > AppDatabase.schemaVersion) {
        throw StateError(
          'Cette sauvegarde nécessite une version plus récente de Pasora.',
        );
      }
      await create(
        uploadToDrive: false,
      ); // filet de sécurité avant remplacement
      await database.close();
      await File(await database.path)
          .writeAsBytes(databaseEntry.content, flush: true);
      final root = await getApplicationDocumentsDirectory();
      for (final entry in archive.files.where(
        (item) => item.isFile && item.name.startsWith('photos/'),
      )) {
        final relative = p.normalize(entry.name);
        if (relative.startsWith('..')) continue;
        final output = File(p.join(root.path, relative));
        await output.parent.create(recursive: true);
        await output.writeAsBytes(entry.content, flush: true);
      }
      await database.instance; // ouvre et applique les migrations éventuelles
      return const Success(null);
    } catch (error) {
      return Failure(
        AppFailure('Restauration impossible : $error', cause: error),
      );
    }
  }

  Map<String, Object?> _toMap(BackupRecord record) => {
    'id': record.id,
    'date': record.date.toIso8601String(),
    'size': record.size,
    'drive_file_id': record.driveFileId,
    'status': record.status.name,
    'local_path': record.localPath,
  };

  BackupRecord _fromMap(Map<String, Object?> row) => BackupRecord(
    id: row['id']! as String,
    date: DateTime.parse(row['date']! as String),
    size: row['size']! as int,
    status: BackupStatus.values.byName(row['status']! as String),
    driveFileId: row['drive_file_id'] as String?,
    localPath: row['local_path'] as String?,
  );
}
