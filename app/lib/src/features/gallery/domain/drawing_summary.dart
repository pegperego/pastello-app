/// What the gallery needs to know about a saved drawing.
class DrawingSummary {
  const DrawingSummary({required this.id, required this.updatedAt});

  /// Identifier, also the name of the drawing's folder (ADR 0010).
  final String id;

  /// Last change; the gallery shows the newest drawings first.
  final DateTime updatedAt;
}
