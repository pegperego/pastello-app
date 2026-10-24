import 'dart:convert';
import 'dart:ui' as ui;

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pastello_engine/pastello_engine.dart';

const sheet = Size(400, 240);

/// Artwork with a single sticker: a red circle.
class _Artwork implements StickerArtwork {
  _Artwork() {
    final recorder = ui.PictureRecorder();
    ui.Canvas(recorder).drawCircle(
      const Offset(50, 50),
      45,
      ui.Paint()..color = const Color(0xFFE63946),
    );
    _circle = recorder.endRecording();
  }

  late final ui.Picture _circle;

  @override
  double get size => 100;

  @override
  ui.Picture? pictureFor(String packId, String elementId) =>
      packId == 'animals' && elementId == 'dog' ? _circle : null;
}

void main() {
  const dog = StickerElement(
    id: 'a',
    packId: 'animals',
    elementId: 'dog',
    size: 100,
    transform: ElementTransform(translation: Offset(120, 120)),
  );
  const missing = StickerElement(
    id: 'b',
    packId: 'space',
    elementId: 'rocket',
    size: 100,
    transform: ElementTransform(translation: Offset(280, 120), rotation: 0.3),
  );

  test('a sticker is a square centered on its position', () {
    expect(dog.localBounds, const Rect.fromLTWH(-50, -50, 100, 100));
    expect(dog.contains(const Offset(160, 160)), isTrue);
    expect(dog.contains(const Offset(175, 120)), isFalse);
    expect(dog.erasable, isFalse);
    expect(dog.withId('c').elementId, 'dog');
    expect(dog.withTransform(ElementTransform.identity).packId, 'animals');
    expect(StickerElement.defaultSize, greaterThan(0));
  });

  test('stickers round-trip through JSON text', () {
    final drawing = const Drawing(
      sheetSize: sheet,
    ).withElementAdded(dog).withElementAdded(missing);
    final json =
        jsonDecode(jsonEncode(drawingToJson(drawing))) as Map<String, Object?>;
    expect(json['schemaVersion'], drawingSchemaVersion);
    final restored = drawingFromJson(json);
    final sticker = restored.elements.last as StickerElement;
    expect(sticker.packId, 'space');
    expect(sticker.elementId, 'rocket');
    expect(sticker.transform.rotation, closeTo(0.3, 1e-9));
  });

  test('loading the artwork later rebuilds the cache', () {
    final grain = PaperGrain.generate();
    final renderer = DrawingRenderer(grain: grain);
    addTearDown(() {
      renderer.dispose();
      grain.dispose();
    });
    renderer.show(const Drawing(sheetSize: sheet).withElementAdded(dog));
    final artwork = _Artwork();
    renderer.stickers = artwork;
    expect(renderer.lastUpdateWasRebuild, isTrue);
    expect(renderer.stickers, artwork);
    renderer.stickers = artwork;
  });

  testWidgets('stickers and the placeholder for a missing pack', (
    tester,
  ) async {
    final grain = PaperGrain.generate();
    final renderer = DrawingRenderer(grain: grain, stickers: _Artwork());
    final live = LiveStroke();
    addTearDown(() {
      renderer.dispose();
      live.dispose();
      grain.dispose();
    });
    renderer.show(
      const Drawing(
        sheetSize: sheet,
      ).withElementAdded(dog).withElementAdded(missing),
    );
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
      matchesGoldenFile('goldens/stickers.png'),
    );

    // Thumbnails use the same artwork.
    final picture = renderDrawing(
      const Drawing(sheetSize: sheet).withElementAdded(dog),
      grain,
      width: 200,
      stickers: _Artwork(),
    );
    picture.dispose();
  });
}
