import 'dart:io';
import 'dart:ui';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pastello/src/features/backup/application/backup_providers.dart';
import 'package:pastello/src/features/backup/data/document_picker.dart';
import 'package:pastello/src/features/backup/data/drawing_backup.dart';
import 'package:pastello/src/features/drawings/application/drawings_providers.dart';
import 'package:pastello/src/features/drawings/data/drawing_repository.dart';
import 'package:pastello/src/features/parents/application/parents_providers.dart';
import 'package:pastello_engine/pastello_engine.dart';

/// Stands for the system pickers: "saves" to [saved], "opens" [toOpen].
class FakePicker implements DocumentPicker {
  File? saved;
  String? savedName;
  File? toOpen;
  bool cancel = false;

  @override
  Future<bool> save(File file, {required String name}) async {
    if (cancel) return false;
    savedName = name;
    await file.copy(saved!.path);
    return true;
  }

  @override
  Future<bool> open(File target) async {
    if (cancel) return false;
    await toOpen!.copy(target.path);
    return true;
  }
}

void main() {
  late Directory root, scratch, outside;
  late FakePicker picker;
  late ProviderContainer container;

  setUp(() {
    root = Directory.systemTemp.createTempSync('pastello-root');
    scratch = Directory.systemTemp.createTempSync('pastello-scratch');
    outside = Directory.systemTemp.createTempSync('pastello-outside');
    picker = FakePicker()..saved = File('${outside.path}/backup.zip');
    container = ProviderContainer(
      overrides: [
        drawingRepositoryProvider.overrideWithValue(
          FileDrawingRepository(root),
        ),
        drawingBackupProvider.overrideWithValue(DrawingBackup(root)),
        documentPickerProvider.overrideWithValue(picker),
        backupScratchProvider.overrideWithValue(() async => scratch),
        appInfoProvider.overrideWith(
          (ref) async =>
              const AppInfo(version: '1.1.0 (2)', device: 'd', android: '16'),
        ),
      ],
    );
  });
  tearDown(() {
    container.dispose();
    for (final d in [root, scratch, outside]) {
      d.deleteSync(recursive: true);
    }
  });

  Future<void> saveDrawing() => container
      .read(drawingRepositoryProvider)
      .save(newElementId(), const Drawing(sheetSize: Size(400, 300)));

  test('export saves the file where the parent chooses', () async {
    await saveDrawing();
    await saveDrawing();
    var written = false;
    final count = await container
        .read(backupActionsProvider)
        .exportAll(fileName: 'pastello.zip', onWritten: () => written = true);
    expect(count, 2);
    expect(written, isTrue);
    expect(picker.savedName, 'pastello.zip');
    expect(picker.saved!.existsSync(), isTrue);
    // The temporary copy is gone.
    expect(scratch.listSync(), isEmpty);
  });

  test('a cancelled export returns null and leaves nothing behind', () async {
    await saveDrawing();
    picker.cancel = true;
    expect(
      await container
          .read(backupActionsProvider)
          .exportAll(fileName: 'pastello.zip'),
      isNull,
    );
    expect(scratch.listSync(), isEmpty);
  });

  test('import adds the drawings and refreshes the gallery', () async {
    // A backup from another tablet.
    final other = Directory.systemTemp.createTempSync('pastello-other');
    addTearDown(() => other.deleteSync(recursive: true));
    await FileDrawingRepository(
      other,
    ).save(newElementId(), const Drawing(sheetSize: Size(400, 300)));
    picker.toOpen = File('${outside.path}/other.zip');
    await DrawingBackup(other).export(picker.toOpen!, appVersion: '1.1.0');

    expect(await container.read(drawingsProvider.future), isEmpty);
    var picked = false;
    final report = await container
        .read(backupActionsProvider)
        .importFile(onPicked: () => picked = true);
    expect(picked, isTrue);
    expect(report!.added, 1);
    expect(container.read(drawingsProvider).value, hasLength(1));
    expect(scratch.listSync(), isEmpty);

    picker.cancel = true;
    expect(await container.read(backupActionsProvider).importFile(), isNull);
  });
}
