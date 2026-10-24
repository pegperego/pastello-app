import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:pastello_engine/pastello_engine.dart';

import '../../../core/storage/atomic_file.dart';
import '../domain/drawing_summary.dart';
import '../domain/saved_drawing.dart';

/// How long deleted drawings stay in the trash (ADR 0010).
const trashRetention = Duration(days: 30);

/// Stores the child's drawings.
abstract interface class DrawingRepository {
  /// Saved drawings, newest first.
  Future<List<DrawingSummary>> list();

  /// Drawings in the trash, most recently deleted first.
  Future<List<DrawingSummary>> listTrash();

  /// Loads a drawing and, when it is consistent with it, its history.
  /// Returns `null` if the drawing does not exist or cannot be read.
  Future<SavedDrawing?> load(String id);

  /// Saves a drawing, its undo history and its thumbnail.
  Future<void> save(
    String id,
    Drawing drawing, {
    List<DrawingCommand> undo = const [],
    List<DrawingCommand> redo = const [],
    Uint8List? thumbnail,
  });

  /// Copies a drawing, without its history (ADR 0007). Returns the new id.
  Future<String> duplicate(String id);

  /// Moves a drawing to the trash.
  Future<void> moveToTrash(String id);

  /// Moves a drawing back from the trash.
  Future<void> restore(String id);

  /// Deletes everything in the trash for good.
  Future<void> emptyTrash();

  /// Deletes drawings that have been in the trash longer than
  /// [trashRetention]. Returns how many were deleted.
  Future<int> purgeTrash();
}

/// Stores each drawing in its own folder, as documented in
/// `docs/file-format.md`.
class FileDrawingRepository implements DrawingRepository {
  FileDrawingRepository(Directory root, {DateTime Function()? clock})
    : _drawings = Directory('${root.path}/drawings'),
      _trash = Directory('${root.path}/trash'),
      _now = clock ?? DateTime.now;

  final Directory _drawings;
  final Directory _trash;
  final DateTime Function() _now;

  /// Latest saved revision of each drawing, see [save].
  final Map<String, int> _revisions = {};

  Directory _folder(Directory parent, String id) =>
      Directory('${parent.path}/$id');

  @override
  Future<List<DrawingSummary>> list() async {
    final summaries = await _summaries(_drawings);
    return summaries..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
  }

  @override
  Future<List<DrawingSummary>> listTrash() async {
    final summaries = await _summaries(_trash);
    return summaries..sort(
      (a, b) =>
          (b.deletedAt ?? b.updatedAt).compareTo(a.deletedAt ?? a.updatedAt),
    );
  }

  Future<List<DrawingSummary>> _summaries(Directory parent) async {
    if (!await parent.exists()) return [];
    final summaries = <DrawingSummary>[];
    await for (final entry in parent.list()) {
      if (entry is! Directory) continue;
      final id = entry.uri.pathSegments.lastWhere((s) => s.isNotEmpty);
      final meta = await _readMeta(entry);
      // Folders without a drawing (an interrupted copy) are not drawings.
      if (meta == null || !await File('${entry.path}/drawing.json').exists()) {
        continue;
      }
      final thumbnail = File('${entry.path}/thumbnail.png');
      summaries.add(
        DrawingSummary(
          id: id,
          updatedAt: meta.updatedAt,
          deletedAt: meta.deletedAt,
          thumbnail: await thumbnail.exists()
              ? await thumbnail.readAsBytes()
              : null,
        ),
      );
    }
    return summaries;
  }

  @override
  Future<SavedDrawing?> load(String id) async {
    final folder = _folder(_drawings, id);
    final Drawing drawing;
    final int revision;
    try {
      final json = await _readJson(File('${folder.path}/drawing.json'));
      drawing = drawingFromJson(json);
      revision = json['revision'] is int ? json['revision'] as int : 0;
    } on Object {
      return null;
    }
    _revisions[id] = revision;
    try {
      final history = await _readJson(File('${folder.path}/history.json'));
      // A history saved for another revision belongs to a different state
      // of the drawing: discard it rather than corrupt the drawing.
      if (history['revision'] != revision) {
        return SavedDrawing(drawing: drawing);
      }
      List<DrawingCommand> commands(String key) => [
        for (final c in history[key]! as List<Object?>)
          commandFromJson(c! as Map<String, Object?>),
      ];
      return SavedDrawing(
        drawing: drawing,
        undo: commands('undo'),
        redo: commands('redo'),
      );
    } on Object {
      return SavedDrawing(drawing: drawing);
    }
  }

  @override
  Future<void> save(
    String id,
    Drawing drawing, {
    List<DrawingCommand> undo = const [],
    List<DrawingCommand> redo = const [],
    Uint8List? thumbnail,
  }) async {
    final folder = _folder(_drawings, id);
    final revision = (_revisions[id] ?? 0) + 1;
    _revisions[id] = revision;
    final meta = await _readMeta(folder);
    final now = _now();

    // The drawing first: if saving stops halfway, the history no longer
    // matches it and is discarded on load, but the drawing is safe.
    await writeFileAtomically(
      File('${folder.path}/drawing.json'),
      jsonEncode({...drawingToJson(drawing), 'revision': revision}),
    );
    await writeFileAtomically(
      File('${folder.path}/history.json'),
      jsonEncode({
        'schemaVersion': drawingSchemaVersion,
        'revision': revision,
        'undo': [for (final c in undo) commandToJson(c)],
        'redo': [for (final c in redo) commandToJson(c)],
      }),
    );
    if (thumbnail != null) {
      await writeBytesAtomically(
        File('${folder.path}/thumbnail.png'),
        thumbnail,
      );
    }
    await _writeMeta(
      folder,
      _Meta(createdAt: meta?.createdAt ?? now, updatedAt: now),
    );
  }

  @override
  Future<String> duplicate(String id) async {
    final source = _folder(_drawings, id);
    final copyId = newElementId();
    final copy = _folder(_drawings, copyId);
    await copy.create(recursive: true);
    for (final name in ['drawing.json', 'thumbnail.png']) {
      final file = File('${source.path}/$name');
      if (await file.exists()) await file.copy('${copy.path}/$name');
    }
    final now = _now();
    // meta.json last: until it exists the copy is not listed.
    await _writeMeta(copy, _Meta(createdAt: now, updatedAt: now));
    return copyId;
  }

  @override
  Future<void> moveToTrash(String id) async {
    final folder = _folder(_drawings, id);
    final meta = await _readMeta(folder);
    if (meta == null) return;
    await _trash.create(recursive: true);
    final trashed = await folder.rename(_folder(_trash, id).path);
    await _writeMeta(
      trashed,
      _Meta(
        createdAt: meta.createdAt,
        updatedAt: meta.updatedAt,
        deletedAt: _now(),
      ),
    );
  }

  @override
  Future<void> restore(String id) async {
    final folder = _folder(_trash, id);
    final meta = await _readMeta(folder);
    if (meta == null) return;
    await _drawings.create(recursive: true);
    final restored = await folder.rename(_folder(_drawings, id).path);
    await _writeMeta(
      restored,
      _Meta(createdAt: meta.createdAt, updatedAt: meta.updatedAt),
    );
  }

  @override
  Future<void> emptyTrash() async {
    if (await _trash.exists()) await _trash.delete(recursive: true);
  }

  @override
  Future<int> purgeTrash() async {
    final limit = _now().subtract(trashRetention);
    var purged = 0;
    for (final summary in await listTrash()) {
      final deletedAt = summary.deletedAt;
      if (deletedAt != null && deletedAt.isBefore(limit)) {
        await _folder(_trash, summary.id).delete(recursive: true);
        purged++;
      }
    }
    return purged;
  }

  Future<Map<String, Object?>> _readJson(File file) async =>
      jsonDecode(await file.readAsString()) as Map<String, Object?>;

  Future<_Meta?> _readMeta(Directory folder) async {
    try {
      final json = await _readJson(File('${folder.path}/meta.json'));
      final deletedAt = json['deletedAt'];
      return _Meta(
        createdAt: DateTime.parse(json['createdAt']! as String),
        updatedAt: DateTime.parse(json['updatedAt']! as String),
        deletedAt: deletedAt is String ? DateTime.parse(deletedAt) : null,
      );
    } on Object {
      return null;
    }
  }

  Future<void> _writeMeta(Directory folder, _Meta meta) => writeFileAtomically(
    File('${folder.path}/meta.json'),
    jsonEncode({
      'createdAt': meta.createdAt.toIso8601String(),
      'updatedAt': meta.updatedAt.toIso8601String(),
      if (meta.deletedAt != null)
        'deletedAt': meta.deletedAt!.toIso8601String(),
    }),
  );
}

class _Meta {
  const _Meta({
    required this.createdAt,
    required this.updatedAt,
    this.deletedAt,
  });

  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? deletedAt;
}
