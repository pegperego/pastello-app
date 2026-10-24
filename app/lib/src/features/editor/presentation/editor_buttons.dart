import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../../app/tokens.dart';
import '../domain/editor_tool.dart';

/// A big tool button with its illustrated icon (G-05). The tip of the
/// drawing tools takes [color].
class ToolButton extends StatelessWidget {
  const ToolButton({
    super.key,
    required this.tool,
    required this.label,
    required this.color,
    required this.selected,
    required this.onPressed,
  });

  final EditorTool tool;
  final String label;
  final Color color;
  final bool selected;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(3),
      child: Semantics(
        button: true,
        selected: selected,
        label: label,
        excludeSemantics: true,
        child: Tooltip(
          message: label,
          child: Material(
            // The active state is shown by a thick border, not by color
            // alone (G-08).
            color: selected ? Tokens.coralLight : Colors.transparent,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: BorderSide(
                color: selected ? Tokens.coral : Colors.transparent,
                width: 3,
              ),
            ),
            child: InkWell(
              borderRadius: BorderRadius.circular(16),
              onTap: onPressed,
              child: SizedBox.square(
                dimension: 64,
                child: Padding(
                  padding: const EdgeInsets.all(8),
                  child: SvgPicture.asset(
                    tool.iconAsset,
                    theme: SvgTheme(currentColor: color),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// A round color swatch. The selected one gets a double ring (G-06).
class ColorSwatchButton extends StatelessWidget {
  const ColorSwatchButton({
    super.key,
    required this.color,
    required this.label,
    required this.selected,
    required this.onPressed,
    this.child,
  });

  final Color color;
  final String label;
  final bool selected;
  final VoidCallback onPressed;
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      label: label,
      excludeSemantics: true,
      child: GestureDetector(
        onTap: onPressed,
        child: SizedBox.square(
          dimension: Tokens.minTouchTarget,
          child: Center(
            child: Container(
              width: selected ? 36 : 42,
              height: selected ? 36 : 42,
              decoration: BoxDecoration(
                color: color,
                shape: BoxShape.circle,
                border: Border.all(color: Tokens.ink.withValues(alpha: 0.12)),
                boxShadow: selected
                    ? const [
                        BoxShadow(color: Tokens.paper, spreadRadius: 3),
                        BoxShadow(color: Tokens.ink, spreadRadius: 6),
                      ]
                    : null,
              ),
              child: child,
            ),
          ),
        ),
      ),
    );
  }
}

/// A width preset, drawn as a dot of that size in the selected color.
class WidthButton extends StatelessWidget {
  const WidthButton({
    super.key,
    required this.dotSize,
    required this.color,
    required this.label,
    required this.selected,
    required this.onPressed,
  });

  final double dotSize;
  final Color color;
  final String label;
  final bool selected;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      label: label,
      excludeSemantics: true,
      child: GestureDetector(
        onTap: onPressed,
        child: Container(
          width: 112,
          height: Tokens.minTouchTarget - 4,
          margin: const EdgeInsets.all(2),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: selected ? Tokens.skyLight : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: selected ? Tokens.sky : Colors.transparent,
              width: 2,
            ),
          ),
          child: Container(
            width: dotSize,
            height: dotSize,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
              border: Border.all(color: Tokens.ink.withValues(alpha: 0.2)),
            ),
          ),
        ),
      ),
    );
  }
}

/// A square action button for the top bar.
class ActionButton extends StatelessWidget {
  const ActionButton({
    super.key,
    required this.icon,
    required this.tooltip,
    required this.onPressed,
    this.active = false,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback? onPressed;
  final bool active;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: IconButton(
        tooltip: tooltip,
        onPressed: onPressed,
        iconSize: 28,
        constraints: const BoxConstraints.tightFor(
          width: Tokens.minTouchTarget,
          height: Tokens.minTouchTarget,
        ),
        style: IconButton.styleFrom(
          backgroundColor: active ? Tokens.sunLight : Tokens.sheet,
          foregroundColor: Tokens.ink,
          disabledForegroundColor: Tokens.border,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
            side: BorderSide(
              color: active ? Tokens.sun : Tokens.border,
              width: active ? 2 : 1,
            ),
          ),
        ),
        icon: Icon(icon),
      ),
    );
  }
}
