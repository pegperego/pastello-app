import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/tokens.dart';
import '../../../core/clock.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../drawings/application/drawings_providers.dart';
import '../application/backup_providers.dart';
import '../data/drawing_backup.dart';

/// Export and import of all the drawings, in the parents' page (F-21).
class BackupSection extends ConsumerWidget {
  const BackupSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final empty = ref.watch(drawingsProvider).value?.isEmpty ?? true;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
          child: Text(l10n.backupHint, style: const TextStyle(height: 1.5)),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(8, 0, 16, 8),
          child: Wrap(
            spacing: 8,
            children: [
              TextButton.icon(
                onPressed: empty ? null : () => _export(context, ref),
                icon: const Icon(Icons.upload_file_rounded),
                label: Text(l10n.exportDrawings),
              ),
              TextButton.icon(
                onPressed: () => _import(context, ref),
                icon: const Icon(Icons.download_rounded),
                label: Text(l10n.importDrawings),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Future<void> _export(BuildContext context, WidgetRef ref) async {
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final date = ref.read(clockProvider)().toIso8601String().substring(0, 10);
    final close = _showWorking(context, l10n);
    var closed = false;
    try {
      // The file is ready before the picker opens: the waiting dialog goes
      // away as soon as the picker appears.
      final count = await ref
          .read(backupActionsProvider)
          .exportAll(
            fileName: l10n.backupFileName(date),
            onWritten: () {
              closed = true;
              close();
            },
          );
      if (count != null) {
        messenger.showSnackBar(SnackBar(content: Text(l10n.exportDone(count))));
      }
    } on Object {
      messenger.showSnackBar(SnackBar(content: Text(l10n.exportFailed)));
    } finally {
      if (!closed) close();
    }
  }

  Future<void> _import(BuildContext context, WidgetRef ref) async {
    final l10n = AppLocalizations.of(context);
    void Function()? close;
    String? message;
    try {
      final report = await ref
          .read(backupActionsProvider)
          .importFile(
            onPicked: () {
              if (context.mounted) close = _showWorking(context, l10n);
            },
          );
      if (report == null) return;
      message = [
        l10n.importAdded(report.added),
        if (report.alreadyPresent > 0)
          l10n.importPresent(report.alreadyPresent),
        if (report.unreadable > 0) l10n.importUnreadable(report.unreadable),
      ].join('\n');
    } on BackupFormatException {
      message = l10n.importNotBackup;
    } on BackupTooNewException {
      message = l10n.importTooNew;
    } on Object {
      message = l10n.exportFailed;
    } finally {
      close?.call();
    }
    if (!context.mounted) return;
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.importDone),
        content: Text(message!, style: const TextStyle(height: 1.5)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(l10n.ok),
          ),
        ],
      ),
    );
  }

  /// Shows a waiting dialog; the returned function closes it.
  void Function() _showWorking(BuildContext context, AppLocalizations l10n) {
    final navigator = Navigator.of(context);
    var open = true;
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (context) => PopScope(
        canPop: false,
        child: AlertDialog(
          content: Row(
            children: [
              const CircularProgressIndicator(color: Tokens.coral),
              const SizedBox(width: 24),
              Text(l10n.backupWorking),
            ],
          ),
        ),
      ),
    ).whenComplete(() => open = false);
    return () {
      if (open) navigator.pop();
      open = false;
    };
  }
}
