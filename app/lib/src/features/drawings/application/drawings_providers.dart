import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pastello_engine/pastello_engine.dart';

import '../../stickers/application/stickers_providers.dart';
import '../data/drawing_repository.dart';
import '../domain/drawing_summary.dart';

/// Where drawings are stored. Provided in `main` (and by tests).
final drawingRepositoryProvider = Provider<DrawingRepository>(
  (ref) => throw UnimplementedError('Override drawingRepositoryProvider'),
);

/// Width of gallery thumbnails, in pixels.
const thumbnailWidth = 480;

/// Turns a drawing into a PNG thumbnail. Replaced in widget tests, where
/// encoding images needs the real event loop.
final thumbnailRendererProvider = Provider<Future<Uint8List> Function(Drawing)>(
  (ref) =>
      (drawing) => renderThumbnail(
        drawing,
        stickers: ref.read(stickerArtworkProvider).value,
      ),
);

/// Renders [drawing] as a PNG [thumbnailWidth] pixels wide.
Future<Uint8List> renderThumbnail(
  Drawing drawing, {
  StickerArtwork? stickers,
}) async {
  final grain = PaperGrain.generate();
  final picture = renderDrawing(
    drawing,
    grain,
    width: thumbnailWidth,
    stickers: stickers,
  );
  final image = await picture.toImage(
    thumbnailWidth,
    renderedHeight(drawing, thumbnailWidth),
  );
  final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
  image.dispose();
  picture.dispose();
  grain.dispose();
  return bytes!.buffer.asUint8List();
}

/// The gallery: saved drawings, newest first (F-01).
final drawingsProvider =
    AsyncNotifierProvider<DrawingsController, List<DrawingSummary>>(
      DrawingsController.new,
    );

/// Lists the drawings and applies the gallery actions (F-09).
class DrawingsController extends AsyncNotifier<List<DrawingSummary>> {
  bool _purged = false;

  DrawingRepository get _repository => ref.read(drawingRepositoryProvider);

  @override
  Future<List<DrawingSummary>> build() async {
    if (!_purged) {
      // Drawings older than 30 days leave the trash for good (ADR 0010).
      _purged = true;
      await _repository.purgeTrash();
    }
    return _repository.list();
  }

  /// Reloads the list, for example after closing the editor.
  Future<void> refresh() async {
    state = AsyncData(await _repository.list());
  }

  /// Duplicates a drawing (F-09).
  Future<void> duplicate(String id) async {
    await _repository.duplicate(id);
    await refresh();
  }

  /// Moves a drawing to the trash, without asking: it can be restored.
  Future<void> moveToTrash(String id) async {
    await _repository.moveToTrash(id);
    await refresh();
    ref.invalidate(trashProvider);
  }
}

/// Drawings in the trash.
final trashProvider =
    AsyncNotifierProvider<TrashController, List<DrawingSummary>>(
      TrashController.new,
    );

/// Restores drawings from the trash or empties it.
class TrashController extends AsyncNotifier<List<DrawingSummary>> {
  DrawingRepository get _repository => ref.read(drawingRepositoryProvider);

  @override
  Future<List<DrawingSummary>> build() => _repository.listTrash();

  /// Moves a drawing back to the gallery.
  Future<void> restore(String id) async {
    await _repository.restore(id);
    state = AsyncData(await _repository.listTrash());
    await ref.read(drawingsProvider.notifier).refresh();
  }

  /// Deletes everything in the trash. Only behind the parental gate.
  Future<void> empty() async {
    await _repository.emptyTrash();
    state = const AsyncData([]);
  }
}
