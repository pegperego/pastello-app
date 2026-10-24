import 'package:flutter/material.dart';

import '../../../app/theme.dart';
import '../../../app/tokens.dart';
import '../../drawings/domain/drawing_summary.dart';

/// A drawing in the gallery or in the trash: thumbnail, date and a round
/// action button in the corner.
class DrawingTile extends StatelessWidget {
  const DrawingTile({
    super.key,
    required this.summary,
    required this.dateLabel,
    required this.semanticLabel,
    required this.actionIcon,
    required this.actionLabel,
    required this.onAction,
    this.onOpen,
  });

  final DrawingSummary summary;
  final String dateLabel;
  final String semanticLabel;
  final IconData actionIcon;
  final String actionLabel;
  final VoidCallback onAction;
  final VoidCallback? onOpen;

  @override
  Widget build(BuildContext context) {
    final thumbnail = summary.thumbnail;
    return Column(
      children: [
        Expanded(
          child: Stack(
            fit: StackFit.expand,
            children: [
              Semantics(
                button: onOpen != null,
                label: semanticLabel,
                excludeSemantics: true,
                child: Material(
                  color: Tokens.sheet,
                  elevation: 1,
                  shadowColor: Tokens.ink.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(16),
                  clipBehavior: Clip.antiAlias,
                  child: InkWell(
                    onTap: onOpen,
                    child: thumbnail == null
                        ? const SizedBox.expand()
                        : Image.memory(
                            thumbnail,
                            fit: BoxFit.contain,
                            gaplessPlayback: true,
                          ),
                  ),
                ),
              ),
              Positioned(
                right: 6,
                bottom: 6,
                child: IconButton(
                  tooltip: actionLabel,
                  onPressed: onAction,
                  constraints: const BoxConstraints.tightFor(
                    width: Tokens.minTouchTarget - 8,
                    height: Tokens.minTouchTarget - 8,
                  ),
                  style: IconButton.styleFrom(
                    backgroundColor: Tokens.sheet.withValues(alpha: 0.95),
                    foregroundColor: Tokens.ink,
                    side: const BorderSide(color: Tokens.border),
                  ),
                  icon: Icon(actionIcon),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 6),
        // Already part of the thumbnail's label for screen readers.
        ExcludeSemantics(
          child: Text(
            dateLabel,
            style: fredoka(
              15,
              weight: FontWeight.w500,
            ).copyWith(color: Tokens.graphite),
          ),
        ),
      ],
    );
  }
}
