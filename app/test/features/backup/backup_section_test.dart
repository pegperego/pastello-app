import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pastello/src/features/backup/application/backup_providers.dart';
import 'package:pastello/src/features/backup/data/drawing_backup.dart';

import '../../helpers.dart';
import '../parents/parents_page_test.dart' show openParents, scrollTo;

/// Backup actions without files or pickers.
class FakeBackupActions implements BackupActions {
  int? exported = 2;
  ImportReport? report;
  Object? importError;
  String? fileName;

  @override
  Future<int?> exportAll({
    required String fileName,
    void Function()? onWritten,
  }) async {
    this.fileName = fileName;
    onWritten?.call();
    return exported;
  }

  @override
  Future<ImportReport?> importFile({void Function()? onPicked}) async {
    onPicked?.call();
    if (importError != null) throw importError!;
    return report;
  }
}

void main() {
  late FakeBackupActions actions;

  Future<void> open(WidgetTester tester, {bool withDrawings = true}) async {
    actions = FakeBackupActions();
    await openParents(
      tester,
      drawings: withDrawings
          ? (MemoryDrawingRepository()..add('a', testNow))
          : MemoryDrawingRepository(),
      overrides: [backupActionsProvider.overrideWithValue(actions)],
    );
    await scrollTo(tester, find.text('Importa disegni'));
  }

  testWidgets('export saves a dated file and says how many drawings', (
    tester,
  ) async {
    await open(tester);
    await tester.tap(find.text('Esporta tutti i disegni'));
    await pumpFrames(tester);
    expect(actions.fileName, 'pastello-disegni-2026-10-24.zip');
    expect(find.text('2 disegni esportati'), findsOneWidget);
    // The waiting dialog is gone.
    expect(find.byType(CircularProgressIndicator), findsNothing);
  });

  testWidgets('there is nothing to export from an empty gallery', (
    tester,
  ) async {
    await open(tester, withDrawings: false);
    final button = tester.widget<TextButton>(
      find.ancestor(
        of: find.text('Esporta tutti i disegni'),
        matching: find.byWidgetPredicate((w) => w is TextButton),
      ),
    );
    expect(button.onPressed, isNull);
  });

  testWidgets('import reports what was added and skipped', (tester) async {
    await open(tester);
    actions.report = const ImportReport(
      added: 3,
      alreadyPresent: 1,
      unreadable: 2,
    );
    await tester.tap(find.text('Importa disegni'));
    await pumpFrames(tester);
    expect(find.text('Importazione completata'), findsOneWidget);
    expect(
      find.text(
        '3 disegni aggiunti alla galleria.\n1 era già presente.\n'
        '2 non si potevano leggere.',
      ),
      findsOneWidget,
    );
    expect(find.byType(CircularProgressIndicator), findsNothing);
    await tester.tap(find.text('OK'));
    await pumpFrames(tester);
    expect(find.text('Importazione completata'), findsNothing);
  });

  testWidgets('import explains a wrong or newer file', (tester) async {
    await open(tester);
    actions.importError = const BackupFormatException('no manifest');
    await tester.tap(find.text('Importa disegni'));
    await pumpFrames(tester);
    expect(
      find.text('Questo file non è una copia dei disegni di Pastello.'),
      findsOneWidget,
    );
    await tester.tap(find.text('OK'));
    await pumpFrames(tester);

    actions.importError = const BackupTooNewException();
    await tester.tap(find.text('Importa disegni'));
    await pumpFrames(tester);
    expect(find.textContaining('versione più recente'), findsOneWidget);
  });

  testWidgets('a cancelled import shows nothing', (tester) async {
    await open(tester);
    await tester.tap(find.text('Importa disegni'));
    await pumpFrames(tester);
    expect(find.text('Importazione completata'), findsNothing);
  });
}
