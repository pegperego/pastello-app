import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pastello/src/features/editor/presentation/sheet_view.dart';
import 'package:pastello/src/features/export/application/export_service.dart';
import 'package:pastello_engine/pastello_engine.dart';
import 'package:pdf/pdf.dart';

import '../../helpers.dart';
import '../gallery/gallery_page_test.dart' show solveGate;

void main() {
  test('exported images use the screen resolution along the sheet', () {
    expect(exportWidth(const Size(1137, 711), const Size(2560, 1600)), 2560);
    expect(exportWidth(const Size(800, 1280), const Size(1600, 2560)), 1600);
    expect(exportName(DateTime(2026, 10, 25, 9, 5)), 'pastello-20261025-0905');
  });

  test('the printed page is a one-page PDF', () async {
    final pdf = await printablePdf(transparentPng, PdfPageFormat.a4.landscape);
    expect(String.fromCharCodes(pdf.take(5)), '%PDF-');
  });

  testWidgets('a drawing renders to a PNG of the requested size', (
    tester,
  ) async {
    final drawing = const Drawing(sheetSize: Size(400, 300)).withElementAdded(
      const StrokeElement(
        id: 'a',
        tool: StrokeTool.marker,
        color: Color(0xFF000000),
        width: 10,
        points: [SheetPoint(10, 10), SheetPoint(300, 200)],
      ),
    );
    final png = (await tester.runAsync(() => renderPng(drawing, width: 200)))!;
    final codec = (await tester.runAsync(() => instantiateImageCodec(png)))!;
    final frame = (await tester.runAsync(codec.getNextFrame))!;
    expect(frame.image.width, 200);
    expect(frame.image.height, 150);
  });

  testWidgets('from the gallery: save, print, share behind the gate', (
    tester,
  ) async {
    final drawings = MemoryDrawingRepository()..add('a', testNow);
    await pumpApp(tester, drawings: drawings);
    await tester.pump();

    Future<void> option(String label) async {
      await tester.tap(find.byTooltip('Opzioni del disegno'));
      await pumpFrames(tester);
      await tester.tap(find.text(label));
      await pumpFrames(tester);
    }

    await option('Salva nella galleria');
    expect(exports.calls.single, startsWith('save pastello-20261024-1800'));
    expect(find.text('Salvato nella galleria'), findsOneWidget);

    await option('Stampa');
    expect(exports.calls.last, startsWith('print'));

    // Sharing needs a grown-up: cancelling the gate shares nothing.
    await option('Condividi');
    await tester.tap(find.text('Annulla'));
    await pumpFrames(tester);
    expect(exports.calls, hasLength(2));
    await option('Condividi');
    await solveGate(tester);
    expect(exports.calls.last, startsWith('share'));

    exports.fail = true;
    await option('Stampa');
    expect(find.text('Qualcosa non ha funzionato, riprova'), findsOneWidget);
  });

  testWidgets('from the editor: print button and the more menu', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 2.25;
    tester.view.physicalSize = const Size(2560, 1600);
    addTearDown(tester.view.reset);
    await pumpApp(tester);
    await tester.tap(find.bySemanticsLabel('Nuovo disegno'));
    await pumpFrames(tester);

    // Nothing to print on an empty sheet.
    final print = find.ancestor(
      of: find.byTooltip('Stampa'),
      matching: find.byType(IconButton),
    );
    expect(tester.widget<IconButton>(print).onPressed, isNull);

    await tester.timedDragFrom(
      tester.getCenter(find.byType(SheetView)),
      const Offset(200, 40),
      const Duration(milliseconds: 200),
    );
    await tester.pump();
    await tester.tap(print);
    await pumpFrames(tester);
    expect(exports.calls.single, startsWith('print'));

    await tester.tap(find.byTooltip('Altro'));
    await tester.pump();
    await tester.tap(find.text('Salva nella galleria'));
    await pumpFrames(tester);
    expect(exports.calls.last, startsWith('save'));

    await tester.tap(find.byTooltip('Altro'));
    await tester.pump();
    await tester.tap(find.text('Condividi'));
    await pumpFrames(tester);
    await solveGate(tester);
    expect(exports.calls.last, startsWith('share'));
  });
}
