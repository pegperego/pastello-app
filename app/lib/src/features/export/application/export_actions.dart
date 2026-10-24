import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pastello_engine/pastello_engine.dart';

import '../../../core/clock.dart';
import '../../../core/feedback/feedback.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../parents/presentation/parental_gate.dart';
import 'export_service.dart';

/// The three ways out of the app, shared by the gallery and the editor
/// (ADR 0011): saving and printing are free, sharing needs a grown-up.
enum ExportAction { save, print, share }

/// Runs [action] on [drawing] and tells the user how it went.
Future<void> runExport(
  BuildContext context,
  WidgetRef ref,
  Drawing drawing,
  ExportAction action,
) async {
  final l10n = AppLocalizations.of(context);
  final messenger = ScaffoldMessenger.of(context);
  if (action == ExportAction.share && !await showParentalGate(context)) return;
  final service = ref.read(exportServiceProvider);
  final name = exportName(ref.read(clockProvider)());
  try {
    final png = await ref.read(pngRendererProvider)(drawing);
    switch (action) {
      case ExportAction.save:
        await service.saveToGallery(png, name);
        unawaited(ref.read(feedbackProvider).sound(AppSound.ding));
        messenger.showSnackBar(SnackBar(content: Text(l10n.savedToGallery)));
      case ExportAction.print:
        unawaited(ref.read(feedbackProvider).sound(AppSound.ding));
        await service.print(png, drawing.sheetSize, name);
      case ExportAction.share:
        await service.share(png, name);
    }
  } on Object {
    messenger.showSnackBar(SnackBar(content: Text(l10n.exportFailed)));
  }
}
