import 'package:flutter/material.dart';

import '../../../app/tokens.dart';
import '../domain/palette.dart';
import 'editor_buttons.dart';

/// Shows the "more colors" grid and returns the picked color, if any (F-05).
Future<Color?> showMoreColors(
  BuildContext context, {
  required Color selected,
  required String colorLabel,
}) {
  return showModalBottomSheet<Color>(
    context: context,
    backgroundColor: Tokens.paper,
    showDragHandle: true,
    builder: (context) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        child: Wrap(
          alignment: WrapAlignment.center,
          children: [
            for (final color in moreColors)
              ColorSwatchButton(
                color: color,
                label: colorLabel,
                selected: color == selected,
                onPressed: () => Navigator.of(context).pop(color),
              ),
          ],
        ),
      ),
    ),
  );
}
