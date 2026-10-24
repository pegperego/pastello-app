import 'package:flutter/foundation.dart';

/// A sticker in a pack.
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

/// A content pack of stickers, described by its `pack.json` (ADR 0018).
@immutable
class StickerPack {
  const StickerPack({
    required this.id,
    required this.version,
    required this.titles,
    required this.icon,
    required this.author,
    required this.license,
    required this.items,
  });

  /// Identifier, stored in drawings together with the item id.
  final String id;

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
