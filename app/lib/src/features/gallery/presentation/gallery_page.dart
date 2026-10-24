import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../editor/presentation/editor_page.dart';
import '../application/gallery_providers.dart';
import 'breathing_plus.dart';

/// The home screen: the child's drawings and a big "+" (F-01, F-09).
class GalleryPage extends ConsumerWidget {
  const GalleryPage({super.key});

  void _newDrawing(BuildContext context) {
    Navigator.of(
      context,
    ).push(MaterialPageRoute<void>(builder: (_) => const EditorPage()));
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final drawings = ref.watch(drawingsProvider);
    return Scaffold(
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 12),
              child: Text(l10n.appTitle, style: fredoka(30)),
            ),
            const Divider(height: 1.5),
            Expanded(
              child: GridView.builder(
                padding: const EdgeInsets.all(24),
                gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                  maxCrossAxisExtent: 260,
                  childAspectRatio: 16 / 10,
                  mainAxisSpacing: 20,
                  crossAxisSpacing: 20,
                ),
                // The "+" is always the first tile; thumbnails come in #6.
                itemCount: 1 + drawings.length,
                itemBuilder: (context, index) => index == 0
                    ? BreathingPlus(
                        semanticLabel: l10n.newDrawing,
                        onPressed: () => _newDrawing(context),
                      )
                    : const SizedBox.shrink(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
