import 'package:flutter/foundation.dart';

/// An item of a pack: a sticker, or a coloring page.
@immutable
class StickerItem {
  const StickerItem({
    required this.id,
    required this.asset,
    required this.name,
  });

  /// Identifier within the pack, stored in drawings.
  final String id;

  /// Path of the SVG in the app's assets.
  final String asset;

  /// English name, for screen readers and credits.
  final String name;
}

/// What a content pack contains (ADR 0018).
enum PackKind {
  /// Stickers (F-11), in `stickers/`.
  stickers,

  /// Coloring pages (F-19), in `coloring/`.
  coloring,
}

/// A content pack, described by its `pack.json` (ADR 0018). Packs of
/// stickers and of coloring pages share the format.
@immutable
class StickerPack {
  const StickerPack({
    required this.id,
    this.kind = PackKind.stickers,
    required this.version,
    required this.titles,
    required this.icon,
    required this.author,
    required this.license,
    required this.items,
  });

  /// Identifier, stored in drawings together with the item id.
  final String id;

  final PackKind kind;

  final int version;

  /// Title by language code (`it`, `en`).
  final Map<String, String> titles;

  /// The item that represents the pack in the category tabs.
  final StickerItem icon;

  final String author;
  final String license;
  final List<StickerItem> items;

  /// The title in [languageCode], or in English.
  String title(String languageCode) =>
      titles[languageCode] ?? titles['en'] ?? id;
}
