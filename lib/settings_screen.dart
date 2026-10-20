import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import 'editor_screen.dart';
import 'settings.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  void _notify(BuildContext context, String message) =>
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(message)));

  Future<void> _importTheme(BuildContext context) async {
    final controller = MorgSettingsScope.controllerOf(context);
    final file = await FilePicker.pickFile(
      dialogTitle: 'Tema exportado (.json)',
    );
    if (file == null) return;
    try {
      final name = await controller.importTheme(
        utf8.decode(await file.readAsBytes()),
      );
      if (context.mounted) {
        _notify(context, 'Tema "$name" importado. Úsalo con "theme": "$name".');
      }
    } on Exception catch (error) {
      if (context.mounted) _notify(context, 'Tema inválido: $error');
    }
  }

  Future<void> _reset(BuildContext context) async {
    final controller = MorgSettingsScope.controllerOf(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Restaurar configuración'),
        content: const Text(
          'Se reemplazará morg.json por la configuración por defecto.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Restaurar'),
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
      appBar: AppBar(title: const Text('Ajustes')),
      body: ListView(
        children: [
          ListTile(
            leading: const Icon(Icons.data_object),
            title: const Text('Editar configuración'),
            subtitle: const Text(
              'morg.json — misma estructura que neorg.setup()',
            ),
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
            leading: const Icon(Icons.palette),
            title: const Text('Importar tema de Neovim'),
            subtitle: Text('Tema actual: ${config.themeName}'),
            onTap: () => _importTheme(context),
          ),
          ListTile(
            leading: const Icon(Icons.restore),
            title: const Text('Restaurar configuración por defecto'),
            onTap: () => _reset(context),
          ),
        ],
      ),
    );
  }
}
