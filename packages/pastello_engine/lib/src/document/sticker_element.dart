import 'dart:ui';

import 'drawing_element.dart';
import 'element_transform.dart';

/// A sticker from a content pack (F-11, ADR 0018).
///
/// The drawing only stores which sticker it is (`packId`/`elementId`); the
/// artwork comes from the installed pack, so a drawing stays valid when a
/// pack is updated. A sticker whose pack is missing is shown as a "?".
class StickerElement extends DrawingElement {
  /// Creates a sticker.
  const StickerElement({
    required super.id,
    required this.packId,
    required this.elementId,
    this.size = defaultSize,
    super.transform,
  });

  /// Side of a new sticker, in sheet units.
  static const double defaultSize = 160;

  /// The content pack.
  final String packId;

  /// The sticker within the pack.
  final String elementId;

  /// Side of the sticker's square, in sheet units, before scaling.
  final double size;

  @override
  Rect get localBounds =>
      Rect.fromCenter(center: Offset.zero, width: size, height: size);

  @override
  bool get erasable => false;

  @override
  StickerElement withTransform(ElementTransform transform) => StickerElement(
    id: id,
    packId: packId,
    elementId: elementId,
    size: size,
    transform: transform,
  );

  @override
  StickerElement withId(String id) => StickerElement(
    id: id,
    packId: packId,
    elementId: elementId,
    size: size,
    transform: transform,
  );
}

/// Provides the artwork of stickers. Implemented by the app, which loads the
/// content packs; the engine only draws what it is given.
abstract interface class StickerArtwork {
  /// The artwork of a sticker, drawn in a [size] × [size] square with its
  /// top-left corner at the origin, or `null` if it is not installed.
  Picture? pictureFor(String packId, String elementId);

  /// Size of the square the pictures are drawn in.
  double get size;
}
