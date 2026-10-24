import 'package:flutter/material.dart';
import 'package:pastello_engine/pastello_engine.dart';

import '../../../app/theme.dart';
import '../../../app/tokens.dart';
import '../../../l10n/generated/app_localizations.dart';
import 'labels.dart';

/// The shapes panel (F-12): the 7 shapes and the outline / filled switch.
/// Returns the chosen shape and whether it is filled.
Future<(ShapeKind, bool)?> showShapePanel(
  BuildContext context, {
  required ShapeKind selected,
  required bool filled,
  required Color color,
}) => showModalBottomSheet<(ShapeKind, bool)>(
  context: context,
  backgroundColor: Tokens.paper,
  showDragHandle: true,
  builder: (context) =>
      _ShapePanel(selected: selected, filled: filled, color: color),
);

class _ShapePanel extends StatefulWidget {
  const _ShapePanel({
    required this.selected,
    required this.filled,
    required this.color,
  });

  final ShapeKind selected;
  final bool filled;
  final Color color;

  @override
  State<_ShapePanel> createState() => _ShapePanelState();
}

class _ShapePanelState extends State<_ShapePanel> {
  late bool _filled = widget.filled;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(l10n.chooseShape, style: fredoka(22)),
            const SizedBox(height: 12),
            SegmentedButton<bool>(
              segments: [
                ButtonSegment(
                  value: false,
                  icon: const Icon(Icons.circle_outlined),
                  label: Text(l10n.shapeOutline),
                ),
                ButtonSegment(
                  value: true,
                  icon: const Icon(Icons.circle),
                  label: Text(l10n.shapeFilled),
                ),
              ],
              selected: {_filled},
              onSelectionChanged: (value) =>
                  setState(() => _filled = value.single),
            ),
            const SizedBox(height: 16),
            Wrap(
              alignment: WrapAlignment.center,
              spacing: 10,
              runSpacing: 10,
              children: [
                for (final kind in ShapeKind.values)
                  Semantics(
                    button: true,
                    selected: kind == widget.selected,
                    label: shapeLabel(l10n, kind),
                    excludeSemantics: true,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(16),
                      onTap: () => Navigator.of(context).pop((kind, _filled)),
                      child: Container(
                        width: 88,
                        height: 88,
                        decoration: BoxDecoration(
                          color: Tokens.sheet,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: kind == widget.selected
                                ? Tokens.coral
                                : Tokens.border,
                            width: kind == widget.selected ? 3 : 1.5,
                          ),
                        ),
                        child: CustomPaint(
                          painter: _ShapePreview(
                            kind,
                            filled: _filled,
                            color: widget.color,
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Draws a shape with the engine, exactly as it will look on the sheet.
class _ShapePreview extends CustomPainter {
  _ShapePreview(this.kind, {required this.filled, required this.color});

  final ShapeKind kind;
  final bool filled;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final (shape, _) = shapeFromDrag(
      id: 'preview',
      kind: kind,
      start: const Offset(22, 22),
      // Lines go diagonally; figures fill the square.
      end: Offset(size.width - 22, size.height - (kind.isLine ? 30 : 22)),
      color: color,
      strokeWidth: 5,
      filled: filled,
    );
    canvas
      ..save()
      ..transform(shape.transform.matrix);
    shape.paintLocal(canvas);
    canvas.restore();
  }

  @override
  bool shouldRepaint(_ShapePreview oldDelegate) =>
      oldDelegate.kind != kind ||
      oldDelegate.filled != filled ||
      oldDelegate.color != color;
}
