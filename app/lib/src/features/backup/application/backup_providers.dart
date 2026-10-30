import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';

import '../../drawings/application/drawings_providers.dart';
import '../../parents/application/parents_providers.dart';
import '../data/document_picker.dart';
import '../data/drawing_backup.dart';

/// Exports and imports the drawings. Provided in `main` (and by tests).
final drawingBackupProvider = Provider<DrawingBackup>(
  (ref) => throw UnimplementedError('Override drawingBackupProvider'),
);

/// The system file pickers. Replaced in tests.
final documentPickerProvider = Provider<DocumentPicker>(
  (ref) => const PlatformDocumentPicker(),
);

/// Where backup files are written before being copied. Replaced in tests.
final backupScratchProvider = Provider<Future<Directory> Function()>(
  (ref) => getTemporaryDirectory,
);

final backupActionsProvider = Provider<BackupActions>(BackupActions.new);

/// The parents' page actions for backups (F-21): a temporary file is
/// written, then copied where the parent chooses, and always deleted.
class BackupActions {
  BackupActions(this._ref);

  final Ref _ref;

  /// Writes all the drawings to a file and lets the parent save it as
  /// [fileName]. Returns how many drawings were saved, or `null` if the
  /// parent cancelled.
  ///
  /// [onWritten] runs once the file is ready, before the picker opens.
  Future<int?> exportAll({
    required String fileName,
    void Function()? onWritten,
  }) async {
    final version = await _ref
        .read(appInfoProvider.future)
        .then((info) => info.version, onError: (Object _) => 'unknown');
    final file = await _scratch(fileName);
    try {
      final count = await _ref
          .read(drawingBackupProvider)
          .export(file, appVersion: version);
      onWritten?.call();
      final saved = await _ref
          .read(documentPickerProvider)
          .save(file, name: fileName);
      return saved ? count : null;
    } finally {
      if (await file.exists()) await file.delete();
    }
  }

  /// Lets the parent choose a backup and adds its drawings to the gallery.
  /// Returns `null` if the parent cancelled; throws the exceptions of
  /// [DrawingBackup.import].
  ///
  /// [onPicked] runs once a file is chosen, before it is read.
  Future<ImportReport?> importFile({void Function()? onPicked}) async {
    final file = await _scratch('pastello-import.zip');
    try {
      if (!await _ref.read(documentPickerProvider).open(file)) return null;
      onPicked?.call();
      final report = await _ref.read(drawingBackupProvider).import(file);
      await _ref.read(drawingsProvider.notifier).refresh();
      _ref.invalidate(trashProvider);
      return report;
    } finally {
      if (await file.exists()) await file.delete();
    }
  }

  Future<File> _scratch(String name) async {
    final directory = await _ref.read(backupScratchProvider)();
    return File('${directory.path}/$name');
  }
}
