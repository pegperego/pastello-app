import 'dart:ui';

import '../commands/commands.dart';
import 'drawing.dart';
import 'drawing_element.dart';
import 'element_transform.dart';
import 'sheet_point.dart';
import 'shape_element.dart';
import 'sheet_background.dart';
import 'sticker_element.dart';
import 'stroke_element.dart';
import 'stroke_tool.dart';
import 'text_element.dart';

/// Version of the drawing file format written by this code.
///
/// Bump it when the format changes and add a step to [migrateDrawingJson].
/// The format is documented in `docs/file-format.md`.
const int drawingSchemaVersion = 6;

/// Thrown when a file cannot be read: it is malformed, or it was written by a
/// newer version of the app.
class DrawingFormatException implements Exception {
  /// Creates an exception with a [message].
  const DrawingFormatException(this.message);

  /// What went wrong.
  final String message;

  @override
  String toString() => 'DrawingFormatException: $message';
}

/// Encodes [drawing] as JSON.
Map<String, Object?> drawingToJson(Drawing drawing) => {
  'schemaVersion': drawingSchemaVersion,
  'sheet': {
    'width': _round(drawing.sheetSize.width),
    'height': _round(drawing.sheetSize.height),
  },
  if (!drawing.background.isDefault)
    'background': backgroundToJson(drawing.background),
  'elements': [for (final e in drawing.elements) elementToJson(e)],
};

/// Encodes a sheet background.
Map<String, Object?> backgroundToJson(SheetBackground background) => {
  'color': background.color.toARGB32(),
  'pattern': background.pattern.name,
};

/// Decodes a background written by [backgroundToJson]; unknown patterns
/// fall back to plain paper.
SheetBackground backgroundFromJson(Map<String, Object?> json) {
  final name = json['pattern'];
  return SheetBackground(
    color: Color(_int(json['color'])),
    pattern:
        BackgroundPattern.values.where((p) => p.name == name).firstOrNull ??
        BackgroundPattern.none,
  );
}

/// Decodes a drawing written by [drawingToJson], migrating older versions.
Drawing drawingFromJson(Map<String, Object?> json) {
  final current = migrateDrawingJson(json);
  final sheet = _map(current['sheet']);
  return Drawing(
    sheetSize: Size(_double(sheet['width']), _double(sheet['height'])),
    background: current['background'] == null
        ? SheetBackground.white
        : backgroundFromJson(_map(current['background'])),
    elements: [
      for (final e in _list(current['elements'])) elementFromJson(_map(e)),
    ],
  );
}

/// Brings [json] up to [drawingSchemaVersion].
///
/// Each future format change adds one step here, so files written by any
/// older version can still be opened.
Map<String, Object?> migrateDrawingJson(Map<String, Object?> json) {
  final version = json['schemaVersion'];
  if (version is! int || version < 1) {
    throw const DrawingFormatException('Missing or invalid schemaVersion');
  }
  if (version > drawingSchemaVersion) {
    throw DrawingFormatException(
      'Written by a newer version (schema $version, '
      'this app reads up to $drawingSchemaVersion)',
    );
  }
  // Version 2 added texts and element transforms, version 3 stickers,
  // version 4 shapes, version 5 backgrounds, version 6 the highlighter and
  // neon strokes: older files are valid newer files, nothing to convert.
  return json;
}

/// Encodes any element.
Map<String, Object?> elementToJson(DrawingElement element) => switch (element) {
  StrokeElement() => strokeToJson(element),
  TextElement() => textToJson(element),
  StickerElement() => stickerToJson(element),
  ShapeElement() => shapeToJson(element),
  _ => throw ArgumentError('Cannot serialize ${element.runtimeType}'),
};

/// Decodes an element written by [elementToJson].
DrawingElement elementFromJson(Map<String, Object?> json) =>
    switch (json['type']) {
      'stroke' => strokeFromJson(json),
      'text' => textFromJson(json),
      'sticker' => stickerFromJson(json),
      'shape' => shapeFromJson(json),
      final type => throw DrawingFormatException('Unknown element type $type'),
    };

/// Encodes a text.
Map<String, Object?> textToJson(TextElement text) => {
  'type': 'text',
  'id': text.id,
  'text': text.text,
  'color': text.color.toARGB32(),
  'font': text.font.name,
  'fontSize': _round(text.fontSize),
  ..._transformToJson(text.transform),
};

/// Decodes a text written by [textToJson].
TextElement textFromJson(Map<String, Object?> json) {
  final fontName = json['font'];
  return TextElement(
    id: _string(json['id']),
    text: _string(json['text']),
    color: Color(_int(json['color'])),
    font:
        TextFont.values.where((f) => f.name == fontName).firstOrNull ??
        TextFont.andika,
    fontSize: _double(json['fontSize']),
    transform: _transformFromJson(json['transform']),
  );
}

/// Encodes a sticker.
Map<String, Object?> stickerToJson(StickerElement sticker) => {
  'type': 'sticker',
  'id': sticker.id,
  'pack': sticker.packId,
  'item': sticker.elementId,
  'size': _round(sticker.size),
  ..._transformToJson(sticker.transform),
};

/// Decodes a sticker written by [stickerToJson].
StickerElement stickerFromJson(Map<String, Object?> json) => StickerElement(
  id: _string(json['id']),
  packId: _string(json['pack']),
  elementId: _string(json['item']),
  size: _double(json['size']),
  transform: _transformFromJson(json['transform']),
);

/// Encodes a shape.
Map<String, Object?> shapeToJson(ShapeElement shape) => {
  'type': 'shape',
  'id': shape.id,
  'kind': shape.kind.name,
  'extent': [_round(shape.extent.dx), _round(shape.extent.dy)],
  'color': shape.color.toARGB32(),
  'strokeWidth': _round(shape.strokeWidth),
  if (shape.filled) 'filled': true,
  ..._transformToJson(shape.transform),
};

/// Decodes a shape written by [shapeToJson].
ShapeElement shapeFromJson(Map<String, Object?> json) {
  final kindName = json['kind'];
  final kind = ShapeKind.values.where((k) => k.name == kindName).firstOrNull;
  if (kind == null) throw DrawingFormatException('Unknown shape $kindName');
  final extent = _list(json['extent']);
  return ShapeElement(
    id: _string(json['id']),
    kind: kind,
    extent: Offset(_double(extent[0]), _double(extent[1])),
    color: Color(_int(json['color'])),
    strokeWidth: _double(json['strokeWidth']),
    filled: json['filled'] == true,
    transform: _transformFromJson(json['transform']),
  );
}

Map<String, Object?> _transformToJson(ElementTransform t) => t.isIdentity
    ? const {}
    : {
        'transform': {
          'x': _round(t.translation.dx),
          'y': _round(t.translation.dy),
          'scale': t.scale,
          'rotation': t.rotation,
        },
      };

ElementTransform _transformFromJson(Object? json) {
  if (json == null) return ElementTransform.identity;
  final t = _map(json);
  return ElementTransform(
    translation: Offset(_double(t['x']), _double(t['y'])),
    scale: _double(t['scale']),
    rotation: _double(t['rotation']),
  );
}

/// Encodes a stroke.
///
/// Points are stored as a flat list `[x, y, pressure, time, ...]` rounded to
/// hundredths of a sheet unit, which keeps files small and is far below what
/// can be seen.
Map<String, Object?> strokeToJson(StrokeElement stroke) => {
  'type': 'stroke',
  'id': stroke.id,
  'tool': stroke.tool.name,
  'color': stroke.color.toARGB32(),
  'width': _round(stroke.width),
  'points': _pointsToJson(stroke.points),
  if (stroke.erasures.isNotEmpty)
    'erasures': [for (final e in stroke.erasures) _erasureToJson(e)],
  ..._transformToJson(stroke.transform),
};

/// Decodes a stroke written by [strokeToJson].
StrokeElement strokeFromJson(Map<String, Object?> json) {
  if (json['type'] != 'stroke') {
    throw DrawingFormatException('Unknown element type ${json['type']}');
  }
  final toolName = json['tool'];
  final tool = StrokeTool.values.where((t) => t.name == toolName).firstOrNull;
  if (tool == null) throw DrawingFormatException('Unknown tool $toolName');
  return StrokeElement(
    id: _string(json['id']),
    tool: tool,
    color: Color(_int(json['color'])),
    width: _double(json['width']),
    points: _pointsFromJson(json['points']),
    erasures: [
      for (final e in _list(json['erasures'] ?? const <Object?>[]))
        _erasureFromJson(_map(e)),
    ],
    transform: _transformFromJson(json['transform']),
  );
}

/// Encodes an undoable command, for the persisted history (ADR 0007).
Map<String, Object?> commandToJson(DrawingCommand command) => switch (command) {
  AddElementCommand(:final element) => {
    'type': 'add',
    'element': elementToJson(element),
  },
  UpdateElementCommand(:final before, :final after) => {
    'type': 'update',
    'before': elementToJson(before),
    'after': elementToJson(after),
  },
  DeleteElementCommand(:final element, :final index) => {
    'type': 'delete',
    'element': elementToJson(element),
    'index': index,
  },
  EraseCommand(:final sheetErasure, :final erasures) => {
    'type': 'erase',
    'sheetErasure': _erasureToJson(sheetErasure),
    'erasures': {
      for (final MapEntry(:key, :value) in erasures.entries)
        key: _erasureToJson(value),
    },
  },
  ChangeBackgroundCommand(:final before, :final after) => {
    'type': 'background',
    'before': backgroundToJson(before),
    'after': backgroundToJson(after),
  },
  BatchCommand(:final commands) => {
    'type': 'batch',
    'commands': [for (final c in commands) commandToJson(c)],
  },
  ClearCommand(:final removed) => {
    'type': 'clear',
    'removed': [for (final e in removed) elementToJson(e)],
  },
  _ => throw ArgumentError('Cannot serialize ${command.runtimeType}'),
};

/// Decodes a command written by [commandToJson], including the version 1
/// forms (`add` with a `stroke`, `erase` with one `erasure`).
DrawingCommand commandFromJson(Map<String, Object?> json) {
  switch (json['type']) {
    case 'add':
      return AddElementCommand(
        json.containsKey('stroke')
            ? strokeFromJson(_map(json['stroke']))
            : elementFromJson(_map(json['element'])),
      );
    case 'update':
      return UpdateElementCommand(
        elementFromJson(_map(json['before'])),
        elementFromJson(_map(json['after'])),
      );
    case 'delete':
      return DeleteElementCommand(
        elementFromJson(_map(json['element'])),
        _int(json['index']),
      );
    case 'erase' when json.containsKey('erasure'):
      final erasure = _erasureFromJson(_map(json['erasure']));
      return EraseCommand(erasure, {
        for (final id in _list(json['strokeIds'])) _string(id): erasure,
      });
    case 'erase':
      return EraseCommand(_erasureFromJson(_map(json['sheetErasure'])), {
        for (final MapEntry(:key, :value) in _map(json['erasures']).entries)
          key: _erasureFromJson(_map(value)),
      });
    case 'background':
      return ChangeBackgroundCommand(
        backgroundFromJson(_map(json['before'])),
        backgroundFromJson(_map(json['after'])),
      );
    case 'batch':
      return BatchCommand([
        for (final c in _list(json['commands'])) commandFromJson(_map(c)),
      ]);
    case 'clear':
      return ClearCommand([
        for (final e in _list(json['removed'])) elementFromJson(_map(e)),
      ]);
    case final type:
      throw DrawingFormatException('Unknown command $type');
  }
}

Map<String, Object?> _erasureToJson(Erasure erasure) => {
  'id': erasure.id,
  'width': _round(erasure.width),
  'points': _pointsToJson(erasure.points),
};

Erasure _erasureFromJson(Map<String, Object?> json) => Erasure(
  id: _string(json['id']),
  width: _double(json['width']),
  points: _pointsFromJson(json['points']),
);

List<num> _pointsToJson(List<SheetPoint> points) => [
  for (final p in points) ...[
    _round(p.x),
    _round(p.y),
    _round(p.pressure),
    p.time,
  ],
];

List<SheetPoint> _pointsFromJson(Object? json) {
  final values = _list(json);
  if (values.length % 4 != 0) {
    throw const DrawingFormatException('Points must come in groups of 4');
  }
  return [
    for (var i = 0; i < values.length; i += 4)
      SheetPoint(
        _double(values[i]),
        _double(values[i + 1]),
        pressure: _double(values[i + 2]),
        time: _int(values[i + 3]),
      ),
  ];
}

num _round(double value) {
  final rounded = (value * 100).roundToDouble() / 100;
  return rounded == rounded.truncateToDouble() ? rounded.toInt() : rounded;
}

Map<String, Object?> _map(Object? value) => value is Map<String, Object?>
    ? value
    : throw DrawingFormatException('Expected an object, got $value');

List<Object?> _list(Object? value) => value is List<Object?>
    ? value
    : throw DrawingFormatException('Expected a list, got $value');

String _string(Object? value) => value is String
    ? value
    : throw DrawingFormatException('Expected a string, got $value');

int _int(Object? value) => value is int
    ? value
    : throw DrawingFormatException('Expected an integer, got $value');

double _double(Object? value) => value is num
    ? value.toDouble()
    : throw DrawingFormatException('Expected a number, got $value');
