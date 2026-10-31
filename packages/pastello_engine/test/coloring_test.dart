import 'dart:convert';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pastello_engine/pastello_engine.dart';

const sheet = Size(400, 240);
const black = Color(0xFF000000);
const red = Color(0xFFE63946);
const page = ColoringOutline(packId: 'test', pageId: 'ring');

/// Artwork with one page, 100 × 100: a ring 8 units thick with a white
/// disc inside, which must not stop the paint bucket.
class _Artwork implements ColoringArtwork {
  _Artwork() {
    final recorder = ui.PictureRecorder();
    ui.Canvas(recorder)
      ..drawCircle(
        const Offset(50, 50),
        30,
        ui.Paint()..color = const Color(0xFFFFFFFF),
      )
      ..drawCircle(
        const Offset(50, 50),
        40,
        ui.Paint()
          ..color = black
          ..style = ui.PaintingStyle.stroke
          ..strokeWidth = 8,
      );
    _ring = recorder.endRecording();
  }

  late final ui.Picture _ring;

  @override
  ColoringPage? pageFor(ColoringOutline outline) =>
      outline == page ? (picture: _ring, size: const Size(100, 100)) : null;
}

StrokeElement stroke(String id, double y, {Color color = red}) => StrokeElement(
  id: id,
  tool: StrokeTool.marker,
  color: color,
  width: 20,
  points: [SheetPoint(0, y), SheetPoint(400, y)],
);

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

Color pixel(ByteData data, int x, int y) {
  final i = (y * sheet.width.toInt() + x) * 4;
  return Color.fromARGB(
    data.getUint8(i + 3),
    data.getUint8(i),
    data.getUint8(i + 1),
    data.getUint8(i + 2),
  );
}

void main() {
  // On the 400 × 240 sheet, the margin is 12: the page is placed in a
  // 216 × 216 square centered at (200, 120). The ring is centered there,
  // with radius 86.4 and thickness 17.28 (from 77.8 to 95).
  test('the page fits the sheet with a margin, in both orientations', () {
    expect(
      ColoringOutline.placement(const Size(100, 100), sheet),
      Rect.fromCenter(center: const Offset(200, 120), width: 216, height: 216),
    );
    final portrait = ColoringOutline.placement(
      const Size(200, 100),
      const Size(240, 400),
    );
    expect(portrait.width, closeTo(216, 1e-9));
    expect(portrait.height, closeTo(108, 1e-9));
    expect(portrait.center, const Offset(120, 200));
    expect(ColoringOutline.placement(Size.zero, sheet), Rect.zero);
  });

  test('strokes, shapes and fills go under the outline, texts and stickers '
      'above it', () {
    final fill = FillElement(
      id: 'f',
      color: red,
      mask: FillMask(
        left: 0,
        top: 0,
        rows: [
          Int32List.fromList([0, 4]),
        ],
      ),
    );
    final text = TextElement(id: 't', text: 'Ciao', color: red, fontSize: 20);
    const sticker = StickerElement(id: 's', packId: 'p', elementId: 'e');
    final elements = <DrawingElement>[
      stroke('a', 10),
      text,
      sticker,
      stroke('b', 20),
      fill,
    ];

    final plain = Drawing(sheetSize: sheet, elements: elements);
    expect(plain.paintOrder.map((e) => e.id), ['f', 'a', 't', 's', 'b']);
    expect(plain.overOutline, isEmpty);

    final coloring = Drawing(
      sheetSize: sheet,
      outline: page,
      elements: elements,
    );
    expect(coloring.underOutline.map((e) => e.id), ['f', 'a', 'b']);
    expect(coloring.overOutline.map((e) => e.id), ['t', 's']);
    expect(coloring.paintOrder.map((e) => e.id), ['f', 'a', 'b', 't', 's']);
    // Only the paper, not a command, could change it: every copy keeps it.
    expect(coloring.withElementAdded(stroke('c', 30)).outline, page);
    expect(coloring.withElementRemoved('a').outline, page);
    expect(coloring.withBackground(SheetBackground.white).outline, page);
    expect(ClearCommand(coloring.elements).apply(coloring).outline, page);
  });

  test('the outline round-trips through JSON', () {
    const drawing = Drawing(sheetSize: sheet, outline: page);
    final json =
        jsonDecode(jsonEncode(drawingToJson(drawing))) as Map<String, Object?>;
    expect(json['outline'], {'pack': 'test', 'page': 'ring'});
    expect(drawingFromJson(json).outline, page);
    expect(
      drawingToJson(const Drawing(sheetSize: sheet)).containsKey('outline'),
      isFalse,
    );
    expect(
      drawingFromJson(drawingToJson(const Drawing(sheetSize: sheet))).outline,
      isNull,
    );
  });

  testWidgets('the paint bucket stops at the outline, not at its white '
      'areas', (tester) async {
    const drawing = Drawing(sheetSize: sheet, outline: page);
    final artwork = _Artwork();
    final inside = (await tester.runAsync(
      () => bucketFill(drawing, const Offset(200, 120), coloring: artwork),
    ))!;
    expect(inside.containsPixel(200, 120), isTrue);
    // Past the white disc (radius 72), up to under the ring.
    expect(inside.containsPixel(200 + 76, 120), isTrue);
    expect(inside.containsPixel(200 + 100, 120), isFalse);
    expect(inside.containsPixel(10, 10), isFalse);

    // A tap on the line fills the nearest side; without the artwork, the
    // whole sheet.
    final outside = (await tester.runAsync(
      () => bucketFill(drawing, const Offset(10, 10), coloring: artwork),
    ))!;
    expect(outside.containsPixel(200, 120), isFalse);
    final unknown = (await tester.runAsync(
      () => bucketFill(drawing, const Offset(10, 10)),
    ))!;
    expect(unknown.containsPixel(200, 120), isTrue);
  });

  testWidgets('strokes, committed or live, stay under the outline, texts '
      'above it', (tester) async {
    final grain = PaperGrain.generate();
    final renderer = DrawingRenderer(grain: grain, coloring: _Artwork());
    final live = LiveStroke();
    addTearDown(() {
      renderer.dispose();
      live.dispose();
      grain.dispose();
    });
    // The ring crosses y = 120 at x = 105 .. 122 (left side).
    var drawing = const Drawing(sheetSize: sheet, outline: page);
    renderer.show(drawing);
    drawing = drawing.withElementAdded(stroke('a', 120));
    renderer.show(drawing);
    expect(renderer.lastUpdateWasRebuild, isFalse);
    live
      ..begin(tool: StrokeTool.marker, color: red, width: 20)
      ..add(const SheetPoint(114, 0))
      ..add(const SheetPoint(114, 240));
    await tester.pumpWidget(sheetWidget(renderer, live));
    var pixels = await capture(tester);
    expect(pixel(pixels, 114, 120), black);
    expect(pixel(pixels, 114, 60), red);
    expect(pixel(pixels, 50, 120), red);

    // A text over the line hides it; the cache is not touched.
    live.clear();
    drawing = drawing.withElementAdded(
      TextElement(
        id: 't',
        text: 'MM',
        color: red,
        fontSize: 60,
        transform: ElementTransform(translation: Offset(114, 120)),
      ),
    );
    expect(
      drawing.elements.last.bounds.contains(const Offset(114, 120)),
      isTrue,
    );
    renderer.show(drawing);
    expect(renderer.lastUpdateWasRebuild, isFalse);
    await tester.pump();
    pixels = await capture(tester);
    expect(pixel(pixels, 114, 120), red);

    // Without the cache the result is the same.
    renderer.cacheEnabled = false;
    await tester.pump();
    final uncached = await capture(tester);
    expect(pixel(uncached, 114, 120), red);
    expect(pixel(uncached, 114, 90), pixel(pixels, 114, 90));
  });

  testWidgets('a missing page shows a placeholder, thumbnails include the '
      'outline', (tester) async {
    final artwork = _Artwork();
    final grain = PaperGrain.generate();
    addTearDown(grain.dispose);
    Future<ByteData> render(Drawing drawing, ColoringArtwork? coloring) async {
      final picture = renderDrawing(
        drawing,
        grain,
        width: 400,
        coloring: coloring,
      );
      return (await tester.runAsync(() async {
        final image = await picture.toImage(400, 240);
        picture.dispose();
        final bytes = await image.toByteData();
        image.dispose();
        return bytes!;
      }))!;
    }

    final ring = await render(
      const Drawing(sheetSize: sheet, outline: page),
      artwork,
    );
    expect(pixel(ring, 114, 120), black);
    const missing = Drawing(
      sheetSize: sheet,
      outline: ColoringOutline(packId: 'test', pageId: 'gone'),
    );
    final placeholder = await render(missing, artwork);
    expect(pixel(placeholder, 200, 90), isNot(const Color(0xFFFFFFFF)));
    // Still loading: plain paper.
    final loading = await render(missing, null);
    expect(pixel(loading, 200, 90), const Color(0xFFFFFFFF));
  });
}
