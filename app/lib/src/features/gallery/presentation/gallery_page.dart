import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme.dart';
import '../../../app/tokens.dart';
import '../../../core/clock.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../drawings/application/drawings_providers.dart';
import '../../drawings/domain/drawing_summary.dart';
import '../../editor/presentation/editor_page.dart';
import 'breathing_plus.dart';
import 'drawing_tile.dart';
import 'relative_date.dart';
import 'trash_page.dart';
import '../../export/application/export_actions.dart';
import '../../parents/presentation/parental_gate.dart';
import '../../parents/presentation/parents_page.dart';

/// The home screen: a big "+" and the child's drawings, newest first
/// (F-01, F-09).
class GalleryPage extends ConsumerWidget {
  const GalleryPage({super.key});

  Future<void> _openEditor(
    BuildContext context,
    WidgetRef ref, {
    String? drawingId,
  }) async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => EditorPage(drawingId: drawingId)),
    );
    await ref.read(drawingsProvider.notifier).refresh();
  }

  Future<void> _export(
    BuildContext context,
    WidgetRef ref,
    String id,
    ExportAction action,
  ) async {
    final saved = await ref.read(drawingRepositoryProvider).load(id);
    if (saved == null || !context.mounted) return;
    await runExport(context, ref, saved.drawing, action);
  }

  Future<void> _showOptions(
    BuildContext context,
    WidgetRef ref,
    DrawingSummary summary,
  ) async {
    final l10n = AppLocalizations.of(context);
    final galleryContext = context;
    final drawings = ref.read(drawingsProvider.notifier);
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Tokens.paper,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
          child: Wrap(
            alignment: WrapAlignment.center,
            spacing: 16,
            children: [
              _BigAction(
                icon: Icons.content_copy_rounded,
                label: l10n.duplicate,
                onPressed: () {
                  Navigator.of(context).pop();
                  drawings.duplicate(summary.id);
                },
              ),
              for (final (icon, label, action) in [
                (
                  Icons.photo_library_rounded,
                  l10n.saveToGallery,
                  ExportAction.save,
                ),
                (Icons.print_rounded, l10n.print, ExportAction.print),
                (Icons.share_rounded, l10n.share, ExportAction.share),
              ])
                _BigAction(
                  icon: icon,
                  label: label,
                  onPressed: () {
                    Navigator.of(context).pop();
                    _export(galleryContext, ref, summary.id, action);
                  },
                ),
              _BigAction(
                icon: Icons.delete_rounded,
                label: l10n.delete,
                color: Tokens.raspberry,
                // No confirmation: the drawing goes to the trash and can
                // be restored (F-09).
                onPressed: () {
                  Navigator.of(context).pop();
                  drawings.moveToTrash(summary.id);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final locale = Localizations.localeOf(context).toLanguageTag();
    final now = ref.watch(clockProvider)();
    final drawings = ref.watch(drawingsProvider).value ?? const [];
    return Scaffold(
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 12, 16, 8),
              child: Row(
                children: [
                  Expanded(child: Text(l10n.appTitle, style: fredoka(30))),
                  IconButton(
                    tooltip: l10n.parents,
                    iconSize: 28,
                    constraints: const BoxConstraints.tightFor(
                      width: Tokens.minTouchTarget,
                      height: Tokens.minTouchTarget,
                    ),
                    style: IconButton.styleFrom(
                      backgroundColor: Tokens.sheet,
                      foregroundColor: Tokens.ink,
                      side: const BorderSide(color: Tokens.border),
                    ),
                    // Grown-ups only: the gate is asked every time (F-14).
                    onPressed: () async {
                      if (await showParentalGate(context) && context.mounted) {
                        await Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) => const ParentsPage(),
                          ),
                        );
                      }
                    },
                    icon: const Icon(Icons.family_restroom_rounded),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    tooltip: l10n.trash,
                    iconSize: 28,
                    constraints: const BoxConstraints.tightFor(
                      width: Tokens.minTouchTarget,
                      height: Tokens.minTouchTarget,
                    ),
                    style: IconButton.styleFrom(
                      backgroundColor: Tokens.sheet,
                      foregroundColor: Tokens.ink,
                      side: const BorderSide(color: Tokens.border),
                    ),
                    onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => const TrashPage(),
                      ),
                    ),
                    icon: const Icon(Icons.delete_outline_rounded),
                  ),
                ],
              ),
            ),
            const Divider(height: 1.5),
            Expanded(
              child: GridView.builder(
                padding: const EdgeInsets.all(24),
                gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                  maxCrossAxisExtent: 280,
                  childAspectRatio: 16 / 12,
                  mainAxisSpacing: 20,
                  crossAxisSpacing: 20,
                ),
                // The "+" is always the first tile.
                itemCount: 1 + drawings.length,
                itemBuilder: (context, index) {
                  if (index == 0) {
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 26),
                      child: BreathingPlus(
                        semanticLabel: l10n.newDrawing,
                        onPressed: () => _openEditor(context, ref),
                      ),
                    );
                  }
                  final summary = drawings[index - 1];
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
                    actionIcon: Icons.more_horiz_rounded,
                    actionLabel: l10n.drawingOptions,
                    onAction: () => _showOptions(context, ref, summary),
                    onOpen: () =>
                        _openEditor(context, ref, drawingId: summary.id),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// A big icon with a label, for the drawing options sheet.
class _BigAction extends StatelessWidget {
  const _BigAction({
    required this.icon,
    required this.label,
    required this.onPressed,
    this.color = Tokens.ink,
  });

  final IconData icon;
  final String label;
  final VoidCallback onPressed;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: onPressed,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 48, color: color),
            const SizedBox(height: 6),
            Text(label, style: fredoka(18, weight: FontWeight.w500)),
          ],
        ),
      ),
    );
  }
}
