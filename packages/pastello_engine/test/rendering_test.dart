import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/rendering.dart';
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
    drawing = AddElementCommand(s).apply(drawing);
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

Future<ByteData> capture(WidgetTester tester) async {
  final boundary = tester.renderObject<RenderRepaintBoundary>(
    find.byType(RepaintBoundary).first,
  );
  return (await tester.runAsync(() async {
    final image = await boundary.toImage();
    final bytes = await image.toByteData();
    image.dispose();
    return bytes!;
  }))!;
}

({int maxDelta, double changedRatio}) imageDifference(ByteData a, ByteData b) {
  expect(a.lengthInBytes, b.lengthInBytes);
  var maxDelta = 0, changed = 0;
  for (var i = 0; i < a.lengthInBytes; i += 4) {
    var pixelDelta = 0;
    for (var c = 0; c < 4; c++) {
      final d = (a.getUint8(i + c) - b.getUint8(i + c)).abs();
      if (d > pixelDelta) pixelDelta = d;
    }
    if (pixelDelta > 0) changed++;
    if (pixelDelta > maxDelta) maxDelta = pixelDelta;
  }
  return (maxDelta: maxDelta, changedRatio: changed / (a.lengthInBytes / 4));
}

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
    renderer.showErased(command.apply(drawing), command.sheetErasure);
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

  group('magic brushes', () {
    /// A loop that crosses itself at (200, 120).
    StrokeElement loop(StrokeTool tool, Color color) => StrokeElement(
      id: newElementId(),
      tool: tool,
      color: color,
      width: 24,
      points: [
        for (var i = 0; i <= 80; i++)
          SheetPoint(
            200 + 150 * math.sin(i / 80 * 2 * math.pi),
            120 + 80 * math.sin(i / 80 * 4 * math.pi),
          ),
      ],
    );

    Drawing magic(SheetBackground background) => Drawing(
      sheetSize: sheet,
      background: background,
      elements: [
        wave(StrokeTool.marker, 120, const Color(0xFF1D4ED8)),
        loop(StrokeTool.highlighter, const Color(0xFFFFD60A)),
        wave(StrokeTool.neon, 40, const Color(0xFFFF4FD8)),
        wave(StrokeTool.neon, 200, const Color(0xFF2EE6A6)),
      ],
    );

    /// The brushes with random pieces, and a watercolor going over itself.
    Drawing random(SheetBackground background) => Drawing(
      sheetSize: sheet,
      background: background,
      elements: [
        for (final (i, tool) in [
          StrokeTool.glitter,
          StrokeTool.stars,
          StrokeTool.spray,
        ].indexed)
          StrokeElement(
            id: newElementId(),
            tool: tool,
            color: const Color(0xFFFF4FD8),
            width: 20,
            seed: 7 + i,
            points: wave(tool, 30 + i * 50, const Color(0x00000000)).points,
          ),
        loop(StrokeTool.watercolor, const Color(0xFF3A86FF)),
      ],
    );

    for (final (name, background) in [
      ('white', SheetBackground.white),
      ('dark', const SheetBackground(color: Color(0xFF1E2A44))),
    ]) {
      testWidgets('on $name paper', (tester) async {
        renderer.show(magic(background));
        await tester.pumpWidget(sheetWidget(renderer, live));
        await expectLater(
          find.byType(RepaintBoundary).first,
          matchesGoldenFile('goldens/magic_$name.png'),
        );
        renderer.show(random(background));
        await tester.pump();
        await expectLater(
          find.byType(RepaintBoundary).first,
          matchesGoldenFile('goldens/magic_random_$name.png'),
        );
      });
    }

    testWidgets('the same seed paints the same sparkles', (tester) async {
      StrokeElement glitter(int seed) => StrokeElement(
        id: 'g',
        tool: StrokeTool.glitter,
        color: const Color(0xFFE63946),
        width: 30,
        seed: seed,
        points: wave(StrokeTool.glitter, 120, const Color(0x00000000)).points,
      );
      Future<ByteData> paint(int seed) async {
        renderer.show(
          const Drawing(sheetSize: sheet).withElementAdded(glitter(seed)),
        );
        await tester.pump();
        return capture(tester);
      }

      await tester.pumpWidget(sheetWidget(renderer, live));
      final first = await paint(1);
      expect(imageDifference(first, await paint(1)).maxDelta, 0);
      expect(imageDifference(first, await paint(2)).maxDelta, greaterThan(0));
    });

    testWidgets('watercolor gets darker where it goes over itself', (
      tester,
    ) async {
      renderer.show(
        const Drawing(sheetSize: sheet).withElementAdded(
          loop(StrokeTool.watercolor, const Color(0xFF3A86FF)),
        ),
      );
      await tester.pumpWidget(sheetWidget(renderer, live));
      final image = await capture(tester);
      int red(Offset at) => image.getUint8(
        (at.dy.round() * sheet.width.round() + at.dx.round()) * 4,
      );
      expect(
        red(const Offset(200, 120)),
        lessThan(red(const Offset(350, 120))),
      );
      expect(red(const Offset(350, 120)), lessThan(255));
    });

    testWidgets('the highlighter does not get darker where it crosses '
        'itself', (tester) async {
      renderer.show(
        const Drawing(sheetSize: sheet).withElementAdded(
          loop(StrokeTool.highlighter, const Color(0xFF3A86FF)),
        ),
      );
      await tester.pumpWidget(sheetWidget(renderer, live));
      final image = await capture(tester);
      // Captured at one pixel per sheet unit.
      int red(Offset at) => image.getUint8(
        (at.dy.round() * sheet.width.round() + at.dx.round()) * 4,
      );

      final crossing = red(const Offset(200, 120));
      expect(crossing, lessThan(255), reason: 'the highlighter is there');
      expect(crossing, red(const Offset(350, 120)));
    });
  });

  group('a long live stroke looks the same once committed', () {
    // 240 points: frozen in several batches while "drawing".
    final points = [
      for (var i = 0; i < 240; i++)
        SheetPoint(30 + i * 1.4, 120 + 70 * math.sin(i / 18), time: i * 6),
    ];

    Future<void> drawLive(WidgetTester tester, StrokeTool? tool) async {
      live.begin(tool: tool, color: const Color(0xFFE63946), width: 22);
      for (var i = 0; i < points.length; i++) {
        live.add(points[i]);
        if (i % 10 == 9) await tester.pump();
      }
      await tester.pump();
    }

    for (final tool in StrokeTool.values) {
      testWidgets(tool.name, (tester) async {
        renderer.show(const Drawing(sheetSize: sheet));
        await tester.pumpWidget(sheetWidget(renderer, live));
        await drawLive(tester, tool);
        final liveImage = await capture(tester);

        renderer.show(
          const Drawing(sheetSize: sheet).withElementAdded(
            StrokeElement(
              id: 'committed',
              tool: tool,
              color: live.color,
              width: live.width,
              points: List.of(points),
            ),
          ),
        );
        live.clear();
        await tester.pump();
        await expectLater(
          find.byType(RepaintBoundary).first,
          matchesGoldenFile('goldens/long_${tool.name}.png'),
        );

        // Pieces frozen separately only differ on anti-aliased edges, where
        // they overlap. Measured: < 1% of pixels, at most 51/255.
        final diff = imageDifference(liveImage, await capture(tester));
        expect(diff.maxDelta, lessThanOrEqualTo(64));
        // The blurred glow of the neon also differs by a few levels across
        // its halo, and around the joint with the tail still drawn live.
        expect(
          diff.changedRatio,
          lessThan(tool == StrokeTool.neon ? 0.05 : 0.02),
        );
      });
    }

    testWidgets('eraser', (tester) async {
      renderer.show(sampleDrawing());
      await tester.pumpWidget(sheetWidget(renderer, live));
      await drawLive(tester, null);
      await expectLater(
        find.byType(RepaintBoundary).first,
        matchesGoldenFile('goldens/long_live_eraser.png'),
      );
    });
  });
}
