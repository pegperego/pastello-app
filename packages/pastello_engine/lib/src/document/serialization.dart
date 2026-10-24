import 'dart:ui';

import '../commands/commands.dart';
import 'drawing.dart';
import 'sheet_point.dart';
import 'stroke_element.dart';
import 'stroke_tool.dart';

/// Version of the drawing file format written by this code.
///
/// Bump it when the format changes and add a step to [migrateDrawingJson].
/// The format is documented in `docs/file-format.md`.
const int drawingSchemaVersion = 1;

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
  'elements': [for (final e in drawing.elements) strokeToJson(e)],
};

/// Decodes a drawing written by [drawingToJson], migrating older versions.
Drawing drawingFromJson(Map<String, Object?> json) {
  final current = migrateDrawingJson(json);
  final sheet = _map(current['sheet']);
  return Drawing(
    sheetSize: Size(_double(sheet['width']), _double(sheet['height'])),
    elements: [
      for (final e in _list(current['elements'])) strokeFromJson(_map(e)),
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
  // No migrations yet: version 1 is the first format.
  return json;
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
  );
}

/// Encodes an undoable command, for the persisted history (ADR 0007).
Map<String, Object?> commandToJson(DrawingCommand command) => switch (command) {
  AddStrokeCommand(:final stroke) => {
    'type': 'add',
    'stroke': strokeToJson(stroke),
  },
  EraseCommand(:final erasure, :final strokeIds) => {
    'type': 'erase',
    'erasure': _erasureToJson(erasure),
    'strokeIds': strokeIds.toList(),
  },
  ClearCommand(:final removed) => {
    'type': 'clear',
    'removed': [for (final e in removed) strokeToJson(e)],
  },
  _ => throw ArgumentError('Cannot serialize ${command.runtimeType}'),
};

/// Decodes a command written by [commandToJson].
DrawingCommand commandFromJson(Map<String, Object?> json) =>
    switch (json['type']) {
      'add' => AddStrokeCommand(strokeFromJson(_map(json['stroke']))),
      'erase' => EraseCommand(_erasureFromJson(_map(json['erasure'])), {
        for (final id in _list(json['strokeIds'])) _string(id),
      }),
      'clear' => ClearCommand([
        for (final e in _list(json['removed'])) strokeFromJson(_map(e)),
      ]),
      final type => throw DrawingFormatException('Unknown command $type'),
    };

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
