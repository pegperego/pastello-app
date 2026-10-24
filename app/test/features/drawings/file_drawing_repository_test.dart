import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:pastello/src/features/drawings/data/drawing_repository.dart';
import 'package:pastello_engine/pastello_engine.dart';

StrokeElement stroke(double y) => StrokeElement(
  id: newElementId(),
  tool: StrokeTool.crayon,
  color: const Color(0xFFE63946),
  width: 10,
  points: [SheetPoint(0, y), SheetPoint(100, y, time: 40)],
);

void main() {
  late Directory root;
  late DateTime now;
  late FileDrawingRepository repository;

  setUp(() {
    root = Directory.systemTemp.createTempSync('pastello');
    now = DateTime(2026, 10, 24, 18);
    repository = FileDrawingRepository(root, clock: () => now);
  });
  tearDown(() => root.deleteSync(recursive: true));

  /// A drawing with two strokes, the second one undone.
  Future<String> saveSample({
    String id = 'a',
    FileDrawingRepository? into,
  }) async {
    final stack = CommandStack(const Drawing(sheetSize: Size(400, 300)))
      ..execute(AddStrokeCommand(stroke(50)))
      ..execute(AddStrokeCommand(stroke(150)))
      ..undo();
    await (into ?? repository).save(
      id,
      stack.drawing,
      undo: stack.undoCommands,
      redo: stack.redoCommands,
      thumbnail: Uint8List.fromList([1, 2, 3]),
    );
    return id;
  }

  test('saves and loads a drawing with its history', () async {
    await saveSample();
    final saved = (await repository.load('a'))!;
    expect(saved.drawing.elements, hasLength(1));
    expect(saved.undo, hasLength(1));
    expect(saved.redo, hasLength(1));

    final list = await repository.list();
    expect(list.single.id, 'a');
    expect(list.single.updatedAt, now);
    expect(list.single.thumbnail, [1, 2, 3]);
    // Atomic writes leave no temporary files behind.
    expect(
      Directory('${root.path}/drawings/a').listSync().map((f) => f.path),
      everyElement(isNot(endsWith('.tmp'))),
    );
  });

  test('the history survives an app restart', () async {
    await saveSample();
    // A new repository, as after restarting the app.
    final restarted = FileDrawingRepository(root, clock: () => now);
    final saved = (await restarted.load('a'))!;
    await restarted.save(
      'a',
      saved.drawing,
      undo: saved.undo,
      redo: saved.redo,
    );
    final again = (await FileDrawingRepository(root).load('a'))!;
    expect(again.undo, hasLength(1));
  });

  test('a history that does not match the drawing is discarded', () async {
    await saveSample();
    final file = File('${root.path}/drawings/a/history.json');
    final history = jsonDecode(file.readAsStringSync()) as Map<String, Object?>;
    file.writeAsStringSync(jsonEncode({...history, 'revision': 99}));
    final saved = (await repository.load('a'))!;
    expect(saved.drawing.elements, hasLength(1));
    expect(saved.undo, isEmpty);

    file.writeAsStringSync('not json');
    expect((await repository.load('a'))!.undo, isEmpty);
  });

  test('unreadable or missing drawings are skipped', () async {
    expect(await repository.load('missing'), isNull);
    await saveSample();
    File('${root.path}/drawings/a/drawing.json').writeAsStringSync('{');
    expect(await repository.load('a'), isNull);
    // A folder without meta.json (an interrupted copy) is not listed.
    Directory('${root.path}/drawings/b').createSync();
    File('${root.path}/drawings/b/drawing.json').writeAsStringSync('{}');
    expect((await repository.list()).map((d) => d.id), ['a']);
  });

  test('lists the newest drawings first', () async {
    await saveSample(id: 'old');
    now = now.add(const Duration(hours: 1));
    await saveSample(id: 'new');
    expect((await repository.list()).map((d) => d.id), ['new', 'old']);
  });

  test('duplicates without the history', () async {
    await saveSample();
    now = now.add(const Duration(minutes: 5));
    final copy = await repository.duplicate('a');
    final saved = (await repository.load(copy))!;
    expect(saved.drawing.elements, hasLength(1));
    expect(saved.undo, isEmpty);
    expect((await repository.list()).first.id, copy);
  });

  test('trash: delete, restore, purge after 30 days, empty', () async {
    await saveSample(id: 'a');
    await saveSample(id: 'b');
    await repository.moveToTrash('a');
    expect((await repository.list()).map((d) => d.id), ['b']);
    expect((await repository.listTrash()).single.deletedAt, now);

    await repository.restore('a');
    expect(await repository.listTrash(), isEmpty);
    expect(await repository.list(), hasLength(2));

    await repository.moveToTrash('a');
    now = now.add(const Duration(days: 29));
    await repository.moveToTrash('b');
    now = now.add(const Duration(days: 2));
    expect(await repository.purgeTrash(), 1);
    expect((await repository.listTrash()).map((d) => d.id), ['b']);

    await repository.emptyTrash();
    expect(await repository.listTrash(), isEmpty);
    // Unknown ids are ignored.
    await repository.moveToTrash('nope');
    await repository.restore('nope');
  });
}
