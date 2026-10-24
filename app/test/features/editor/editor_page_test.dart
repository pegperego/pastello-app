import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pastello/src/app/app_icon.dart';
import 'package:pastello/src/core/settings/app_settings.dart';
import 'package:pastello/src/features/editor/presentation/editor_buttons.dart';
import 'package:pastello/src/features/editor/presentation/sheet_view.dart';

import '../../helpers.dart';

/// Opens the editor on a tablet-sized screen.
Future<void> openEditor(
  WidgetTester tester, {
  bool portrait = false,
  MemorySettingsRepository? settings,
}) async {
  tester.view.devicePixelRatio = 2.25;
  tester.view.physicalSize = portrait
      ? const Size(1600, 2560)
      : const Size(2560, 1600);
  addTearDown(tester.view.reset);
  await pumpApp(tester, settings: settings);
  await tester.tap(find.bySemanticsLabel('Nuovo disegno'));
  await pumpFrames(tester);
}

/// The action button showing [icon]. Found by icon because disabled
/// buttons have no tooltip.
IconButton action(WidgetTester tester, AppIcons icon) => tester.widget(
  find.ancestor(
    of: find.byWidgetPredicate((w) => w is AppIcon && w.icon == icon),
    matching: find.byType(IconButton),
  ),
);

Future<void> drawStroke(WidgetTester tester, {double dy = 0}) async {
  final sheet = tester.getCenter(find.byType(SheetView));
  await tester.timedDragFrom(
    sheet + Offset(-200, dy),
    const Offset(400, 60),
    const Duration(milliseconds: 300),
  );
  await tester.pump();
}

void main() {
  testWidgets('landscape: tools left, colors right; left-handed swaps them', (
    tester,
  ) async {
    await openEditor(tester);
    final sheetX = tester.getCenter(find.byType(SheetView)).dx;
    expect(
      tester.getCenter(find.bySemanticsLabel('Matita')).dx,
      lessThan(sheetX),
    );
    expect(
      tester.getCenter(find.bySemanticsLabel('Altri colori')).dx,
      greaterThan(sheetX),
    );

    await openEditor(
      tester,
      settings: MemorySettingsRepository(const AppSettings(leftHanded: true)),
    );
    final x = tester.getCenter(find.byType(SheetView)).dx;
    expect(
      tester.getCenter(find.bySemanticsLabel('Matita')).dx,
      greaterThan(x),
    );
  });

  testWidgets('portrait: tools and colors below the sheet', (tester) async {
    await openEditor(tester, portrait: true);
    final sheetY = tester.getCenter(find.byType(SheetView)).dy;
    expect(
      tester.getCenter(find.bySemanticsLabel('Matita')).dy,
      greaterThan(sheetY),
    );
    final sheet = tester.getSize(find.byType(SheetView));
    expect(sheet.height, greaterThan(sheet.width));
  });

  testWidgets('drawing, undo, redo and clearing the sheet', (tester) async {
    await openEditor(tester);
    expect(action(tester, AppIcons.undo).onPressed, isNull);

    await drawStroke(tester);
    expect(action(tester, AppIcons.undo).onPressed, isNotNull);

    await tester.tap(find.byTooltip('Annulla'));
    await tester.pump();
    expect(action(tester, AppIcons.undo).onPressed, isNull);
    expect(action(tester, AppIcons.redo).onPressed, isNotNull);

    await tester.tap(find.byTooltip('Ripeti'));
    await tester.pump();

    // A second finger while drawing is ignored (ADR 0008).
    final center = tester.getCenter(find.byType(SheetView));
    final first = await tester.startGesture(center);
    final second = await tester.startGesture(center + const Offset(100, 0));
    await first.moveBy(const Offset(50, 50));
    await second.moveBy(const Offset(50, 50));
    await second.up();
    await first.up();
    await tester.pump();

    await tester.tap(find.byTooltip('Altro'));
    await tester.pump();
    await tester.tap(find.text('Pulisci il foglio'));
    await tester.pump();
    expect(action(tester, AppIcons.redo).onPressed, isNull);
    expect(action(tester, AppIcons.undo).onPressed, isNotNull);
  });

  testWidgets('choosing tools, widths and more colors', (tester) async {
    final settings = MemorySettingsRepository();
    await openEditor(tester, settings: settings);

    await tester.tap(find.bySemanticsLabel('Gomma'));
    await tester.tap(find.bySemanticsLabel('Extra grosso'));
    await tester.pump();
    await drawStroke(tester);
    expect(settings.saved.tool, 'eraser');
    expect(settings.saved.widths['eraser'], 'extraThick');

    final swatches = find.bySemanticsLabel('Colore').evaluate().length;
    await tester.tap(find.bySemanticsLabel('Altri colori'));
    await pumpFrames(tester);
    final sheetSwatch = find.descendant(
      of: find.byType(BottomSheet),
      matching: find.byType(ColorSwatchButton),
    );
    expect(sheetSwatch, findsNWidgets(40));
    await tester.tap(sheetSwatch.at(36));
    await pumpFrames(tester);
    // The picked color gets its own swatch next to the fixed ones.
    expect(find.bySemanticsLabel('Colore'), findsNWidgets(swatches + 1));
    expect(settings.saved.extraColor, isNotNull);
  });

  testWidgets('the rotation lock is applied and remembered', (tester) async {
    final settings = MemorySettingsRepository();
    await openEditor(tester, settings: settings);

    await tester.tap(find.byTooltip('Blocca la rotazione'));
    await tester.pump();
    expect(settings.saved.rotationLock, LockedOrientation.landscape);
    expect(
      requestedOrientations.last,
      contains(DeviceOrientation.landscapeLeft),
    );

    await tester.tap(find.byTooltip('Sblocca la rotazione'));
    await tester.pump();
    expect(settings.saved.rotationLock, isNull);
    expect(requestedOrientations.last, isEmpty);
  });

  testWidgets('home goes back to the gallery', (tester) async {
    await openEditor(tester);
    await tester.tap(find.byTooltip('Torna alla galleria'));
    await pumpFrames(tester);
    expect(find.byType(SheetView), findsNothing);
  });
}
