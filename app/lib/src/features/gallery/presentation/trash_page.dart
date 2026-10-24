import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme.dart';
import '../../../app/tokens.dart';
import '../../../core/clock.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../drawings/application/drawings_providers.dart';
import '../../parents/presentation/parental_gate.dart';
import 'drawing_tile.dart';
import 'relative_date.dart';

/// Deleted drawings: restoring is free, emptying the trash is for grown-ups
/// (F-09, ADR 0010).
class TrashPage extends ConsumerWidget {
  const TrashPage({super.key});

  Future<void> _empty(BuildContext context, WidgetRef ref) async {
    if (await showParentalGate(context)) {
      await ref.read(trashProvider.notifier).empty();
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final locale = Localizations.localeOf(context).toLanguageTag();
    final now = ref.watch(clockProvider)();
    final trash = ref.watch(trashProvider).value ?? const [];
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Tokens.paper,
        title: Text(l10n.trash, style: fredoka(26)),
        actions: [
          if (trash.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(right: 12),
              child: TextButton.icon(
                onPressed: () => _empty(context, ref),
                icon: const Icon(Icons.delete_forever_rounded),
                label: Text(l10n.emptyTrash),
                style: TextButton.styleFrom(foregroundColor: Tokens.raspberry),
              ),
            ),
        ],
      ),
      body: trash.isEmpty
          ? Center(child: Text(l10n.trashIsEmpty, style: fredoka(22)))
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 8, 24, 0),
                  child: Text(l10n.trashRetention),
                ),
                Expanded(
                  child: GridView.builder(
                    padding: const EdgeInsets.all(24),
                    gridDelegate:
                        const SliverGridDelegateWithMaxCrossAxisExtent(
                          maxCrossAxisExtent: 280,
                          childAspectRatio: 16 / 12,
                          mainAxisSpacing: 20,
                          crossAxisSpacing: 20,
                        ),
                    itemCount: trash.length,
                    itemBuilder: (context, index) {
                      final summary = trash[index];
                      final date = relativeDate(
                        l10n,
                        locale,
                        summary.updatedAt,
                        now,
                      );
                      return DrawingTile(
                        key: ValueKey(summary.id),
                        summary: summary,
                        dateLabel: date,
                        semanticLabel: l10n.drawingFrom(date),
                        actionIcon: Icons.restore_from_trash_rounded,
                        actionLabel: l10n.restore,
                        onAction: () => ref
                            .read(trashProvider.notifier)
                            .restore(summary.id),
                      );
                    },
                  ),
                ),
              ],
            ),
    );
  }
}
