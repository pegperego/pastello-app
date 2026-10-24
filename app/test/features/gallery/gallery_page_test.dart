import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pastello/src/features/editor/presentation/sheet_view.dart';
import 'package:pastello/src/features/gallery/presentation/gallery_page.dart';
import 'package:pastello/src/features/gallery/presentation/trash_page.dart';

import '../../helpers.dart';

/// Solves the parental gate shown on screen.
Future<void> solveGate(WidgetTester tester, {bool wrongFirst = false}) async {
  int answer() {
    final question = tester
        .widgetList<Text>(find.byType(Text))
        .map((t) => t.data ?? '')
        .firstWhere((t) => RegExp(r'^\d+ \+ \d+ = \?$').hasMatch(t));
    final numbers = RegExp(
      r'\d+',
    ).allMatches(question).map((m) => int.parse(m[0]!));
    return numbers.reduce((a, b) => a + b);
  }

  Future<void> type(String text) async {
    for (final digit in text.split('')) {
      await tester.tap(find.widgetWithText(FilledButton, digit));
    }
    await tester.tap(find.bySemanticsLabel('Conferma'));
    await tester.pump();
  }

  if (wrongFirst) {
    final before = answer();
    await type('1');
    await tester.tap(find.bySemanticsLabel('Cancella cifra'));
    await type('${before + 1}');
  }
  await type('${answer()}');
  await pumpFrames(tester);
}

void main() {
  testWidgets('an empty gallery shows only the "+"', (tester) async {
    await pumpApp(tester);
    expect(find.byType(GalleryPage), findsOneWidget);
    expect(find.text('Pastello'), findsOneWidget);
    expect(find.byIcon(Icons.add_rounded), findsOneWidget);
    expect(find.byIcon(Icons.more_horiz_rounded), findsNothing);
  });

  testWidgets('drawings are listed newest first, with relative dates', (
    tester,
  ) async {
    final drawings = MemoryDrawingRepository()
      ..add('old', DateTime(2026, 10, 12, 9))
      ..add('yesterday', DateTime(2026, 10, 23, 20))
      ..add('today', DateTime(2026, 10, 24, 8))
      ..add('last-year', DateTime(2025, 3, 2));
    await pumpApp(tester, drawings: drawings);
    await tester.pump();
    final labels = tester
        .widgetList<Text>(find.byType(Text))
        .map((t) => t.data)
        .toList();
    expect(
      labels,
      containsAllInOrder(['oggi', 'ieri', '12 ott', '2 mar 2025']),
    );
    expect(find.bySemanticsLabel('Disegno di oggi'), findsOneWidget);
  });

  testWidgets('the "+" breathes, unless animations are disabled', (
    tester,
  ) async {
    await pumpApp(tester);
    expect(tester.hasRunningAnimations, isTrue);

    await pumpApp(tester, disableAnimations: true);
    await tester.pump();
    expect(tester.hasRunningAnimations, isFalse);
  });

  testWidgets('duplicate and delete from the options', (tester) async {
    final drawings = MemoryDrawingRepository()..add('a', testNow);
    await pumpApp(tester, drawings: drawings);
    await tester.pump();

    await tester.tap(find.byTooltip('Opzioni del disegno'));
    await pumpFrames(tester);
    await tester.tap(find.text('Duplica'));
    await pumpFrames(tester);
    expect(drawings.drawings.keys, containsAll(['a', 'a-copy']));
    expect(find.byTooltip('Opzioni del disegno'), findsNWidgets(2));

    await tester.tap(find.byTooltip('Opzioni del disegno').first);
    await pumpFrames(tester);
    await tester.tap(find.text('Elimina'));
    await pumpFrames(tester);
    expect(drawings.trash, hasLength(1));
    expect(find.byTooltip('Opzioni del disegno'), findsOneWidget);
  });

  testWidgets('trash: restore freely, empty only after the gate', (
    tester,
  ) async {
    final drawings = MemoryDrawingRepository()
      ..add('a', testNow)
      ..add('b', testNow);
    await drawings.moveToTrash('a');
    await drawings.moveToTrash('b');
    await pumpApp(tester, drawings: drawings);
    await tester.tap(find.byTooltip('Cestino'));
    await pumpFrames(tester);
    expect(find.byType(TrashPage), findsOneWidget);
    expect(find.text('I disegni restano qui per 30 giorni.'), findsOneWidget);

    await tester.tap(find.byTooltip('Ripristina').first);
    await pumpFrames(tester);
    expect(drawings.drawings, hasLength(1));

    // Cancelling the gate keeps the trash.
    await tester.tap(find.text('Svuota il cestino'));
    await pumpFrames(tester);
    expect(find.text('Solo per grandi'), findsOneWidget);
    await tester.tap(find.text('Annulla'));
    await pumpFrames(tester);
    expect(drawings.trash, hasLength(1));

    await tester.tap(find.text('Svuota il cestino'));
    await pumpFrames(tester);
    await solveGate(tester, wrongFirst: true);
    expect(drawings.trash, isEmpty);
    expect(find.text('Il cestino è vuoto'), findsOneWidget);
  });

  testWidgets('a drawing is saved when leaving and opens again', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(2560, 1600);
    tester.view.devicePixelRatio = 2.25;
    addTearDown(tester.view.reset);
    final drawings = MemoryDrawingRepository();
    await pumpApp(tester, drawings: drawings);

    // An empty sheet is not saved (F-01).
    await tester.tap(find.bySemanticsLabel('Nuovo disegno'));
    await pumpFrames(tester);
    await tester.tap(find.byTooltip('Torna alla galleria'));
    await pumpFrames(tester);
    expect(drawings.saves, 0);

    await tester.tap(find.bySemanticsLabel('Nuovo disegno'));
    await pumpFrames(tester);
    final sheet = tester.getCenter(find.byType(SheetView));
    await tester.timedDragFrom(
      sheet,
      const Offset(200, 50),
      const Duration(milliseconds: 200),
    );
    await tester.pump();
    await tester.tap(find.byTooltip('Torna alla galleria'));
    await pumpFrames(tester);
    expect(drawings.drawings, hasLength(1));
    expect(find.bySemanticsLabel('Disegno di oggi'), findsOneWidget);

    // Reopen: the stroke can still be undone.
    await tester.tap(find.bySemanticsLabel('Disegno di oggi'));
    await pumpFrames(tester);
    await tester.tap(find.byTooltip('Annulla'));
    await tester.pump();
    await tester.tap(find.byTooltip('Torna alla galleria'));
    await pumpFrames(tester);
    final saved = drawings.drawings.values.single.$1;
    expect(saved.drawing.isEmpty, isTrue);
    expect(saved.redo, hasLength(1));
  });
}
