import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pastello_engine/pastello_engine.dart';

const sheet = Size(400, 240);

StrokeElement line(double y, {ElementTransform? transform}) => StrokeElement(
  id: newElementId(),
  tool: StrokeTool.marker,
  color: const Color(0xFF2A9D3F),
  width: 12,
  points: [SheetPoint(40, y), SheetPoint(360, y, time: 100)],
  transform: transform ?? ElementTransform.identity,
);

TextElement text(String value, {ElementTransform? transform}) => TextElement(
  id: newElementId(),
  text: value,
  color: const Color(0xFF8E44AD),
  fontSize: 30,
  transform: transform ?? const ElementTransform(translation: Offset(200, 120)),
);

Map<String, Object?> viaText(Map<String, Object?> json) =>
    jsonDecode(jsonEncode(json)) as Map<String, Object?>;

void main() {
  group('ElementTransform', () {
    const t = ElementTransform(
      translation: Offset(100, 50),
      scale: 2,
      rotation: math.pi / 2,
    );

    test('maps local points to the sheet and back', () {
      expect(
        t.apply(const Offset(10, 0)),
        offsetMoreOrLessEquals(const Offset(100, 70)),
      );
      expect(
        t.invert(t.apply(const Offset(7, -3))),
        offsetMoreOrLessEquals(const Offset(7, -3)),
      );
      expect(ElementTransform.identity.isIdentity, isTrue);
      expect(t.isIdentity, isFalse);
    });

    test('matrix and apply agree', () {
      final m = t.matrix;
      const p = Offset(3, 4);
      final viaMatrix = Offset(
        m[0] * p.dx + m[4] * p.dy + m[12],
        m[1] * p.dx + m[5] * p.dy + m[13],
      );
      expect(viaMatrix, offsetMoreOrLessEquals(t.apply(p)));
    });

    test('bounds of a transformed rectangle', () {
      final r = t.applyToRect(const Rect.fromLTWH(0, 0, 10, 20));
      expect(r.width, closeTo(40, 1e-9));
      expect(r.height, closeTo(20, 1e-9));
    });

    test('equality and copyWith', () {
      expect(t.copyWith(scale: 3).scale, 3);
      expect(t.copyWith(), t);
      expect(t.hashCode, t.copyWith().hashCode);
      expect(t, isNot(ElementTransform.identity));
    });
  });

  group('TextElement', () {
    test('grows with its text and lines', () {
      final short = text('Ciao');
      final long = text('Ciao nonna!');
      final twoLines = text('Ciao\nnonna');
      expect(long.localBounds.width, greaterThan(short.localBounds.width));
      expect(
        twoLines.localBounds.height,
        greaterThan(short.localBounds.height),
      );
      // An empty text still has the size of a line.
      expect(text('').localBounds.height, greaterThan(0));
      expect(short.localBounds.center, Offset.zero);
      expect(short.erasable, isFalse);
    });

    test('is hit where it is drawn, rotated and scaled', () {
      final t = text(
        'Ciao',
        transform: const ElementTransform(
          translation: Offset(200, 120),
          scale: 2,
          rotation: math.pi / 2,
        ),
      );
      expect(t.contains(const Offset(200, 120)), isTrue);
      // Rotated by 90°: the text now extends vertically.
      expect(t.bounds.height, greaterThan(t.bounds.width));
      expect(t.contains(Offset(200 + t.bounds.width, 120)), isFalse);
      expect(
        t.contains(Offset(200 + t.bounds.width / 2 + 5, 120), slop: 20),
        isTrue,
      );
    });

    test('copies', () {
      final t = text('Ciao');
      expect(t.withId('x').id, 'x');
      expect(t.withId('x').text, 'Ciao');
      final moved = t.withTransform(const ElementTransform(scale: 2));
      expect(moved.transform.scale, 2);
      expect(t.copyWith(font: TextFont.fredoka).font, TextFont.fredoka);
    });
  });

  group('Drawing', () {
    final bottom = line(120);
    final top = text('Ciao');
    final drawing = const Drawing(
      sheetSize: sheet,
    ).withElementAdded(bottom).withElementAdded(top);

    test('finds the topmost element under a point', () {
      expect(drawing.elementAt(const Offset(200, 120)), top);
      expect(
        drawing.elementAt(
          const Offset(200, 120),
          where: (e) => e is StrokeElement,
        ),
        bottom,
      );
      expect(drawing.elementAt(const Offset(5, 5)), isNull);
      expect(drawing.elementById(top.id), top);
      expect(drawing.elementById('nope'), isNull);
    });

    test('replaces and inserts in place', () {
      final edited = top.copyWith(text: 'Ciao nonna');
      final replaced = drawing.withElementReplaced(edited);
      expect(replaced.elements.last, edited);
      expect(drawing.withElementInserted(0, edited).elements.first, edited);
    });
  });

  group('commands', () {
    test('update, delete and their undo', () {
      final t = text('Ciao');
      final stack = CommandStack(const Drawing(sheetSize: sheet))
        ..execute(AddElementCommand(line(50)))
        ..execute(AddElementCommand(t))
        ..execute(AddElementCommand(line(200)));
      final moved = t.withTransform(
        const ElementTransform(translation: Offset(10, 10)),
      );
      stack.execute(UpdateElementCommand(t, moved));
      expect(stack.drawing.elementById(t.id), moved);

      stack.execute(DeleteElementCommand.forDrawing(stack.drawing, t.id)!);
      expect(stack.drawing.elements, hasLength(2));
      stack.undo();
      // Back in its place in the z-order.
      expect(stack.drawing.elements[1], moved);
      stack.undo();
      expect(stack.drawing.elementById(t.id), t);
      expect(DeleteElementCommand.forDrawing(stack.drawing, 'nope'), isNull);
    });

    test('the eraser skips texts and follows moved strokes', () {
      const moveDown = ElementTransform(translation: Offset(0, 100));
      final moved = line(20, transform: moveDown);
      final t = text('Ciao');
      final drawing = const Drawing(
        sheetSize: sheet,
      ).withElementAdded(moved).withElementAdded(t);

      // The stroke is drawn at y = 20 + 100 on the sheet.
      final pass = [const SheetPoint(200, 100), const SheetPoint(200, 140)];
      final command = EraseCommand.forDrawing(drawing, pass, 10)!;
      expect(command.elementIds, {moved.id});
      final local = command.erasures[moved.id]!;
      expect(local.points.first.y, closeTo(0, 1e-9));
      expect(local.id, command.sheetErasure.id);

      final erased = command.apply(drawing);
      expect(
        (erased.elements.first as StrokeElement).erasures.single.id,
        local.id,
      );
      // Nothing to erase where there is only text.
      expect(
        EraseCommand.forDrawing(
          const Drawing(sheetSize: sheet).withElementAdded(t),
          pass,
          10,
        ),
        isNull,
      );
    });
  });

  group('serialization', () {
    test('texts and transforms round-trip', () {
      final t = text(
        'Ciao\nnonna!',
        transform: const ElementTransform(
          translation: Offset(120.5, 80),
          scale: 1.5,
          rotation: 0.3,
        ),
      ).copyWith(font: TextFont.playwrite);
      final stroke = line(30, transform: const ElementTransform(scale: 2));
      final drawing = const Drawing(
        sheetSize: sheet,
      ).withElementAdded(stroke).withElementAdded(t);
      final restored = drawingFromJson(viaText(drawingToJson(drawing)));
      final rt = restored.elements.last as TextElement;
      expect(rt.text, 'Ciao\nnonna!');
      expect(rt.font, TextFont.playwrite);
      expect(rt.color, t.color);
      expect(rt.transform.rotation, closeTo(0.3, 1e-9));
      expect(rt.transform.translation.dx, closeTo(120.5, 0.01));
      expect(restored.elements.first.transform.scale, 2);
    });

    test('every command round-trips', () {
      final t = text('Ciao');
      final s = line(120);
      final drawing = const Drawing(
        sheetSize: sheet,
      ).withElementAdded(s).withElementAdded(t);
      final commands = <DrawingCommand>[
        AddElementCommand(t),
        UpdateElementCommand(t, t.copyWith(text: 'Ciao!')),
        DeleteElementCommand(t, 1),
        EraseCommand.forDrawing(drawing, [
          const SheetPoint(100, 0),
          const SheetPoint(100, 240),
        ], 10)!,
        ClearCommand(drawing.elements),
      ];
      for (final command in commands) {
        final restored = commandFromJson(viaText(commandToJson(command)));
        expect(restored.runtimeType, command.runtimeType);
        expect(
          drawingToJson(restored.apply(drawing)),
          drawingToJson(command.apply(drawing)),
        );
      }
    });

    test('version 1 files and histories are still read', () {
      final s = line(120);
      final v1 = {
        'schemaVersion': 1,
        'sheet': {'width': 400, 'height': 240},
        'elements': [strokeToJson(s)],
      };
      expect(drawingFromJson(viaText(v1)).elements.single.id, s.id);

      final add = commandFromJson(
        viaText({'type': 'add', 'stroke': strokeToJson(s)}),
      );
      expect((add as AddElementCommand).element.id, s.id);

      final erase = commandFromJson(
        viaText({
          'type': 'erase',
          'erasure': {
            'id': 'e1',
            'width': 10,
            'points': [100, 0, 0.5, 0, 100, 240, 0.5, 10],
          },
          'strokeIds': [s.id],
        }),
      );
      final undo = erase.revert(
        erase.apply(const Drawing(sheetSize: sheet).withElementAdded(s)),
      );
      expect((undo.elements.single as StrokeElement).erasures, isEmpty);
    });

    test('unknown element types are rejected', () {
      expect(
        () => elementFromJson({'type': 'hologram'}),
        throwsA(isA<DrawingFormatException>()),
      );
      expect(() => elementToJson(_Alien()), throwsArgumentError);
    });
  });

  group('renderer', () {
    late PaperGrain grain;
    late DrawingRenderer renderer;
    setUp(() {
      grain = PaperGrain.generate();
      renderer = DrawingRenderer(grain: grain);
    });
    tearDown(() {
      renderer.dispose();
      grain.dispose();
    });

    test('floating elements leave the cache only while they float', () {
      final t = text('Ciao');
      final drawing = const Drawing(
        sheetSize: sheet,
      ).withElementAdded(line(50)).withElementAdded(t);
      renderer.show(drawing);

      final moved = t.withTransform(
        const ElementTransform(translation: Offset(100, 100)),
      );
      renderer.show(drawing, floating: [moved]);
      expect(renderer.lastUpdateWasRebuild, isTrue);

      // Following the finger: no cache work at all.
      final before = renderer.lastCacheUpdate;
      renderer.show(
        drawing,
        floating: [
          t.withTransform(
            const ElementTransform(translation: Offset(110, 100)),
          ),
        ],
      );
      expect(renderer.lastCacheUpdate, before);

      renderer.show(drawing.withElementReplaced(moved));
      expect(renderer.lastUpdateWasRebuild, isTrue);
    });

    test('erasing near a text rebuilds instead of covering it', () {
      final t = text('Ciao');
      final s = line(120);
      final drawing = const Drawing(
        sheetSize: sheet,
      ).withElementAdded(s).withElementAdded(t);
      renderer.show(drawing);

      final near = EraseCommand.forDrawing(drawing, [
        const SheetPoint(200, 100),
        const SheetPoint(200, 140),
      ], 10)!;
      renderer.showErased(near.apply(drawing), near.sheetErasure);
      expect(renderer.lastUpdateWasRebuild, isTrue);

      final far = EraseCommand.forDrawing(drawing, [
        const SheetPoint(50, 100),
        const SheetPoint(50, 140),
      ], 10)!;
      renderer.showErased(far.apply(drawing), far.sheetErasure);
      expect(renderer.lastUpdateWasRebuild, isFalse);
    });
  });

  testWidgets('texts, transforms and the eraser preview render as expected', (
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
    final drawing = const Drawing(sheetSize: sheet)
        .withElementAdded(line(60))
        .withElementAdded(
          text(
            'Ciao',
            transform: const ElementTransform(
              translation: Offset(200, 130),
              scale: 1.5,
              rotation: -0.25,
            ),
          ),
        )
        .withElementAdded(
          line(
            20,
            transform: const ElementTransform(
              translation: Offset(0, 180),
              scale: 0.5,
            ),
          ),
        );
    renderer.show(drawing);
    live.begin(tool: null, color: const Color(0xFF000000), width: 30);
    live
      ..add(const SheetPoint(200, 0))
      ..add(const SheetPoint(200, 240, time: 100));
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
      matchesGoldenFile('goldens/elements_eraser_preview.png'),
    );
  });
}

class _Alien extends DrawingElement {
  const _Alien() : super(id: 'alien');

  @override
  Rect get localBounds => Rect.zero;

  @override
  bool get erasable => false;

  @override
  DrawingElement withId(String id) => this;

  @override
  DrawingElement withTransform(ElementTransform transform) => this;
}
