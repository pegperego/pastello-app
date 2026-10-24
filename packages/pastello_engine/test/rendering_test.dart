import 'dart:math' as math;

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pastello_engine/pastello_engine.dart';

const sheet = Size(400, 240);

StrokeElement wave(StrokeTool tool, double y, Color color) => StrokeElement(
  id: newElementId(),
  tool: tool,
  color: color,
  width: 18,
  points: [
    for (var x = 20.0; x <= 380; x += 6)
      SheetPoint(x, y + 8 * math.sin(x / 30), time: x.toInt() * 3),
  ],
);

/// One stroke per tool, plus an eraser pass across all of them.
Drawing sampleDrawing() {
  var drawing = const Drawing(sheetSize: sheet);
  final strokes = [
    wave(StrokeTool.pencil, 20, const Color(0xFF1D4ED8)),
    wave(StrokeTool.marker, 60, const Color(0xFF2A9D3F)),
    wave(StrokeTool.brush, 100, const Color(0xFF8E44AD)),
    wave(StrokeTool.crayon, 140, const Color(0xFFE63946)),
    wave(StrokeTool.rainbow, 180, const Color(0xFF000000)),
  ];
  for (final s in strokes) {
    drawing = AddStrokeCommand(s).apply(drawing);
  }
  final eraser = EraseCommand.forDrawing(drawing, [
    const SheetPoint(200, 0),
    const SheetPoint(200, 240),
  ], 20)!;
  return eraser.apply(drawing);
}

Widget sheetWidget(DrawingRenderer renderer, LiveStroke live) => Center(
  child: RepaintBoundary(
    child: SizedBox.fromSize(
      size: sheet,
      child: CustomPaint(
        painter: SheetPainter(renderer: renderer, live: live, sheetSize: sheet),
      ),
    ),
  ),
);

void main() {
  late PaperGrain grain;
  late DrawingRenderer renderer;
  late LiveStroke live;

  setUp(() {
    grain = PaperGrain.generate();
    renderer = DrawingRenderer(grain: grain);
    live = LiveStroke();
  });

  tearDown(() {
    renderer.dispose();
    live.dispose();
    grain.dispose();
  });

  testWidgets('every tool renders as expected', (tester) async {
    renderer.show(sampleDrawing());
    await tester.pumpWidget(sheetWidget(renderer, live));
    await expectLater(
      find.byType(RepaintBoundary).first,
      matchesGoldenFile('goldens/all_tools.png'),
    );
  });

  testWidgets('cached and uncached rendering match', (tester) async {
    renderer.show(sampleDrawing());
    await tester.pumpWidget(sheetWidget(renderer, live));
    await expectLater(
      find.byType(RepaintBoundary).first,
      matchesGoldenFile('goldens/all_tools.png'),
    );
    renderer.cacheEnabled = false;
    await tester.pump();
    await expectLater(
      find.byType(RepaintBoundary).first,
      matchesGoldenFile('goldens/all_tools.png'),
    );
  });

  test('appending a stroke updates the cache incrementally', () {
    final drawing = sampleDrawing();
    renderer.show(drawing);
    expect(renderer.lastUpdateWasRebuild, isTrue);

    final next = drawing.withElementAdded(
      wave(StrokeTool.marker, 220, const Color(0xFFFF8C42)),
    );
    renderer.show(next);
    expect(renderer.lastUpdateWasRebuild, isFalse);

    // Undo is not an append: the cache is rebuilt.
    renderer.show(drawing);
    expect(renderer.lastUpdateWasRebuild, isTrue);
  });

  test('erasing updates the cache incrementally', () {
    final drawing = sampleDrawing();
    renderer.show(drawing);
    final command = EraseCommand.forDrawing(drawing, [
      const SheetPoint(0, 60),
      const SheetPoint(400, 60),
    ], 10)!;
    renderer.showErased(command.apply(drawing), command.erasure);
    expect(renderer.lastUpdateWasRebuild, isFalse);
  });

  test('an empty sheet does not create a cache', () {
    renderer.show(const Drawing(sheetSize: Size.zero));
    expect(renderer.lastUpdateWasRebuild, isTrue);
    renderer.pixelScale = 0.5;
  });

  test('changing the pixel scale rebuilds the cache', () {
    renderer.show(sampleDrawing());
    renderer.pixelScale = 2;
    expect(renderer.lastUpdateWasRebuild, isTrue);
    expect(renderer.pixelScale, 2);
  });

  testWidgets('the live stroke and the eraser preview are painted', (
    tester,
  ) async {
    renderer.show(sampleDrawing());
    await tester.pumpWidget(sheetWidget(renderer, live));

    live.begin(
      tool: StrokeTool.crayon,
      color: const Color(0xFF4CC9F0),
      width: 24,
    );
    live
      ..add(const SheetPoint(40, 200))
      ..add(const SheetPoint(360, 40, time: 300));
    await tester.pump();
    await expectLater(
      find.byType(RepaintBoundary).first,
      matchesGoldenFile('goldens/live_crayon.png'),
    );

    live.begin(tool: null, color: const Color(0xFF000000), width: 40);
    live
      ..add(const SheetPoint(40, 40))
      ..add(const SheetPoint(360, 200, time: 300));
    await tester.pump();
    expect(live.isEraser, isTrue);
    await expectLater(
      find.byType(RepaintBoundary).first,
      matchesGoldenFile('goldens/live_eraser.png'),
    );

    live.clear();
    expect(live.points, isEmpty);
  });
}
