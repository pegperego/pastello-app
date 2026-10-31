import 'dart:convert';

import 'package:flutter/services.dart';

import '../domain/sticker_pack.dart';

/// Root of the content packs shipped with the app (ADR 0018).
const packsRoot = 'assets/packs';

/// Loads the content packs included in the app's assets, of every kind.
///
/// Later, downloaded packs will come from another source with the same
/// format (ADR 0018); this is the "bundled source" of v1.
Future<List<StickerPack>> loadBundledPacks(AssetBundle bundle) async {
  final index =
      jsonDecode(await bundle.loadString('$packsRoot/index.json'))
          as Map<String, Object?>;
  return [
    for (final id in (index['packs']! as List<Object?>).cast<String>())
      if (jsonDecode(await bundle.loadString('$packsRoot/$id/pack.json'))
              as Map<String, Object?>
          case final json when packKind(json) != null)
        parsePack(json, '$packsRoot/$id'),
  ];
}

/// The kind of the pack described by [json], `stickers` when not given, or
/// `null` for a kind this version of the app does not know: such a pack is
/// left out.
PackKind? packKind(Map<String, Object?> json) => switch (json['kind']) {
  null => PackKind.stickers,
  final String name => PackKind.values.where((k) => k.name == name).firstOrNull,
  _ => null,
};

/// Parses a `pack.json` found in [folder].
StickerPack parsePack(Map<String, Object?> json, String folder) {
  final items = [
    for (final item
        in (json['items']! as List<Object?>).cast<Map<String, Object?>>())
      StickerItem(
        id: item['id']! as String,
        asset: '$folder/${item['file']! as String}',
        name: item['name']! as String,
      ),
  ];
  final iconId = json['icon'] as String?;
  return StickerPack(
    id: json['id']! as String,
    kind: packKind(json)!,
    version: json['version']! as int,
    titles: (json['title']! as Map<String, Object?>).cast<String, String>(),
    icon: items.firstWhere((i) => i.id == iconId, orElse: () => items.first),
    author: json['author']! as String,
    license: json['license']! as String,
    items: items,
  );
}
