import 'dart:ui' as ui;

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:pastello_engine/pastello_engine.dart';

import '../data/bundled_packs.dart';
import '../domain/sticker_pack.dart';

/// Where packs are read from. Replaced in tests.
final assetBundleProvider = Provider<AssetBundle>((ref) => rootBundle);

/// The installed content packs, of every kind.
final contentPacksProvider = FutureProvider<List<StickerPack>>(
  (ref) => loadBundledPacks(ref.watch(assetBundleProvider)),
);

/// The installed sticker packs.
final stickerPacksProvider = FutureProvider<List<StickerPack>>(
  (ref) async => [
    for (final pack in await ref.watch(contentPacksProvider.future))
      if (pack.kind == PackKind.stickers) pack,
  ],
);

/// The artwork of every installed sticker, for the drawing engine.
///
/// SVGs are turned into pictures once, when the app needs them the first
/// time; drawing a sticker then costs the same as drawing a stroke.
final stickerArtworkProvider = FutureProvider<StickerArtwork>((ref) async {
  final packs = await ref.watch(stickerPacksProvider.future);
  final bundle = ref.watch(assetBundleProvider);
  final pictures = <(String, String), ui.Picture>{};
  for (final pack in packs) {
    for (final item in pack.items) {
      // Read the SVG text here and hand only the string to the loader: it
      // parses in a background isolate, and an asset bundle cannot be sent
      // to another isolate.
      final svg = await bundle.loadString(item.asset);
      final info = await vg.loadPicture(SvgStringLoader(svg), null);
      // Normalize every sticker to the same square. The source picture is
      // released only after recording, since the new one refers to it.
      final recorder = ui.PictureRecorder();
      ui.Canvas(recorder)
        ..scale(PackArtwork.pictureSize / info.size.width)
        ..drawPicture(info.picture);
      pictures[(pack.id, item.id)] = recorder.endRecording();
      info.picture.dispose();
    }
  }
  final artwork = PackArtwork(pictures);
  ref.onDispose(artwork.dispose);
  return artwork;
});

/// Sticker pictures by pack and item id.
class PackArtwork implements StickerArtwork {
  PackArtwork(this._pictures);

  /// Side of the square every sticker picture is drawn in.
  static const double pictureSize = 100;

  final Map<(String, String), ui.Picture> _pictures;

  @override
  double get size => pictureSize;

  @override
  ui.Picture? pictureFor(String packId, String elementId) =>
      _pictures[(packId, elementId)];

  /// Releases the pictures.
  void dispose() {
    for (final picture in _pictures.values) {
      picture.dispose();
    }
  }
}
