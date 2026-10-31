import 'dart:ui';

import 'package:flutter/painting.dart';

import '../document/drawing.dart';

/// The artwork of a coloring page: a picture drawn in a rectangle of [size]
/// with its top-left corner at the origin.
typedef ColoringPage = ({Picture picture, Size size});

/// Provides the artwork of coloring pages. Implemented by the app, which
/// loads the content packs; the engine only draws what it is given.
abstract interface class ColoringArtwork {
  /// The page [outline] refers to, or `null` if it is not installed.
  ColoringPage? pageFor(ColoringOutline outline);
}

/// Paints the outline of [drawing], if it has one (F-19, ADR 0022).
///
/// The page is fitted in the sheet with [ColoringOutline.placement]. When
/// [artwork] is available but does not have the page, a "?" placeholder is
/// drawn in the middle of the sheet; without [artwork] (still loading)
/// nothing is drawn.
void paintOutline(Canvas canvas, Drawing drawing, ColoringArtwork? artwork) {
  final outline = drawing.outline;
  if (outline == null || artwork == null) return;
  final page = artwork.pageFor(outline);
  if (page == null) {
    _paintPlaceholder(canvas, drawing.sheetSize);
    return;
  }
  final place = ColoringOutline.placement(page.size, drawing.sheetSize);
  if (place.isEmpty) return;
  canvas
    ..save()
    ..translate(place.left, place.top)
    ..scale(place.width / page.size.width)
    ..drawPicture(page.picture)
    ..restore();
}

/// A big "?" in a box, like the placeholder of a missing sticker.
void _paintPlaceholder(Canvas canvas, Size sheet) {
  final side = sheet.shortestSide * 0.3;
  final box = RRect.fromRectAndRadius(
    Rect.fromCenter(
      center: sheet.center(Offset.zero),
      width: side,
      height: side,
    ),
    Radius.circular(side * 0.15),
  );
  canvas
    ..drawRRect(box, Paint()..color = const Color(0xFFEDE7DD))
    ..drawRRect(
      box,
      Paint()
        ..color = const Color(0xFFB9AE9E)
        ..style = PaintingStyle.stroke
        ..strokeWidth = side * 0.03,
    );
  final question = TextPainter(
    text: TextSpan(
      text: '?',
      style: TextStyle(
        fontSize: side * 0.5,
        fontWeight: FontWeight.bold,
        color: const Color(0xFF8C8173),
      ),
    ),
    textDirection: TextDirection.ltr,
  )..layout();
  question.paint(
    canvas,
    box.center - Offset(question.width / 2, question.height / 2),
  );
}
