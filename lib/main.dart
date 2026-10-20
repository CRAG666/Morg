import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;
import 'package:permission_handler/permission_handler.dart';
import 'package:saf_util/saf_util.dart';

import 'document_screen.dart';
import 'prompt_dialog.dart';
import 'settings.dart';
import 'settings_screen.dart';
import 'theme/norg_theme.dart';
import 'theme_toggle.dart';
import 'workspace/store.dart';
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
  static final _isAndroid = !kIsWeb && Platform.isAndroid;
  var _storageGranted = !_isAndroid;
  final _saf = SafUtil();

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
    if (_isAndroid) {
      final document = await _saf.pickFile();
      if (document == null || !mounted) return;
      final store = SafFileStore(document.uri, document.name);
      _push(DocumentScreen.note(NoteRef(store, document.name)));
      return;
    }
    final file = await FilePicker.pickFile(dialogTitle: 'Abrir archivo Norg');
    if (file == null || !mounted) return;
    final path = kIsWeb ? null : file.path;
    if (path != null) {
      final store = LocalStore(File(path).parent);
      _push(DocumentScreen.note(NoteRef(store, p.basename(path))));
      return;
    }
    final source = utf8.decode(await file.readAsBytes(), allowMalformed: true);
    _push(DocumentScreen.source(source, name: file.name));
  }

  Future<void> _openGuide() async {
    final source = await rootBundle.loadString('assets/guia.norg');
    _push(DocumentScreen.source(source, name: 'guia'));
  }

  Future<String?> _pickCloudFolder({String? initialUri}) async {
    final folder = await _saf.pickDirectory(
      initialUri: initialUri,
      writePermission: true,
      persistablePermission: true,
    );
    return folder?.uri;
  }

  Future<void> _addCloudWorkspace() async {
    final controller = MorgSettingsScope.controllerOf(context);
    final uri = await _pickCloudFolder();
    if (uri == null || !mounted) return;
    final name = await showDialog<String>(
      context: context,
      builder: (_) => PromptDialog(
        title: 'Nombre del workspace',
        hint: 'p. ej. notas',
        confirm: 'Añadir',
        initial: SafStore(uri).location.split(RegExp('[:/]')).last,
      ),
    );
    final trimmed = name?.trim() ?? '';
    if (trimmed.isNotEmpty) await controller.setWorkspace(trimmed, uri);
  }

  Future<void> _openWorkspace(Workspace workspace) async {
    final controller = MorgSettingsScope.controllerOf(context);
    if (workspace.store case SafStore(:final treeUri)
        when !await _saf.hasPersistedPermission(treeUri, checkWrite: true)) {
      final uri = await _pickCloudFolder(initialUri: treeUri);
      if (uri == null) return;
      await controller.setWorkspace(workspace.name, uri);
      if (!mounted) return;
      _push(
        WorkspaceScreen(workspace: Workspace(workspace.name, SafStore(uri))),
      );
      return;
    }
    if (mounted) _push(WorkspaceScreen(workspace: workspace));
  }

  Future<void> _removeWorkspace(Workspace workspace) async {
    final controller = MorgSettingsScope.controllerOf(context);
    final remove = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Quitar «${workspace.name}»'),
        content: const Text(
          'Se quita de morg.json. Los archivos no se borran.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Quitar'),
          ),
        ],
      ),
    );
    if (!(remove ?? false)) return;
    if (workspace.store case SafStore(:final treeUri)) {
      await _saf.releasePersistedPermission(treeUri, write: true);
    }
    await controller.setWorkspace(workspace.name, null);
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
                  'Necesario para workspaces locales; los de la nube no lo requieren.',
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
                leading: Icon(switch (workspace.store) {
                  SafStore() => Icons.cloud,
                  _ when workspace.name == config.defaultWorkspace =>
                    Icons.folder_special,
                  _ => Icons.folder,
                }),
                title: Text(workspace.name),
                subtitle: Text(workspace.store.location),
                enabled: switch (workspace.store) {
                  LocalStore(:final root) =>
                    _storageGranted && root.existsSync(),
                  _ => true,
                },
                onTap: () => _openWorkspace(workspace),
                onLongPress: () => _removeWorkspace(workspace),
              ),
            if (_isAndroid)
              ListTile(
                leading: const Icon(Icons.add_to_drive),
                title: const Text('Añadir carpeta de la nube…'),
                subtitle: const Text('Nextcloud, OneDrive, Syncthing, etc.'),
                onTap: _addCloudWorkspace,
              ),
            const Divider(),
          ],
          ListTile(
            leading: const Icon(Icons.file_open),
            title: const Text('Abrir archivo…'),
            subtitle: Text(kIsWeb ? 'Solo lectura' : 'También desde la nube'),
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
