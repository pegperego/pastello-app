import 'package:flutter/material.dart';
import 'package:pastello_engine/pastello_engine.dart';

import '../../../app/tokens.dart';

/// Shows the 4 fonts, each writing [sample], and returns the chosen one
/// (F-08).
Future<TextFont?> showFontSheet(
  BuildContext context, {
  required TextFont selected,
  required String sample,
}) => showModalBottomSheet<TextFont>(
  context: context,
  backgroundColor: Tokens.paper,
  showDragHandle: true,
  builder: (context) => SafeArea(
    child: Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: Wrap(
        alignment: WrapAlignment.center,
        spacing: 12,
        runSpacing: 12,
        children: [
          for (final font in TextFont.values)
            Semantics(
              button: true,
              selected: font == selected,
              label: font.family,
              child: InkWell(
                borderRadius: BorderRadius.circular(16),
                onTap: () => Navigator.of(context).pop(font),
                child: Container(
                  width: 180,
                  height: 96,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: Tokens.sheet,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: font == selected ? Tokens.coral : Tokens.border,
                      width: font == selected ? 3 : 1.5,
                    ),
                  ),
                  child: Text(
                    sample,
                    style: TextStyle(
                      fontFamily: font.family,
                      fontSize: 32,
                      fontWeight: FontWeight.values.firstWhere(
                        (w) => w.value == font.weight,
                      ),
                      fontVariations: [
                        FontVariation.weight(font.weight.toDouble()),
                      ],
                      color: Tokens.ink,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    ),
  ),
);
