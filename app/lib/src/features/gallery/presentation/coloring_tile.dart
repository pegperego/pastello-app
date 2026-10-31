import 'package:flutter/material.dart';

import '../../../app/theme.dart';
import '../../../app/tokens.dart';

/// The tile next to the "+" that opens the coloring pages (F-19).
class ColoringTile extends StatelessWidget {
  const ColoringTile({super.key, required this.label, required this.onPressed});

  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: label,
      excludeSemantics: true,
      child: Material(
        color: Tokens.skyLight,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onPressed,
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: const Border(
                bottom: BorderSide(color: Tokens.sky, width: 4),
              ),
            ),
            padding: const EdgeInsets.all(8),
            // Smaller on a phone, where the tiles are small.
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.auto_stories_rounded,
                    color: Tokens.sky,
                    size: 56,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    label,
                    style: fredoka(20).copyWith(color: Tokens.sky),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
