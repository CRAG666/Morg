import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';

import 'document_screen.dart';
import 'settings.dart';
import 'settings_screen.dart';
import 'theme/norg_theme.dart';
import 'theme_toggle.dart';
import 'workspace/workspace.dart';
import 'workspace_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final store = await SettingsStore.open(rootBundle);
  final controller = SettingsController(store, await store.load());
  runApp(MorgSettingsScope(controller: controller, child: const MorgApp()));
}

class MorgApp extends StatelessWidget {
  const MorgApp({super.key});

  ThemeData _theme(NorgTheme norg, Brightness brightness) => ThemeData(
    colorScheme: ColorScheme.fromSeed(
      seedColor: norg['@neorg.headings.1.prefix'].foreground!,
      brightness: brightness,
      surface: norg.background,
      onSurface: norg.foreground,
    ),
    scaffoldBackgroundColor: norg.background,
    appBarTheme: AppBarTheme(
      backgroundColor:
          norg['@neorg.tags.ranged_verbatim.code_block'].background,
      foregroundColor: norg.foreground,
    ),
    fontFamily: 'JetBrainsMono',
    fontFamilyFallback: const ['SymbolsNerdFontMono', 'Noto Color Emoji'],
  );

  @override
  Widget build(BuildContext context) {
    final family = MorgSettingsScope.of(context).theme;
    return ValueListenableBuilder(
      valueListenable: themeMode,
      builder: (context, mode, _) => MaterialApp(
        title: 'Morg',
        debugShowCheckedModeBanner: false,
        theme: _theme(family.light, Brightness.light),
        darkTheme: _theme(family.dark, Brightness.dark),
        themeMode: mode,
        home: const HomeScreen(),
      ),
    );
  }
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  var _storageGranted = kIsWeb || !Platform.isAndroid;

  @override
  void initState() {
    super.initState();
    if (!_storageGranted) _checkStorage();
  }

  Future<void> _checkStorage({bool request = false}) async {
    final permission = Permission.manageExternalStorage;
    final status = request
        ? await permission.request()
        : await permission.status;
    if (mounted) setState(() => _storageGranted = status.isGranted);
  }

  void _push(Widget screen) =>
      Navigator.of(context)
          .push(MaterialPageRoute<void>(builder: (_) => screen));

  Future<void> _openFile() async {
    final file = await FilePicker.pickFile(dialogTitle: 'Abrir archivo Norg');
    if (file == null || !mounted) return;
    final source = utf8.decode(await file.readAsBytes(), allowMalformed: true);
    _push(DocumentScreen.source(source, name: file.name));
  }

  Future<void> _openGuide() async {
    final source = await rootBundle.loadString('assets/guia.norg');
    _push(DocumentScreen.source(source, name: 'guia'));
  }

  @override
  Widget build(BuildContext context) {
    final config = MorgSettingsScope.of(context).config;
    final workspaces = kIsWeb
        ? null
        : Workspaces(config.workspaces, home: userHome());
    return Scaffold(
      appBar: AppBar(
        title: const Text('Morg'),
        actions: [
          IconButton(
            tooltip: 'Ajustes',
            onPressed: () => _push(const SettingsScreen()),
            icon: const Icon(Icons.settings),
          ),
          const ThemeToggleButton(),
        ],
      ),
      body: ListView(
        children: [
          if (!_storageGranted)
            Card(
              margin: const EdgeInsets.all(12),
              child: ListTile(
                leading: const Icon(Icons.folder_off),
                title: const Text('Acceso a archivos'),
                subtitle: const Text(
                  'Morg necesita permiso para leer y editar tus workspaces.',
                ),
                trailing: FilledButton(
                  onPressed: () => _checkStorage(request: true),
                  child: const Text('Conceder'),
                ),
              ),
            ),
          if (workspaces != null) ...[
            const ListTile(dense: true, title: Text('Workspaces')),
            for (final workspace in workspaces.all.values)
              ListTile(
                leading: Icon(
                  workspace.name == config.defaultWorkspace
                      ? Icons.folder_special
                      : Icons.folder,
                ),
                title: Text(workspace.name),
                subtitle: Text(workspace.root.path),
                enabled: _storageGranted && workspace.root.existsSync(),
                onTap: () => _push(
                  WorkspaceScreen(
                    workspace: workspace,
                    directory: workspace.root,
                  ),
                ),
              ),
            const Divider(),
          ],
          ListTile(
            leading: const Icon(Icons.file_open),
            title: const Text('Abrir archivo…'),
            subtitle: const Text('Solo lectura'),
            onTap: _openFile,
          ),
          ListTile(
            leading: const Icon(Icons.menu_book),
            title: const Text('Guía de Norg'),
            onTap: _openGuide,
          ),
        ],
      ),
    );
  }
}
