import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:pastello_engine/pastello_engine.dart';

import '../../../app/theme.dart';
import '../../../app/tokens.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../stickers/domain/sticker_pack.dart';
import '../application/coloring_providers.dart';

/// The coloring pages (F-19): one tab per pack, each a grid of pages.
/// Returns the chosen page.
class ColoringPickerPage extends ConsumerWidget {
  const ColoringPickerPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final languageCode = Localizations.localeOf(context).languageCode;
    final packs = ref.watch(coloringPacksProvider).value ?? const [];
    return DefaultTabController(
      length: packs.length,
      child: Scaffold(
        appBar: AppBar(
          backgroundColor: Tokens.paper,
          title: Text(l10n.coloringPages, style: fredoka(26)),
          // With a single pack, its tab would only take room.
          bottom: packs.length < 2
              ? null
              : TabBar(
                  isScrollable: true,
                  tabAlignment: TabAlignment.center,
                  indicatorColor: Tokens.coral,
                  indicatorWeight: 4,
                  labelStyle: fredoka(20),
                  tabs: [
                    for (final pack in packs)
                      Tab(height: 56, text: pack.title(languageCode)),
                  ],
                ),
        ),
        body: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
              child: Text(
                l10n.chooseColoringPage,
                style: fredoka(20, weight: FontWeight.w400),
              ),
            ),
            Expanded(
              child: TabBarView(
                children: [for (final pack in packs) _PageGrid(pack)],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PageGrid extends StatelessWidget {
  const _PageGrid(this.pack);

  final StickerPack pack;

  @override
  Widget build(BuildContext context) {
    return GridView.extent(
      padding: const EdgeInsets.all(24),
      maxCrossAxisExtent: 240,
      mainAxisSpacing: 20,
      crossAxisSpacing: 20,
      children: [
        for (final item in pack.items)
          Semantics(
            button: true,
            label: item.name,
            excludeSemantics: true,
            child: Material(
              color: Tokens.sheet,
              borderRadius: BorderRadius.circular(16),
              child: InkWell(
                borderRadius: BorderRadius.circular(16),
                onTap: () => Navigator.of(
                  context,
                ).pop(ColoringOutline(packId: pack.id, pageId: item.id)),
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Tokens.border, width: 2),
                  ),
                  padding: const EdgeInsets.all(16),
                  child: SvgPicture.asset(item.asset),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
