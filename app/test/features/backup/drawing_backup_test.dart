import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui';

import 'package:archive/archive_io.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pastello/src/features/backup/data/drawing_backup.dart';
import 'package:pastello/src/features/drawings/data/drawing_repository.dart';
import 'package:pastello_engine/pastello_engine.dart';

final png = Uint8List.fromList([0x89, 0x50, 0x4E, 0x47, 13, 10, 26, 10, 0]);

StrokeElement stroke(double y) => StrokeElement(
  id: newElementId(),
  tool: StrokeTool.crayon,
  color: const Color(0xFFE63946),
  width: 10,
  points: [SheetPoint(0, y), SheetPoint(100, y, time: 40)],
);

void main() {
  late Directory from, to, files;
  final now = DateTime(2026, 10, 30, 18);

  setUp(() {
    from = Directory.systemTemp.createTempSync('pastello-from');
    to = Directory.systemTemp.createTempSync('pastello-to');
    files = Directory.systemTemp.createTempSync('pastello-files');
  });
  tearDown(() {
    for (final d in [from, to, files]) {
      d.deleteSync(recursive: true);
    }
  });

  /// Saves a drawing with one stroke undone, so it has a history.
  Future<String> saveSample(FileDrawingRepository repository) async {
    final id = newElementId();
    final stack = CommandStack(const Drawing(sheetSize: Size(400, 300)))
      ..execute(AddElementCommand(stroke(50)))
      ..execute(AddElementCommand(stroke(150)))
      ..undo();
    await repository.save(
      id,
      stack.drawing,
      undo: stack.undoCommands,
      redo: stack.redoCommands,
      thumbnail: png,
    );
    return id;
  }

  File zip(String name, Map<String, List<int>> entries) {
    final archive = Archive();
    for (final MapEntry(:key, :value) in entries.entries) {
      archive.add(ArchiveFile.bytes(key, value));
    }
    return File('${files.path}/$name')
      ..writeAsBytesSync(ZipEncoder().encodeBytes(archive));
  }

  List<int> manifest([int format = backupFormat]) =>
      utf8.encode(jsonEncode({'format': format}));

  test('exports the gallery and imports it on another device', () async {
    final source = FileDrawingRepository(from, clock: () => now);
    final a = await saveSample(source);
    final b = await saveSample(source);
    final trashed = await saveSample(source);
    await source.moveToTrash(trashed);

    final file = File('${files.path}/backup.zip');
    final count = await DrawingBackup(from).export(file, appVersion: '1.1.0');
    expect(count, 2);

    final report = await DrawingBackup(to).import(file);
    expect(report.added, 2);
    expect(report.alreadyPresent, 0);
    expect(report.unreadable, 0);

    final target = FileDrawingRepository(to);
    final list = await target.list();
    expect(list.map((d) => d.id), unorderedEquals([a, b]));
    // Dates, thumbnail and undo history come along; the trash does not.
    expect(list.first.updatedAt, now);
    expect(list.first.thumbnail, png);
    final loaded = (await target.load(a))!;
    expect(loaded.undo, hasLength(1));
    expect(loaded.redo, hasLength(1));
    expect(await target.listTrash(), isEmpty);
    expect(Directory('${to.path}/import').existsSync(), isFalse);
  });

  test(
    'importing twice adds nothing; trashed drawings count as present',
    () async {
      final repository = FileDrawingRepository(from);
      await saveSample(repository);
      final kept = await saveSample(repository);
      final file = File('${files.path}/backup.zip');
      await DrawingBackup(from).export(file, appVersion: '1.1.0');
      await repository.moveToTrash(kept);

      final report = await DrawingBackup(from).import(file);
      expect(report.added, 0);
      expect(report.alreadyPresent, 2);
    },
  );

  test('an empty gallery exports a backup with no drawings', () async {
    final file = File('${files.path}/empty.zip');
    expect(await DrawingBackup(from).export(file, appVersion: '1.1.0'), 0);
    final report = await DrawingBackup(to).import(file);
    expect(report.added, 0);
  });

  test('rejects files that are not Pastello backups', () async {
    final text = File('${files.path}/notes.zip')..writeAsStringSync('hello');
    expect(
      () => DrawingBackup(to).import(text),
      throwsA(isA<BackupFormatException>()),
    );
    final other = zip('other.zip', {'readme.txt': utf8.encode('hi')});
    expect(
      () => DrawingBackup(to).import(other),
      throwsA(isA<BackupFormatException>()),
    );
    final newer = zip('newer.zip', {
      backupManifest: manifest(backupFormat + 1),
    });
    expect(
      () => DrawingBackup(to).import(newer),
      throwsA(isA<BackupTooNewException>()),
    );
  });

  test('ignores unexpected entries and skips unreadable drawings', () async {
    final repository = FileDrawingRepository(from);
    final id = await saveSample(repository);
    final drawing = File('${from.path}/drawings/$id/drawing.json');
    final good = drawing.readAsBytesSync();
    final newerSchema = (jsonDecode(utf8.decode(good)) as Map<String, Object?>)
      ..['schemaVersion'] = 999;
    final broken = 'b' * 32, newer = 'c' * 32, evil = 'd' * 32;

    final file = zip('mixed.zip', {
      backupManifest: manifest(),
      'drawings/$id/drawing.json': good,
      'drawings/$id/thumbnail.png': utf8.encode('not a png'),
      'drawings/$broken/drawing.json': utf8.encode('{'),
      'drawings/$newer/drawing.json': utf8.encode(jsonEncode(newerSchema)),
      'drawings/$evil/history.json': utf8.encode('{}'),
      // Outside the expected layout: never written anywhere.
      '../escape.json': good,
      'drawings/$id/../../escape.json': good,
      'drawings/not-an-id/drawing.json': good,
      'drawings/$id/script.sh': utf8.encode('rm -rf /'),
    });

    final report = await DrawingBackup(to).import(file);
    expect(report.added, 1);
    // Damaged, newer, and a folder without its drawing.
    expect(report.unreadable, 3);

    final folder = Directory('${to.path}/drawings/$id');
    expect(
      folder.listSync().map((e) => e.uri.pathSegments.last),
      unorderedEquals(['drawing.json', 'meta.json']),
    );
    expect(File('${to.path}/escape.json').existsSync(), isFalse);
    expect(File('${to.parent.path}/escape.json').existsSync(), isFalse);
    // Without its meta.json the drawing still shows in the gallery.
    expect((await FileDrawingRepository(to).list()).single.id, id);
  });
}
