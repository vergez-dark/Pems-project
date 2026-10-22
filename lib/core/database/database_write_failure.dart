import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';

import '../error/result.dart';

/// Keep SQL arguments (which may contain customer data) out of device logs.
AppFailure databaseWriteFailure(
  String operation,
  String fallbackMessage,
  Object error,
) {
  if (error is! DatabaseException) {
    debugPrint('PeMS write $operation failed: ${error.runtimeType}');
    return AppFailure(fallbackMessage, cause: error);
  }

  final code = error.getResultCode();
  debugPrint('PeMS write $operation failed: SQLite code ${code ?? 'unknown'}');
  final primaryCode = code == null ? null : code & 0xff;
  final detail = switch (primaryCode) {
    8 => 'La base locale est en lecture seule.',
    13 => 'Le stockage du téléphone est plein.',
    19 => 'Une contrainte de données empêche cette opération.',
    5 || 6 => 'La base locale est momentanément occupée.',
    11 || 26 => 'La base locale est endommagée ou invalide.',
    _ => fallbackMessage,
  };
  return AppFailure(
    code == null ? detail : '$detail (SQLite $code)',
    cause: error,
  );
}
