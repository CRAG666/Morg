import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import 'editor_screen.dart';
import 'settings.dart';
import 'l10n/l10n.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  void _notify(BuildContext context, String message) =>
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(message)));

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
    return Scaffold(
      appBar: AppBar(title: Text(context.l10n.settings)),
      body: ListView(
        children: [
          ListTile(
            leading: const Icon(Icons.data_object),
            title: Text(context.l10n.editConfig),
            subtitle: Text(context.l10n.editConfigSubtitle),
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
            title: Text(context.l10n.importConfig),
            subtitle: Text(context.l10n.importConfigSubtitle),
            onTap: () => _importFile(
              context,
              dialogTitle: context.l10n.pickConfigFile,
              apply: (source) async {
                await controller.save(source);
                return '';
              },
              success: (l10n, _) => l10n.configImported,
            ),
          ),
          ListTile(
            leading: const Icon(Icons.palette),
            title: Text(context.l10n.importTheme),
            subtitle: Text(context.l10n.currentTheme(config.themeName)),
            onTap: () => _importFile(
              context,
              dialogTitle: context.l10n.pickThemeFile,
              apply: controller.importTheme,
              success: (l10n, name) => l10n.themeImported(name),
            ),
          ),
          ListTile(
            leading: const Icon(Icons.restore),
            title: Text(context.l10n.restoreDefaults),
            onTap: () => _reset(context),
          ),
        ],
      ),
    );
  }
}
