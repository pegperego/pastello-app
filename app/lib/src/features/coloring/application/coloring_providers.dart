import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:pastello_engine/pastello_engine.dart';

import '../../stickers/application/stickers_providers.dart';
import '../../stickers/domain/sticker_pack.dart';

/// The installed packs of coloring pages (F-19).
final coloringPacksProvider = FutureProvider<List<StickerPack>>(
  (ref) async => [
    for (final pack in await ref.watch(contentPacksProvider.future))
      if (pack.kind == PackKind.coloring) pack,
  ],
);

/// The artwork of every installed coloring page, for the drawing engine.
///
/// Like stickers, SVGs are turned into pictures once; unlike stickers, each
/// page keeps its own size, so it can be fitted to the sheet (ADR 0022).
final coloringArtworkProvider = FutureProvider<ColoringArtwork>((ref) async {
  final packs = await ref.watch(coloringPacksProvider.future);
  final bundle = ref.watch(assetBundleProvider);
  final pages = <ColoringOutline, ColoringPage>{};
  for (final pack in packs) {
    for (final item in pack.items) {
      // Only the string goes to the loader, which parses in the background.
      final svg = await bundle.loadString(item.asset);
      final info = await vg.loadPicture(SvgStringLoader(svg), null);
      pages[ColoringOutline(packId: pack.id, pageId: item.id)] = (
        picture: info.picture,
        size: info.size,
      );
    }
  }
  final artwork = ColoringPages(pages);
  ref.onDispose(artwork.dispose);
  return artwork;
});

/// Coloring page pictures by pack and page id.
class ColoringPages implements ColoringArtwork {
  ColoringPages(this._pages);

  final Map<ColoringOutline, ColoringPage> _pages;

  @override
  ColoringPage? pageFor(ColoringOutline outline) => _pages[outline];

  /// Releases the pictures.
  void dispose() {
    for (final page in _pages.values) {
      page.picture.dispose();
    }
  }
}

/// The artwork [drawing] needs for its outline, waiting for it to load:
/// `null` when the drawing has no outline.
Future<ColoringArtwork?> coloringFor(Ref ref, Drawing drawing) async =>
    drawing.outline == null
    ? null
    : await ref.read(coloringArtworkProvider.future);
