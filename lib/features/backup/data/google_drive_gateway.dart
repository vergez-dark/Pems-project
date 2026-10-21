import 'dart:async';
import 'dart:io';

import 'package:google_sign_in/google_sign_in.dart';
import 'package:googleapis/drive/v3.dart' as drive;
import 'package:http/http.dart' as http;

class GoogleDriveGateway {
  GoogleDriveGateway({GoogleSignIn? signIn, this.allowInteractive = true})
    : _signIn =
          signIn ??
          GoogleSignIn(scopes: const [drive.DriveApi.driveAppdataScope]);
  final GoogleSignIn _signIn;
  final bool allowInteractive;

  Future<drive.DriveApi> _api() async {
    final account =
        await _signIn.signInSilently() ??
        (allowInteractive ? await _signIn.signIn() : null);
    if (account == null) throw StateError('Connexion Google annulée.');
    return drive.DriveApi(_GoogleAuthClient(await account.authHeaders));
  }

  Future<String> upload(File source, String name) async {
    final api = await _api();
    final metadata = drive.File()
      ..name = name
      ..parents = const ['appDataFolder'];
    final created = await api.files.create(
      metadata,
      uploadMedia: drive.Media(source.openRead(), await source.length()),
      $fields: 'id',
    );
    if (created.id == null) {
      throw StateError('Google Drive n’a pas retourné d’identifiant.');
    }
    await _trim(api);
    return created.id!;
  }

  Future<List<drive.File>> list() async {
    final api = await _api();
    final result = await api.files.list(
      spaces: 'appDataFolder',
      q: "name contains 'pasora-backup-' and trashed = false",
      orderBy: 'createdTime desc',
      $fields: 'files(id,name,size,createdTime)',
    );
    return result.files ?? const [];
  }

  Future<File> download(String fileId, File target) async {
    final api = await _api();
    final media = await api.files.get(
      fileId,
      downloadOptions: drive.DownloadOptions.fullMedia,
    );
    if (media is! drive.Media) {
      throw StateError('Téléchargement Drive invalide.');
    }
    final sink = target.openWrite();
    await media.stream.pipe(sink);
    return target;
  }

  Future<void> _trim(drive.DriveApi api) async {
    final files =
        (await api.files.list(
          spaces: 'appDataFolder',
          q: "name contains 'pasora-backup-' and trashed = false",
          orderBy: 'createdTime desc',
          $fields: 'files(id)',
        )).files ??
        const [];
    for (final file in files.skip(14)) {
      if (file.id != null) await api.files.delete(file.id!);
    }
  }
}

class _GoogleAuthClient extends http.BaseClient {
  _GoogleAuthClient(this.headers);
  final Map<String, String> headers;
  final http.Client _inner = http.Client();

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) {
    request.headers.addAll(headers);
    return _inner.send(request);
  }

  @override
  void close() {
    _inner.close();
    super.close();
  }
}
