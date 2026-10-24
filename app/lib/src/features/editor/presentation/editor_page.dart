import 'package:flutter/material.dart';

import '../../../app/tokens.dart';
import '../../../l10n/generated/app_localizations.dart';

/// The editor (F-03). For now only the frame: the action bar with the way
/// back to the gallery and an empty sheet. Tools arrive with issues #7–#9.
class EditorPage extends StatelessWidget {
  const EditorPage({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            SizedBox(
              height: 64,
              child: Row(
                children: [
                  const SizedBox(width: 12),
                  IconButton.filledTonal(
                    tooltip: l10n.backToGallery,
                    iconSize: 28,
                    constraints: const BoxConstraints.tightFor(
                      width: Tokens.minTouchTarget,
                      height: Tokens.minTouchTarget,
                    ),
                    style: IconButton.styleFrom(
                      backgroundColor: Tokens.sheet,
                      foregroundColor: Tokens.ink,
                    ),
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.home_rounded),
                  ),
                ],
              ),
            ),
            const Divider(height: 1.5),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Semantics(
                  label: l10n.sheet,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: Tokens.sheet,
                      border: Border.all(color: Tokens.border, width: 1.5),
                    ),
                    child: const SizedBox.expand(),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
