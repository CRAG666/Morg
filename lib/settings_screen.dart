import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import 'editor_screen.dart';
import 'l10n/l10n.dart';
import 'prompt_dialog.dart';
import 'settings.dart';
import 'theme_toggle.dart';

const _icons = ['load', 'core.concealer', 'config', 'icons'];
const _metagen = ['load', 'core.esupports.metagen', 'config'];
const _dirman = ['load', 'core.dirman', 'config'];
const _journal = ['load', 'core.journal', 'config'];
const _indent = ['load', 'core.esupports.indent', 'config'];

void _notify(BuildContext context, String message) =>
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));

Future<void> _apply(
  BuildContext context,
  Future<void> Function() change,
) async {
  try {
    await change();
  } on Exception catch (error) {
    if (context.mounted) _notify(context, context.l10n.saveFailed('$error'));
  }
}

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  Future<void> _importFile(
    BuildContext context, {
    required String dialogTitle,
    required Future<String> Function(String source) apply,
    required String Function(AppLocalizations l10n, String result) success,
  }) async {
    final file = await FilePicker.pickFile(dialogTitle: dialogTitle);
    if (file == null) return;
    try {
      final result = await apply(utf8.decode(await file.readAsBytes()));
      if (context.mounted) _notify(context, success(context.l10n, result));
    } on Exception catch (error) {
      if (context.mounted) _notify(context, context.l10n.invalidFile('$error'));
    }
  }

  Future<void> _reset(BuildContext context) async {
    final controller = MorgSettingsScope.controllerOf(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(context.l10n.resetConfigTitle),
        content: Text(context.l10n.resetConfigBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(context.l10n.cancel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(context.l10n.reset),
          ),
        ],
      ),
    );
    if (confirmed ?? false) await controller.reset();
  }

  @override
  Widget build(BuildContext context) {
    final controller = MorgSettingsScope.controllerOf(context);
    final config = controller.value.config;
    final l10n = context.l10n;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.settings)),
      body: ListView(
        children: [
          _Section(l10n.appearance),
          ListTile(
            title: Text(l10n.themeMode),
            subtitle: Padding(
              padding: const EdgeInsets.only(top: 8),
              child: SegmentedButton<ThemeMode>(
                showSelectedIcon: false,
                segments: [
                  for (final mode in ThemeMode.values)
                    ButtonSegment(
                      value: mode,
                      label: Text(themeModeLabel(l10n, mode)),
                    ),
                ],
                selected: {config.themeMode},
                onSelectionChanged: (modes) =>
                    _apply(context, () => setThemeMode(context, modes.single)),
              ),
            ),
          ),
          _ChoiceSetting(
            label: l10n.language,
            path: const ['language'],
            options: {
              'system': l10n.systemLanguage,
              'en': 'English',
              'es': 'Español',
            },
          ),
          FutureBuilder(
            future: controller.store.themeNames(),
            builder: (context, snapshot) => _ChoiceSetting(
              label: l10n.colorscheme,
              path: const ['theme'],
              options: {
                for (final name in snapshot.data ?? [config.themeName])
                  name: name,
              },
            ),
          ),
          _Section(l10n.rendering),
          _TextSetting(
            label: l10n.headingIcons,
            path: [..._icons, 'heading', 'icons'],
            list: true,
          ),
          _TextSetting(
            label: l10n.listIcons,
            path: [..._icons, 'list', 'icons'],
            list: true,
          ),
          _TextSetting(
            label: l10n.quoteIcons,
            path: [..._icons, 'quote', 'icons'],
            list: true,
          ),
          _SwitchSetting(
            label: l10n.hideCodeTags,
            path: [..._icons, 'code_block', 'conceal'],
            fallback: false,
          ),
          _Section(l10n.notesSection),
          _TextSetting(label: l10n.author, path: [..._metagen, 'author']),
          _TextSetting(label: l10n.indexFile, path: [..._dirman, 'index']),
          _ChoiceSetting(
            label: l10n.defaultWorkspace,
            path: [..._dirman, 'default_workspace'],
            options: {
              null: l10n.none,
              for (final name in config.workspaces.keys) name: name,
            },
          ),
          _SwitchSetting(
            label: l10n.formatOnEdit,
            path: [..._indent, 'format_on_escape'],
            fallback: true,
          ),
          _SwitchSetting(
            label: l10n.dedentExcess,
            path: [..._indent, 'dedent_excess'],
            fallback: true,
          ),
          _Section(l10n.journal),
          _TextSetting(
            label: l10n.journalFolder,
            path: [..._journal, 'journal_folder'],
          ),
          _ChoiceSetting(
            label: l10n.journalStrategy,
            path: [..._journal, 'strategy'],
            options: {'nested': l10n.strategyNested, 'flat': l10n.strategyFlat},
          ),
          _TextSetting(
            label: l10n.journalTemplate,
            path: [..._journal, 'template_name'],
          ),
          _SwitchSetting(
            label: l10n.useTemplate,
            path: [..._journal, 'use_template'],
            fallback: true,
          ),
          _Section(l10n.advanced),
          ListTile(
            leading: const Icon(Icons.data_object),
            title: Text(l10n.editConfig),
            subtitle: Text(l10n.editConfigSubtitle),
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => EditorScreen(
                  title: 'morg.json',
                  source: config.source,
                  onSave: controller.save,
                ),
              ),
            ),
          ),
          ListTile(
            leading: const Icon(Icons.file_download),
            title: Text(l10n.importConfig),
            subtitle: Text(l10n.importConfigSubtitle),
            onTap: () => _importFile(
              context,
              dialogTitle: l10n.pickConfigFile,
              apply: (source) async {
                await controller.save(source);
                return '';
              },
              success: (l10n, _) => l10n.configImported,
            ),
          ),
          ListTile(
            leading: const Icon(Icons.palette),
            title: Text(l10n.importTheme),
            subtitle: Text(l10n.currentTheme(config.themeName)),
            onTap: () => _importFile(
              context,
              dialogTitle: l10n.pickThemeFile,
              apply: controller.importTheme,
              success: (l10n, name) => l10n.themeImported(name),
            ),
          ),
          ListTile(
            leading: const Icon(Icons.restore),
            title: Text(l10n.restoreDefaults),
            onTap: () => _reset(context),
          ),
        ],
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section(this.title);

  final String title;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(16, 20, 16, 4),
    child: Text(
      title,
      style: Theme.of(context).textTheme.labelLarge!
          .copyWith(color: Theme.of(context).colorScheme.primary),
    ),
  );
}

class _TextSetting extends StatelessWidget {
  const _TextSetting({
    required this.label,
    required this.path,
    this.list = false,
  });

  final String label;
  final List<String> path;
  final bool list;

  @override
  Widget build(BuildContext context) {
    final controller = MorgSettingsScope.controllerOf(context);
    final value = controller.valueAt(path);
    final shown = value is List ? value.join(' ') : value as String?;
    return ListTile(
      title: Text(label),
      subtitle: Text(
        shown == null || shown.isEmpty ? context.l10n.defaultSetting : shown,
      ),
      onTap: () async {
        final text = await showDialog<String>(
          context: context,
          builder: (_) => PromptDialog(
            title: label,
            hint: context.l10n.defaultSetting,
            confirm: context.l10n.save,
            initial: shown ?? '',
          ),
        );
        if (text == null || !context.mounted) return;
        final trimmed = text.trim();
        final newValue = trimmed.isEmpty
            ? null
            : list
            ? trimmed.split(RegExp(r'\s+'))
            : trimmed;
        await _apply(context, () => controller.setValue(path, newValue));
      },
    );
  }
}

class _SwitchSetting extends StatelessWidget {
  const _SwitchSetting({
    required this.label,
    required this.path,
    required this.fallback,
  });

  final String label;
  final List<String> path;
  final bool fallback;

  @override
  Widget build(BuildContext context) {
    final controller = MorgSettingsScope.controllerOf(context);
    return SwitchListTile(
      title: Text(label),
      value: controller.valueAt(path) as bool? ?? fallback,
      onChanged: (value) =>
          _apply(context, () => controller.setValue(path, value)),
    );
  }
}

class _ChoiceSetting extends StatelessWidget {
  const _ChoiceSetting({
    required this.label,
    required this.path,
    required this.options,
  });

  final String label;
  final List<String> path;
  final Map<String?, String> options;

  @override
  Widget build(BuildContext context) {
    final controller = MorgSettingsScope.controllerOf(context);
    final current = controller.valueAt(path) as String?;
    return ListTile(
      title: Text(label),
      trailing: DropdownButton<String?>(
        value: options.containsKey(current) ? current : options.keys.first,
        items: [
          for (final MapEntry(:key, :value) in options.entries)
            DropdownMenuItem(value: key, child: Text(value)),
        ],
        onChanged: (value) =>
            _apply(context, () => controller.setValue(path, value)),
      ),
    );
  }
}
