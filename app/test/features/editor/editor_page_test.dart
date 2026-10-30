import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pastello/src/app/app_icon.dart';
import 'package:pastello/src/core/settings/app_settings.dart';
import 'package:pastello/src/features/editor/application/editor_controller.dart';
import 'package:pastello/src/features/editor/domain/editor_tool.dart';
import 'package:pastello/src/features/editor/presentation/editor_buttons.dart';
import 'package:pastello/src/features/editor/presentation/editor_page.dart';
import 'package:pastello/src/features/editor/presentation/sheet_view.dart';
import 'package:pastello_engine/pastello_engine.dart';

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

ProviderContainer container(WidgetTester tester) =>
    ProviderScope.containerOf(tester.element(find.byType(EditorPage)));

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
      tester.getCenter(find.bySemanticsLabel('Gomma')).dx,
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
    expect(tester.getCenter(find.bySemanticsLabel('Gomma')).dx, greaterThan(x));
  });

  testWidgets('portrait: tools and colors below the sheet', (tester) async {
    await openEditor(tester, portrait: true);
    final sheetY = tester.getCenter(find.byType(SheetView)).dy;
    expect(
      tester.getCenter(find.bySemanticsLabel('Gomma')).dy,
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

  testWidgets('tools come in categories with a flyout (F-20)', (tester) async {
    final settings = MemorySettingsRepository();
    await openEditor(tester, settings: settings);
    final c = container(tester);

    // The Draw category shows its last tool, the crayon by default.
    expect(find.bySemanticsLabel('Matita'), findsNothing);
    await tester.tap(find.bySemanticsLabel('Pastello'));
    await tester.pump();
    expect(find.bySemanticsLabel('Matita'), findsOneWidget);

    await tester.tap(find.bySemanticsLabel('Pennarello'));
    await tester.pump();
    expect(c.read(editorProvider).tool, EditorTool.marker);
    // The flyout closes and the category now shows the marker.
    expect(find.bySemanticsLabel('Matita'), findsNothing);
    expect(find.bySemanticsLabel('Pennarello'), findsOneWidget);
    expect(settings.saved.categoryTools['draw'], 'marker');

    // One tap brings the marker back after another tool.
    await tester.tap(find.bySemanticsLabel('Gomma'));
    await tester.tap(find.bySemanticsLabel('Pennarello'));
    await tester.pump();
    expect(c.read(editorProvider).tool, EditorTool.marker);
    expect(find.bySemanticsLabel('Matita'), findsOneWidget);
    // A second tap closes the flyout.
    await tester.tap(find.bySemanticsLabel('Pennarello').first);
    await tester.pump();
    expect(find.bySemanticsLabel('Matita'), findsNothing);
  });

  testWidgets('the magic brushes draw with the selected color (F-17)', (
    tester,
  ) async {
    final settings = MemorySettingsRepository();
    await openEditor(tester, settings: settings);
    final c = container(tester);

    await tester.tap(find.bySemanticsLabel('Arcobaleno'));
    await tester.pump();
    expect(find.bySemanticsLabel('Evidenziatore'), findsOneWidget);
    await tester.tap(find.bySemanticsLabel('Neon'));
    await tester.pump();
    expect(settings.saved.categoryTools['magic'], 'neon');

    await drawStroke(tester);
    final state = c.read(editorProvider);
    final stroke = state.drawing!.elements.last as StrokeElement;
    expect(stroke.tool, StrokeTool.neon);
    expect(stroke.color, state.color);
    expect(stroke.width, WidthPreset.medium.width);

    // The highlighter has its own width, wide by default.
    await tester.tap(find.bySemanticsLabel('Neon'));
    await tester.pump();
    await tester.tap(find.bySemanticsLabel('Evidenziatore'));
    await tester.pump();
    await drawStroke(tester, dy: 80);
    final highlight =
        c.read(editorProvider).drawing!.elements.last as StrokeElement;
    expect(highlight.tool, StrokeTool.highlighter);
    expect(highlight.width, WidthPreset.thick.width);

    // The random brushes keep a seed and every point drawn.
    await tester.tap(find.bySemanticsLabel('Evidenziatore'));
    await tester.pump();
    await tester.tap(find.bySemanticsLabel('Glitter'));
    await tester.pump();
    await drawStroke(tester, dy: -80);
    final glitter =
        c.read(editorProvider).drawing!.elements.last as StrokeElement;
    expect(glitter.tool, StrokeTool.glitter);
    expect(glitter.seed, isNot(0));
    expect(glitter.points.length, greaterThan(highlight.points.length));
  });

  testWidgets('a long press opens the flyout; the sheet closes it and draws', (
    tester,
  ) async {
    await openEditor(tester);
    final c = container(tester);
    await tester.tap(find.bySemanticsLabel('Gomma'));
    await tester.longPress(find.bySemanticsLabel('Pastello'));
    await tester.pump();
    expect(find.bySemanticsLabel('Matita'), findsOneWidget);
    expect(c.read(editorProvider).tool, EditorTool.eraser);

    await tester.tap(find.bySemanticsLabel('Pennello'));
    await tester.pump();
    await tester.longPress(find.bySemanticsLabel('Pennello'));
    await tester.pump();
    await drawStroke(tester);
    expect(find.bySemanticsLabel('Matita'), findsNothing);
    expect(c.read(editorProvider).canUndo, isTrue);
  });

  testWidgets('each category remembers its tool between sessions', (
    tester,
  ) async {
    await openEditor(
      tester,
      settings: MemorySettingsRepository(
        const AppSettings(tool: 'eraser', categoryTools: {'draw': 'brush'}),
      ),
    );
    expect(find.bySemanticsLabel('Pennello'), findsOneWidget);
    expect(container(tester).read(editorProvider).tool, EditorTool.eraser);
  });

  testWidgets('portrait: the widths fold into one button', (tester) async {
    final settings = MemorySettingsRepository();
    await openEditor(tester, portrait: true, settings: settings);
    expect(find.bySemanticsLabel('Extra grosso'), findsNothing);

    await tester.tap(find.bySemanticsLabel('Medio'));
    await tester.pump();
    await tester.tap(find.bySemanticsLabel('Extra grosso'));
    await tester.pump();
    expect(settings.saved.widths['crayon'], 'extraThick');
    // The flyout closed; the button shows the new width.
    expect(find.bySemanticsLabel('Medio'), findsNothing);
    expect(find.bySemanticsLabel('Extra grosso'), findsOneWidget);
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

  testWidgets('on a phone held upright every action button is on screen', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 2.625;
    tester.view.physicalSize = const Size(1080, 2340);
    addTearDown(tester.view.reset);
    await pumpApp(tester);
    await tester.tap(find.bySemanticsLabel('Nuovo disegno'));
    await pumpFrames(tester);

    final screen = Offset.zero & tester.view.physicalSize / 2.625;
    for (final tooltip in ['Torna alla galleria', 'Stampa', 'Altro']) {
      final box = tester.getRect(find.byTooltip(tooltip));
      expect(screen.contains(box.topLeft), isTrue, reason: tooltip);
      expect(
        screen.contains(box.bottomRight - const Offset(1, 1)),
        isTrue,
        reason: tooltip,
      );
    }
  });
}
