import 'dart:convert';
import 'dart:io';

import 'package:archive/archive_io.dart';
import 'package:flutter/foundation.dart';
import 'package:pastello_engine/pastello_engine.dart';

/// Version of the backup format written by [DrawingBackup.export].
const backupFormat = 1;

/// Name of the manifest at the root of a backup.
const backupManifest = 'pastello-backup.json';

/// The files of a drawing folder that a backup carries (docs/file-format.md).
const _drawingFiles = {
  'drawing.json',
  'history.json',
  'meta.json',
  'thumbnail.png',
};

/// `drawings/<id>/<file>`, with the ids the app generates.
final _entryPattern = RegExp(
  r'^drawings/([0-9a-f]{32})/(drawing\.json|history\.json|meta\.json|thumbnail\.png)$',
);

/// Limits for an imported file, which may come from anywhere (ADR 0020).
const maxBackupEntries = 20000;
const maxBackupEntrySize = 64 << 20;
const maxBackupSize = 2 << 30;

/// The file is not a Pastello backup, or is damaged.
class BackupFormatException implements Exception {
  const BackupFormatException(this.message);

  final String message;

  @override
  String toString() => 'BackupFormatException: $message';
}

/// The backup was written by a newer version of the app.
class BackupTooNewException implements Exception {
  const BackupTooNewException();
}

/// What an import did.
@immutable
class ImportReport {
  const ImportReport({
    required this.added,
    required this.alreadyPresent,
    required this.unreadable,
  });

  /// Drawings added to the gallery.
  final int added;

  /// Drawings skipped because the gallery or the trash already has them.
  final int alreadyPresent;

  /// Drawings that could not be read, for example from a newer version.
  final int unreadable;
}

/// Exports the gallery's drawings to a `.zip` file and imports them back
/// (F-21, ADR 0020). Works on the folders of `FileDrawingRepository`.
class DrawingBackup {
  DrawingBackup(Directory root, {DateTime Function()? clock})
    : _drawings = Directory('${root.path}/drawings'),
      _trash = Directory('${root.path}/trash'),
      _staging = Directory('${root.path}/import'),
      _now = clock ?? DateTime.now;

  final Directory _drawings;
  final Directory _trash;
  final Directory _staging;
  final DateTime Function() _now;

  /// Writes every drawing of the gallery, with its history, to [target].
  /// The trash is left out. Returns how many drawings were written.
  Future<int> export(File target, {required String appVersion}) async {
    final encoder = ZipFileEncoder()..create(target.path);
    var count = 0;
    try {
      encoder.addArchiveFile(
        ArchiveFile.string(
          backupManifest,
          jsonEncode({
            'format': backupFormat,
            'appVersion': appVersion,
            'createdAt': _now().toIso8601String(),
          }),
        ),
      );
      if (await _drawings.exists()) {
        await for (final folder in _drawings.list()) {
          if (folder is! Directory) continue;
          final id = folder.uri.pathSegments.lastWhere((s) => s.isNotEmpty);
          // Like the gallery: a folder without both files is not a drawing.
          if (!await File('${folder.path}/drawing.json').exists() ||
              !await File('${folder.path}/meta.json').exists()) {
            continue;
          }
          for (final name in _drawingFiles) {
            final file = File('${folder.path}/$name');
            if (await file.exists()) {
              await encoder.addFile(file, 'drawings/$id/$name');
            }
          }
          count++;
        }
      }
    } finally {
      await encoder.close();
    }
    return count;
  }

  /// Adds the drawings of the backup in [source] to the gallery. Drawings
  /// already in the gallery or in the trash are skipped.
  ///
  /// Throws [BackupFormatException] if [source] is not a Pastello backup and
  /// [BackupTooNewException] if a newer version wrote it.
  Future<ImportReport> import(File source) async {
    final input = InputFileStream(source.path);
    try {
      final Archive archive;
      try {
        archive = ZipDecoder().decodeStream(input);
      } on Object {
        throw const BackupFormatException('not a zip file');
      }
      _checkManifest(archive);

      if (archive.length > maxBackupEntries) {
        throw const BackupFormatException('too many entries');
      }
      final byId = <String, Map<String, ArchiveFile>>{};
      var total = 0;
      for (final entry in archive) {
        if (!entry.isFile || entry.isSymbolicLink) continue;
        final match = _entryPattern.firstMatch(entry.name);
        if (match == null) continue;
        total += entry.size;
        if (total > maxBackupSize) {
          throw const BackupFormatException('too large');
        }
        (byId[match[1]!] ??= {})[match[2]!] = entry;
      }

      if (await _staging.exists()) await _staging.delete(recursive: true);
      var added = 0, present = 0, unreadable = 0;
      for (final MapEntry(key: id, value: files) in byId.entries) {
        if (await Directory('${_drawings.path}/$id').exists() ||
            await Directory('${_trash.path}/$id').exists()) {
          present++;
        } else if (await _importDrawing(id, files)) {
          added++;
        } else {
          unreadable++;
        }
      }
      return ImportReport(
        added: added,
        alreadyPresent: present,
        unreadable: unreadable,
      );
    } finally {
      await input.close();
      if (await _staging.exists()) await _staging.delete(recursive: true);
    }
  }

  void _checkManifest(Archive archive) {
    final entry = archive.find(backupManifest);
    final bytes = entry == null ? null : _read(entry);
    final Object? format;
    try {
      format =
          (jsonDecode(utf8.decode(bytes!)) as Map<String, Object?>)['format'];
    } on Object {
      throw const BackupFormatException('no manifest');
    }
    if (format is! int || format < 1) {
      throw const BackupFormatException('unknown format');
    }
    if (format > backupFormat) throw const BackupTooNewException();
  }

  /// Copies one drawing to a staging folder, then moves it into the gallery.
  /// Returns `false` if the drawing cannot be read.
  Future<bool> _importDrawing(String id, Map<String, ArchiveFile> files) async {
    final drawing = files['drawing.json'];
    final drawingBytes = drawing == null ? null : _read(drawing);
    if (drawingBytes == null) return false;
    try {
      // Decoding checks the content and the schema version.
      drawingFromJson(
        jsonDecode(utf8.decode(drawingBytes)) as Map<String, Object?>,
      );
    } on Object {
      return false;
    }

    final folder = Directory('${_staging.path}/$id');
    await folder.create(recursive: true);
    await File('${folder.path}/drawing.json').writeAsBytes(drawingBytes);

    // The history is checked when the drawing is opened (ADR 0007).
    final history = files['history.json'];
    final historyBytes = history == null ? null : _read(history);
    if (historyBytes != null) {
      await File('${folder.path}/history.json').writeAsBytes(historyBytes);
    }

    final thumbnail = files['thumbnail.png'];
    final thumbnailBytes = thumbnail == null ? null : _read(thumbnail);
    if (thumbnailBytes != null && _isPng(thumbnailBytes)) {
      await File('${folder.path}/thumbnail.png').writeAsBytes(thumbnailBytes);
    }

    final meta = files['meta.json'];
    final metaBytes = meta == null ? null : _read(meta);
    final now = _now().toIso8601String();
    var dates = {'createdAt': now, 'updatedAt': now};
    try {
      final json = jsonDecode(utf8.decode(metaBytes!)) as Map<String, Object?>;
      final created = DateTime.parse(json['createdAt']! as String);
      final updated = DateTime.parse(json['updatedAt']! as String);
      dates = {
        'createdAt': created.toIso8601String(),
        'updatedAt': updated.toIso8601String(),
      };
    } on Object {
      // Missing or damaged: the drawing counts as imported now.
    }
    await File('${folder.path}/meta.json').writeAsString(jsonEncode(dates));

    await _drawings.create(recursive: true);
    await folder.rename('${_drawings.path}/$id');
    return true;
  }

  /// The content of [entry], or `null` if it is too large or damaged.
  Uint8List? _read(ArchiveFile entry) {
    if (entry.size > maxBackupEntrySize) return null;
    try {
      return entry.readBytes();
    } on Object {
      return null;
    }
  }

  static bool _isPng(Uint8List bytes) =>
      bytes.length > 8 &&
      bytes[0] == 0x89 &&
      bytes[1] == 0x50 &&
      bytes[2] == 0x4E &&
      bytes[3] == 0x47;
}
