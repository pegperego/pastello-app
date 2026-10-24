import 'dart:ui' as ui;

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:pastello_engine/pastello_engine.dart';

import '../data/bundled_packs.dart';
import '../domain/sticker_pack.dart';

/// Where packs are read from. Replaced in tests.
final assetBundleProvider = Provider<AssetBundle>((ref) => rootBundle);

/// The installed sticker packs.
final stickerPacksProvider = FutureProvider<List<StickerPack>>(
  (ref) => loadBundledPacks(ref.watch(assetBundleProvider)),
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
      final info = await vg.loadPicture(
        SvgAssetLoader(item.asset, assetBundle: bundle),
        null,
      );
      // Normalize every sticker to the same square.
      final recorder = ui.PictureRecorder();
      ui.Canvas(recorder)
        ..scale(PackArtwork.pictureSize / info.size.width)
        ..drawPicture(info.picture);
      info.picture.dispose();
      pictures[(pack.id, item.id)] = recorder.endRecording();
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
