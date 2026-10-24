import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui';

/// Position, scale and rotation of an element on the sheet (ADR 0004).
///
/// An element is described in its own local coordinates; the transform maps
/// them to the sheet: first scale, then rotate, then translate. Moving or
/// resizing an element only changes its transform, never its geometry.
class ElementTransform {
  /// Creates a transform.
  const ElementTransform({
    this.translation = Offset.zero,
    this.scale = 1,
    this.rotation = 0,
  });

  /// The transform that changes nothing.
  static const identity = ElementTransform();

  /// Where the local origin lands on the sheet, in sheet units.
  final Offset translation;

  /// Uniform scale factor.
  final double scale;

  /// Rotation in radians, clockwise on screen.
  final double rotation;

  /// Whether this is [identity].
  bool get isIdentity =>
      translation == Offset.zero && scale == 1 && rotation == 0;

  /// Maps a local point to the sheet.
  Offset apply(Offset local) {
    final c = math.cos(rotation), s = math.sin(rotation);
    final x = local.dx * scale, y = local.dy * scale;
    return Offset(x * c - y * s, x * s + y * c) + translation;
  }

  /// Maps a sheet point to local coordinates.
  Offset invert(Offset sheet) {
    final p = sheet - translation;
    final c = math.cos(rotation), s = math.sin(rotation);
    return Offset(p.dx * c + p.dy * s, -p.dx * s + p.dy * c) / scale;
  }

  /// A 4×4 column-major matrix for `Canvas.transform`.
  Float64List get matrix {
    final c = math.cos(rotation) * scale, s = math.sin(rotation) * scale;
    return Float64List.fromList([
      c, s, 0, 0, //
      -s, c, 0, 0,
      0, 0, 1, 0,
      translation.dx, translation.dy, 0, 1,
    ]);
  }

  /// The axis-aligned box, in sheet units, around [local] once transformed.
  Rect applyToRect(Rect local) {
    final corners = [
      apply(local.topLeft),
      apply(local.topRight),
      apply(local.bottomLeft),
      apply(local.bottomRight),
    ];
    return Rect.fromLTRB(
      corners.map((p) => p.dx).reduce(math.min),
      corners.map((p) => p.dy).reduce(math.min),
      corners.map((p) => p.dx).reduce(math.max),
      corners.map((p) => p.dy).reduce(math.max),
    );
  }

  /// This transform followed by [outer]: maps a local point first with
  /// this transform, then with [outer]. Used to move, resize or rotate
  /// several elements together.
  ElementTransform then(ElementTransform outer) => ElementTransform(
    translation: outer.apply(translation),
    scale: scale * outer.scale,
    rotation: rotation + outer.rotation,
  );

  /// Returns a copy with the given fields replaced.
  ElementTransform copyWith({
    Offset? translation,
    double? scale,
    double? rotation,
  }) => ElementTransform(
    translation: translation ?? this.translation,
    scale: scale ?? this.scale,
    rotation: rotation ?? this.rotation,
  );

  @override
  bool operator ==(Object other) =>
      other is ElementTransform &&
      other.translation == translation &&
      other.scale == scale &&
      other.rotation == rotation;

  @override
  int get hashCode => Object.hash(translation, scale, rotation);
}
