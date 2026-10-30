import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme.dart';
import '../../../app/tokens.dart';
import '../../../core/settings/app_settings.dart';
import '../../../core/settings/settings_providers.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../backup/presentation/backup_section.dart';
import '../../drawings/application/drawings_providers.dart';
import '../application/parents_providers.dart';

/// Everything meant for adults (F-14). It is only reached through the
/// parental gate, which must be passed again every time.
class ParentsPage extends ConsumerWidget {
  const ParentsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final settings = ref.watch(settingsProvider).value ?? const AppSettings();
    final change = ref.read(settingsProvider.notifier).change;
    final trash = ref.watch(trashProvider).value ?? const [];
    final info = ref.watch(appInfoProvider).value;
    final open = ref.read(linkOpenerProvider);

    Widget section(String title, List<Widget> children) => Padding(
      padding: const EdgeInsets.only(top: 16),
      child: Card(
        color: Tokens.sheet,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: Tokens.border),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
                child: Text(title, style: fredoka(20)),
              ),
              ...children,
            ],
          ),
        ),
      ),
    );

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Tokens.paper,
        title: Text(l10n.parents, style: fredoka(26)),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
            children: [
              section(l10n.settings, [
                ListTile(
                  title: Text(l10n.language),
                  subtitle: Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: SegmentedButton<String?>(
                      segments: [
                        ButtonSegment(
                          value: null,
                          label: Text(l10n.languageSystem),
                        ),
                        const ButtonSegment(
                          value: 'it',
                          label: Text('Italiano'),
                        ),
                        const ButtonSegment(
                          value: 'en',
                          label: Text('English'),
                        ),
                      ],
                      selected: {settings.language},
                      onSelectionChanged: (value) => change(
                        (s) => s.copyWith(language: () => value.single),
                      ),
                    ),
                  ),
                ),
                SwitchListTile(
                  title: Text(l10n.leftHanded),
                  subtitle: Text(l10n.leftHandedHint),
                  value: settings.leftHanded,
                  onChanged: (value) =>
                      change((s) => s.copyWith(leftHanded: value)),
                ),
                SwitchListTile(
                  title: Text(l10n.sounds),
                  value: settings.sounds,
                  onChanged: (value) =>
                      change((s) => s.copyWith(sounds: value)),
                ),
                SwitchListTile(
                  title: Text(l10n.haptics),
                  value: settings.haptics,
                  onChanged: (value) =>
                      change((s) => s.copyWith(haptics: value)),
                ),
              ]),
              section(l10n.trash, [
                ListTile(
                  title: Text(l10n.trashCount(trash.length)),
                  subtitle: Text(l10n.trashRetention),
                ),
                _ButtonRow(
                  child: TextButton.icon(
                    onPressed: trash.isEmpty
                        ? null
                        : () => ref.read(trashProvider.notifier).empty(),
                    style: TextButton.styleFrom(
                      foregroundColor: Tokens.raspberry,
                    ),
                    icon: const Icon(Icons.delete_forever_rounded),
                    label: Text(l10n.emptyTrash),
                  ),
                ),
              ]),
              section(l10n.backup, [const BackupSection()]),
              section(l10n.pinningTitle, [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
                  child: Text(
                    l10n.pinningSteps,
                    style: const TextStyle(height: 1.5),
                  ),
                ),
              ]),
              section(l10n.about, [
                ListTile(
                  title: Text(
                    info == null ? '…' : l10n.appVersion(info.version),
                  ),
                  subtitle: Text(
                    info == null
                        ? ''
                        : l10n.deviceInfo(info.device, info.android),
                  ),
                ),
                _ButtonRow(
                  child: TextButton.icon(
                    onPressed: info == null
                        ? null
                        : () async {
                            await Clipboard.setData(
                              ClipboardData(text: info.report),
                            );
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text(l10n.copied)),
                              );
                            }
                          },
                    icon: const Icon(Icons.copy_rounded),
                    label: Text(l10n.copyInfo),
                  ),
                ),
              ]),
              section(l10n.links, [
                for (final (label, uri, icon) in [
                  (l10n.sourceCode, ProjectLinks.source, Icons.code_rounded),
                  (
                    l10n.reportProblem,
                    ProjectLinks.issues,
                    Icons.bug_report_rounded,
                  ),
                  (
                    l10n.privacyPolicy,
                    ProjectLinks.privacy,
                    Icons.privacy_tip_rounded,
                  ),
                ])
                  ListTile(
                    leading: Icon(icon),
                    title: Text(label),
                    trailing: const Icon(Icons.open_in_new_rounded),
                    onTap: () => open(uri),
                  ),
                ListTile(
                  leading: const Icon(Icons.description_rounded),
                  title: Text(l10n.credits),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () => showLicensePage(
                    context: context,
                    applicationName: l10n.appTitle,
                    applicationVersion: info?.version,
                    applicationLegalese:
                        '© Pastello contributors — GNU GPL v3.0',
                  ),
                ),
              ]),
            ],
          ),
        ),
      ),
    );
  }
}

/// A button under a list tile, aligned with its text.
class _ButtonRow extends StatelessWidget {
  const _ButtonRow({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(8, 0, 16, 8),
    child: Align(alignment: Alignment.centerLeft, child: child),
  );
}
