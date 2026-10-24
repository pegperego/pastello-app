import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../../app/theme.dart';
import '../../../app/tokens.dart';
import '../domain/sticker_pack.dart';

/// The sticker panel (F-11): one tab per category, each showing its
/// stickers. Returns the chosen pack and item ids.
Future<(String, String)?> showStickerPanel(
  BuildContext context, {
  required List<StickerPack> packs,
  required String languageCode,
  required String title,
  String? selectedPackId,
}) {
  final initial = packs.indexWhere((p) => p.id == selectedPackId);
  return showModalBottomSheet<(String, String)>(
    context: context,
    backgroundColor: Tokens.paper,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (context) => SizedBox(
      height: MediaQuery.sizeOf(context).height * 0.6,
      child: DefaultTabController(
        length: packs.length,
        initialIndex: initial < 0 ? 0 : initial,
        child: Column(
          children: [
            Text(title, style: fredoka(22)),
            TabBar(
              isScrollable: true,
              tabAlignment: TabAlignment.center,
              indicatorColor: Tokens.coral,
              indicatorWeight: 4,
              tabs: [
                for (final pack in packs)
                  Tab(
                    height: 64,
                    child: Semantics(
                      label: pack.title(languageCode),
                      child: SvgPicture.asset(pack.icon.asset, width: 40),
                    ),
                  ),
              ],
            ),
            Expanded(
              child: TabBarView(
                children: [
                  for (final pack in packs)
                    GridView.extent(
                      padding: const EdgeInsets.all(16),
                      maxCrossAxisExtent: 88,
                      mainAxisSpacing: 8,
                      crossAxisSpacing: 8,
                      children: [
                        for (final item in pack.items)
                          Semantics(
                            button: true,
                            label: item.name,
                            excludeSemantics: true,
                            child: InkWell(
                              borderRadius: BorderRadius.circular(16),
                              onTap: () =>
                                  Navigator.of(context).pop((pack.id, item.id)),
                              child: Padding(
                                padding: const EdgeInsets.all(8),
                                child: SvgPicture.asset(item.asset),
                              ),
                            ),
                          ),
                      ],
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
