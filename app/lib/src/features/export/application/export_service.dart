import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'dart:ui' show Size;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gal/gal.dart';
import 'package:pastello_engine/pastello_engine.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:share_plus/share_plus.dart';

import '../../coloring/application/coloring_providers.dart';
import '../../stickers/application/stickers_providers.dart';

/// Gets drawings out of the app (ADR 0011). Every action goes through
/// Android: the app itself never sends anything anywhere.
abstract interface class ExportService {
  /// Saves a PNG to the device's photo gallery.
  Future<void> saveToGallery(Uint8List png, String name);

  /// Opens Android's share menu with a PNG. Only behind the parental gate.
  Future<void> share(Uint8List png, String name);

  /// Opens Android's print dialog with the drawing fitted on an A4 page.
  Future<void> print(Uint8List png, Size sheetSize, String name);
}

/// The real service, with the plugins approved in ADR 0014.
class PlatformExportService implements ExportService {
  const PlatformExportService();

  @override
  Future<void> saveToGallery(Uint8List png, String name) async {
    // From Android 10 no permission is needed to add an image (ADR 0011).
    if (!await Gal.hasAccess()) await Gal.requestAccess();
    await Gal.putImageBytes(png, name: name);
  }

  @override
  Future<void> share(Uint8List png, String name) => SharePlus.instance.share(
    ShareParams(
      files: [XFile.fromData(png, mimeType: 'image/png', name: '$name.png')],
      fileNameOverrides: ['$name.png'],
    ),
  );

  @override
  Future<void> print(Uint8List png, Size sheetSize, String name) =>
      Printing.layoutPdf(
        name: name,
        format: sheetSize.width >= sheetSize.height
            ? PdfPageFormat.a4.landscape
            : PdfPageFormat.a4,
        onLayout: (format) => printablePdf(png, format),
      );
}

/// A one-page PDF with the drawing fitted in the printable area, keeping its
/// proportions.
Future<Uint8List> printablePdf(Uint8List png, PdfPageFormat format) {
  final document = pw.Document(title: 'Pastello');
  document.addPage(
    pw.Page(
      pageFormat: format,
      margin: const pw.EdgeInsets.all(24),
      build: (_) => pw.Center(
        child: pw.Image(pw.MemoryImage(png), fit: pw.BoxFit.contain),
      ),
    ),
  );
  return document.save();
}

/// The export service. Replaced in tests.
final exportServiceProvider = Provider<ExportService>(
  (ref) => const PlatformExportService(),
);

/// Pixel width of an exported image: the screen's native resolution along
/// the sheet's orientation (ADR 0011).
int exportWidth(Size sheetSize, Size physicalScreen) {
  final scale = physicalScreen.longestSide / sheetSize.longestSide;
  return math.max(1, (sheetSize.width * scale).round());
}

/// Renders [drawing] as a PNG [width] pixels wide.
Future<Uint8List> renderPng(
  Drawing drawing, {
  required int width,
  StickerArtwork? stickers,
  ColoringArtwork? coloring,
}) async {
  final grain = PaperGrain.generate();
  final picture = renderDrawing(
    drawing,
    grain,
    width: width,
    stickers: stickers,
    coloring: coloring,
  );
  final image = await picture.toImage(width, renderedHeight(drawing, width));
  final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
  image.dispose();
  picture.dispose();
  grain.dispose();
  return bytes!.buffer.asUint8List();
}

/// Turns a drawing into the PNG used for every export. Replaced in widget
/// tests, where encoding images needs the real event loop.
final pngRendererProvider = Provider<Future<Uint8List> Function(Drawing)>((
  ref,
) {
  return (drawing) async {
    final view = ui.PlatformDispatcher.instance.implicitView;
    final screen = view?.physicalSize ?? const Size(2560, 1600);
    return renderPng(
      drawing,
      width: exportWidth(drawing.sheetSize, screen),
      stickers: ref.read(stickerArtworkProvider).value,
      coloring: await coloringFor(ref, drawing),
    );
  };
});

/// A file name for an exported drawing, like `pastello-20261025-1830`.
String exportName(DateTime now) {
  String two(int n) => n.toString().padLeft(2, '0');
  return 'pastello-${now.year}${two(now.month)}${two(now.day)}-'
      '${two(now.hour)}${two(now.minute)}';
}
