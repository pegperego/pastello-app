import 'package:flutter/material.dart';
import 'package:pastello_engine/pastello_engine.dart';

import '../../../app/theme.dart';
import '../../../app/tokens.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../domain/palette.dart';
import 'editor_buttons.dart';
import 'labels.dart';

/// The paper chooser (F-02, F-10): patterns and paper colors. Every tap
/// changes the sheet right away, so the child sees the result.
Future<void> showPaperPanel(
  BuildContext context, {
  required SheetBackground Function() current,
  required ValueChanged<SheetBackground> onChanged,
}) => showModalBottomSheet<void>(
  context: context,
  backgroundColor: Tokens.paper,
  showDragHandle: true,
  // Taller than the default bottom sheet limit: let it size to its content.
  isScrollControlled: true,
  builder: (context) => _PaperPanel(current: current, onChanged: onChanged),
);

class _PaperPanel extends StatefulWidget {
  const _PaperPanel({required this.current, required this.onChanged});

  final SheetBackground Function() current;
  final ValueChanged<SheetBackground> onChanged;

  @override
  State<_PaperPanel> createState() => _PaperPanelState();
}

class _PaperPanelState extends State<_PaperPanel> {
  void _set(SheetBackground background) {
    widget.onChanged(background);
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final current = widget.current();
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(l10n.paper, style: fredoka(22)),
            const SizedBox(height: 12),
            Wrap(
              alignment: WrapAlignment.center,
              spacing: 10,
              runSpacing: 10,
              children: [
                for (final pattern in BackgroundPattern.values)
                  Semantics(
                    button: true,
                    selected: pattern == current.pattern,
                    label: patternLabel(l10n, pattern),
                    excludeSemantics: true,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(12),
                      onTap: () => _set(current.copyWith(pattern: pattern)),
                      child: Column(
                        children: [
                          Container(
                            width: 112,
                            height: 64,
                            clipBehavior: Clip.antiAlias,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: pattern == current.pattern
                                    ? Tokens.coral
                                    : Tokens.border,
                                width: pattern == current.pattern ? 3 : 1.5,
                              ),
                            ),
                            child: CustomPaint(
                              painter: _PaperPreview(
                                current.copyWith(pattern: pattern),
                              ),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(patternLabel(l10n, pattern)),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            Text(l10n.paperColor, style: fredoka(18, weight: FontWeight.w500)),
            Wrap(
              alignment: WrapAlignment.center,
              children: [
                for (final color in paperColors)
                  ColorSwatchButton(
                    color: color,
                    label: l10n.paperColor,
                    selected: color == current.color,
                    onPressed: () => _set(current.copyWith(color: color)),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// A small piece of paper, painted by the engine as the sheet will be.
class _PaperPreview extends CustomPainter {
  _PaperPreview(this.background);

  final SheetBackground background;

  @override
  void paint(Canvas canvas, Size size) {
    // Show the pattern at the scale of a real sheet (about 30 cm wide).
    const sheet = Size(1100, 700);
    canvas.scale(size.width / sheet.width * 3);
    background.paint(canvas, sheet);
  }

  @override
  bool shouldRepaint(_PaperPreview oldDelegate) =>
      oldDelegate.background != background;
}
