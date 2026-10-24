import 'package:flutter/painting.dart';

import 'drawing_element.dart';
import 'element_transform.dart';

/// The fonts available for texts (F-08). Each one is bundled by the app
/// under [family].
enum TextFont {
  /// Clear print, made for children learning to read. The default.
  andika('Andika'),

  /// Italian school cursive.
  playwrite('PlaywriteITModerna'),

  /// Round and bold, for titles.
  fredoka('Fredoka', weight: 600),

  /// Comic style, for speech bubbles.
  comicNeue('ComicNeue', weight: 700);

  const TextFont(this.family, {this.weight = 400});

  /// Font family name, as declared by the app.
  final String family;

  /// Weight used, also applied as a variation for variable fonts.
  final int weight;
}

/// Text written on the sheet (F-07).
///
/// The local origin is the center of the text box, so rotating and scaling
/// happen around the center. Lines are centered.
class TextElement extends DrawingElement {
  /// Creates a text.
  TextElement({
    required super.id,
    required this.text,
    required this.color,
    this.font = TextFont.andika,
    this.fontSize = defaultFontSize,
    super.transform,
  });

  /// Size of a new text, in sheet units: easy to read on a tablet.
  static const double defaultFontSize = 48;

  /// The text; lines are separated by `\n`.
  final String text;

  /// Text color.
  final Color color;

  /// Font.
  final TextFont font;

  /// Font size in sheet units, before [transform] scaling.
  final double fontSize;

  late final TextPainter _painter = layoutText(text, font, fontSize, color);

  /// Lays out a text the way [TextElement] paints it.
  static TextPainter layoutText(
    String text,
    TextFont font,
    double fontSize,
    Color color,
  ) => TextPainter(
    text: TextSpan(
      // An empty text still gets the height of a line, so a new text box
      // has a visible size.
      text: text.isEmpty ? ' ' : text,
      style: TextStyle(
        fontFamily: font.family,
        fontSize: fontSize,
        fontWeight: FontWeight.values.firstWhere(
          (w) => w.value == font.weight,
          orElse: () => FontWeight.normal,
        ),
        fontVariations: [FontVariation.weight(font.weight.toDouble())],
        color: color,
        height: 1.2,
      ),
    ),
    textAlign: TextAlign.center,
    textDirection: TextDirection.ltr,
  )..layout();

  @override
  Rect get localBounds => Rect.fromCenter(
    center: Offset.zero,
    width: _painter.width,
    height: _painter.height,
  ).inflate(fontSize * 0.15);

  @override
  bool get erasable => false;

  /// Paints the text, in local coordinates.
  void paintLocal(Canvas canvas) =>
      _painter.paint(canvas, Offset(-_painter.width / 2, -_painter.height / 2));

  /// Returns a copy with the given fields replaced.
  TextElement copyWith({
    String? text,
    Color? color,
    TextFont? font,
    double? fontSize,
    ElementTransform? transform,
    String? id,
  }) => TextElement(
    id: id ?? this.id,
    text: text ?? this.text,
    color: color ?? this.color,
    font: font ?? this.font,
    fontSize: fontSize ?? this.fontSize,
    transform: transform ?? this.transform,
  );

  @override
  TextElement withTransform(ElementTransform transform) =>
      copyWith(transform: transform);

  @override
  TextElement withId(String id) => copyWith(id: id);
}
