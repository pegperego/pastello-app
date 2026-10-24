import 'dart:typed_data';
import 'dart:ui';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pastello/src/core/settings/settings_providers.dart';
import 'package:pastello/src/features/editor/application/editor_controller.dart';
import 'package:pastello_engine/pastello_engine.dart';

import '../../helpers.dart';

const stroke = [SheetPoint(10, 10), SheetPoint(100, 80, time: 30)];

Future<ProviderContainer> container(MemoryDrawingRepository drawings) async {
  final c = ProviderContainer(
    overrides: testOverrides(MemorySettingsRepository(), drawings),
  );
  addTearDown(c.dispose);
  await c.read(settingsProvider.future);
  c.listen(editorProvider, (_, _) {});
  return c;
}

void main() {
  test('changes are saved after a pause, empty sheets never', () async {
    final drawings = MemoryDrawingRepository();
    final c = await container(drawings);
    final editor = c.read(editorProvider.notifier)
      ..ensureSheet(const Size(400, 300));
    await editor.flush();
    expect(drawings.saves, 0);

    editor.commitStroke(stroke);
    await Future<void>.delayed(
      autosaveDelay + const Duration(milliseconds: 100),
    );
    expect(drawings.saves, 1);
    expect(drawings.drawings.keys.single, editor.drawingId);

    // Nothing new to save.
    await editor.flush();
    expect(drawings.saves, 1);
  });

  test('a cleared drawing that was saved is still saved (undo)', () async {
    final drawings = MemoryDrawingRepository();
    final c = await container(drawings);
    final editor = c.read(editorProvider.notifier)
      ..ensureSheet(const Size(400, 300))
      ..commitStroke(stroke);
    await editor.flush();
    editor.clear();
    await editor.flush();
    final saved = drawings.drawings.values.single.$1;
    expect(saved.drawing.isEmpty, isTrue);
    expect(saved.undo, hasLength(2));
  });

  test('opens a saved drawing with its history', () async {
    final drawings = MemoryDrawingRepository()..add('a', testNow);
    final c = await container(drawings);
    final editor = c.read(editorProvider.notifier);
    final opening = editor.open('a');
    expect(c.read(editorProvider).loading, isTrue);
    // The sheet must not be replaced while loading.
    editor.ensureSheet(const Size(800, 600));
    await opening;

    final state = c.read(editorProvider);
    expect(state.loading, isFalse);
    expect(state.drawing!.sheetSize, const Size(400, 300));
    expect(editor.drawingId, 'a');
    editor.commitStroke(stroke);
    await editor.flush();
    expect(drawings.drawings['a']!.$1.undo, hasLength(1));
  });

  test('a missing drawing opens as a new one', () async {
    final c = await container(MemoryDrawingRepository());
    final editor = c.read(editorProvider.notifier);
    await editor.open('missing');
    expect(c.read(editorProvider).loading, isFalse);
    expect(editor.drawingId, isNot('missing'));
    editor.ensureSheet(const Size(300, 200));
    expect(c.read(editorProvider).drawing, isNotNull);
  });

  test('a failed save is retried', () async {
    final drawings = _FailingOnce();
    final c = await container(drawings);
    final editor = c.read(editorProvider.notifier)
      ..ensureSheet(const Size(400, 300))
      ..commitStroke(stroke);
    await editor.flush();
    expect(drawings.drawings, isEmpty);
    await editor.flush();
    expect(drawings.drawings, hasLength(1));
  });
}

class _FailingOnce extends MemoryDrawingRepository {
  bool failed = false;

  @override
  Future<void> save(
    String id,
    Drawing drawing, {
    List<DrawingCommand> undo = const [],
    List<DrawingCommand> redo = const [],
    Uint8List? thumbnail,
  }) {
    if (!failed) {
      failed = true;
      throw const FileSystemExceptionStub();
    }
    return super.save(
      id,
      drawing,
      undo: undo,
      redo: redo,
      thumbnail: thumbnail,
    );
  }
}

class FileSystemExceptionStub implements Exception {
  const FileSystemExceptionStub();
}
