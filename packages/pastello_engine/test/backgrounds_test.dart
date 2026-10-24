import 'dart:convert';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pastello_engine/pastello_engine.dart';

const sheet = Size(600, 360);

StrokeElement scribble() => StrokeElement(
  id: newElementId(),
  tool: StrokeTool.marker,
  color: const Color(0xFFE63946),
  width: 40,
  points: const [SheetPoint(60, 180), SheetPoint(540, 180)],
);

Map<String, Object?> viaText(Map<String, Object?> json) =>
    jsonDecode(jsonEncode(json)) as Map<String, Object?>;

void main() {
  test('one printed centimeter is the long side over 29.7', () {
    expect(
      SheetBackground.centimeter(const Size(1188, 600)),
      closeTo(40, 1e-9),
    );
    expect(
      SheetBackground.centimeter(const Size(600, 1188)),
      closeTo(40, 1e-9),
    );
  });

  test('backgrounds round-trip; plain white is not written', () {
    const lines = SheetBackground(
      color: Color(0xFFFFF3B0),
      pattern: BackgroundPattern.lines,
    );
    final drawing = const Drawing(sheetSize: sheet).withBackground(lines);
    final json = viaText(drawingToJson(drawing));
    expect(drawingFromJson(json).background, lines);
    expect(
      drawingToJson(const Drawing(sheetSize: sheet)).containsKey('background'),
      isFalse,
    );
    expect(
      drawingFromJson(
        viaText(drawingToJson(const Drawing(sheetSize: sheet))),
      ).background,
      SheetBackground.white,
    );
    // Unknown patterns fall back to plain paper.
    expect(
      backgroundFromJson({'color': 0xFFFFFFFF, 'pattern': 'stripes'}).pattern,
      BackgroundPattern.none,
    );
  });

  test('changing the background is undoable and keeps the drawing', () {
    final stroke = scribble();
    const dots = SheetBackground(pattern: BackgroundPattern.dots);
    final stack = CommandStack(const Drawing(sheetSize: sheet))
      ..execute(AddElementCommand(stroke))
      ..execute(const ChangeBackgroundCommand(SheetBackground.white, dots));
    expect(stack.drawing.background, dots);
    expect(stack.drawing.elements.single, stroke);
    // Every other change keeps the background.
    stack.execute(AddElementCommand(scribble()));
    expect(stack.drawing.background, dots);
    stack
      ..undo()
      ..undo();
    expect(stack.drawing.background, SheetBackground.white);

    const command = ChangeBackgroundCommand(SheetBackground.white, dots);
    final restored =
        commandFromJson(viaText(commandToJson(command)))
            as ChangeBackgroundCommand;
    expect(restored.after, dots);
    expect(dots.copyWith(), dots);
    expect(dots.hashCode, dots.copyWith().hashCode);
    expect(dots.isDefault, isFalse);
  });

  testWidgets('every pattern, and the eraser showing the lines again', (
    tester,
  ) async {
    final grain = PaperGrain.generate();
    final renderer = DrawingRenderer(grain: grain);
    final live = LiveStroke();
    addTearDown(() {
      renderer.dispose();
      live.dispose();
      grain.dispose();
    });

    Future<void> show(Drawing drawing, String golden) async {
      renderer.show(drawing);
      await tester.pumpWidget(
        Center(
          child: RepaintBoundary(
            child: SizedBox.fromSize(
              size: sheet,
              child: CustomPaint(
                painter: SheetPainter(
                  renderer: renderer,
                  live: live,
                  sheetSize: sheet,
                ),
              ),
            ),
          ),
        ),
      );
      await expectLater(
        find.byType(RepaintBoundary).first,
        matchesGoldenFile(golden),
      );
    }

    for (final pattern in BackgroundPattern.values) {
      await show(
        const Drawing(sheetSize: sheet).withBackground(
          SheetBackground(
            pattern: pattern,
            color: pattern == BackgroundPattern.dots
                ? const Color(0xFF1F1F1F)
                : const Color(0xFFFFFFFF),
          ),
        ),
        'goldens/background_${pattern.name}.png',
      );
    }

    // A red stroke across lined paper, then an eraser pass through it.
    final stroke = scribble();
    final drawing = const Drawing(sheetSize: sheet)
        .withBackground(const SheetBackground(pattern: BackgroundPattern.lines))
        .withElementAdded(stroke);
    renderer.show(drawing);
    final erase = EraseCommand.forDrawing(drawing, [
      const SheetPoint(300, 100),
      const SheetPoint(300, 260),
    ], 60)!;
    renderer.showErased(erase.apply(drawing), erase.sheetErasure);
    await tester.pump();
    await expectLater(
      find.byType(RepaintBoundary).first,
      matchesGoldenFile('goldens/background_erased.png'),
    );
  });
}
