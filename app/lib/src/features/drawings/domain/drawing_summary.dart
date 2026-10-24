import 'package:flutter/foundation.dart';

/// What the gallery and the trash need to know about a saved drawing.
@immutable
class DrawingSummary {
  const DrawingSummary({
    required this.id,
    required this.updatedAt,
    this.deletedAt,
    this.thumbnail,
  });

  /// Identifier, also the name of the drawing's folder (ADR 0010).
  final String id;

  /// Last change; the gallery shows the newest drawings first.
  final DateTime updatedAt;

  /// When the drawing was moved to the trash, if it was.
  final DateTime? deletedAt;

  /// PNG thumbnail, if one was saved.
  final Uint8List? thumbnail;
}
