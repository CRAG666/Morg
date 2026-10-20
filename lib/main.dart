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
import 'l10n/l10n.dart';

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
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
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
    final file = await FilePicker.pickFile(
      dialogTitle: context.l10n.pickNorgFile,
    );
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
    final asset = context.l10n.guideAsset;
    final source = await rootBundle.loadString(asset);
    _push(DocumentScreen.source(source, name: 'guide'));
  }

  Future<String?> _pickFolder({String? initialUri}) async {
    final folder = await _saf.pickDirectory(
      initialUri: initialUri,
      writePermission: true,
      persistablePermission: true,
    );
    if (folder == null) return null;
    final local = _storageGranted ? localPathForTree(folder.uri) : null;
    return local ?? folder.uri;
  }

  Future<void> _addWorkspace() async {
    final controller = MorgSettingsScope.controllerOf(context);
    final location = await _pickFolder();
    if (location == null || !mounted) return;
    final name = await showDialog<String>(
      context: context,
      builder: (_) => PromptDialog(
        title: context.l10n.workspaceName,
        hint: context.l10n.workspaceNameHint,
        confirm: context.l10n.add,
        initial: Uri.decodeComponent(location).split(RegExp('[:/]')).last,
      ),
    );
    final trimmed = name?.trim() ?? '';
    if (trimmed.isNotEmpty) await controller.setWorkspace(trimmed, location);
  }

  bool _isMissing(Workspace workspace) => switch (workspace.store) {
    LocalStore(:final root) => !root.existsSync(),
    _ => false,
  };

  Future<void> _openWorkspace(Workspace workspace) async {
    final controller = MorgSettingsScope.controllerOf(context);
    final store = workspace.store;
    final lostAccess = switch (store) {
      SafStore(:final treeUri) => !await _saf.hasPersistedPermission(
        treeUri,
        checkWrite: true,
      ),
      _ => _isMissing(workspace),
    };
    var target = workspace;
    if (lostAccess) {
      final location = await _pickFolder(
        initialUri: store is SafStore ? store.treeUri : null,
      );
      if (location == null) return;
      await controller.setWorkspace(workspace.name, location);
      target = Workspaces({
        workspace.name: location,
      }, home: userHome()).all[workspace.name]!;
    }
    if (mounted) _push(WorkspaceScreen(workspace: target));
  }

  Future<void> _removeWorkspace(Workspace workspace) async {
    final controller = MorgSettingsScope.controllerOf(context);
    final remove = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(context.l10n.removeWorkspace(workspace.name)),
        content: Text(context.l10n.removeWorkspaceBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(context.l10n.cancel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(context.l10n.remove),
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
            tooltip: context.l10n.settings,
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
                title: Text(context.l10n.fileAccess),
                subtitle: Text(context.l10n.fileAccessBody),
                trailing: FilledButton(
                  onPressed: () => _checkStorage(request: true),
                  child: Text(context.l10n.grant),
                ),
              ),
            ),
          if (workspaces != null) ...[
            ListTile(dense: true, title: Text(context.l10n.workspaces)),
            for (final workspace in workspaces.all.values)
              ListTile(
                leading: Icon(switch (workspace.store) {
                  SafStore() => Icons.cloud,
                  _ when workspace.name == config.defaultWorkspace =>
                    Icons.folder_special,
                  _ => Icons.folder,
                }),
                title: Text(workspace.name),
                subtitle: Text(
                  _isAndroid && _isMissing(workspace)
                      ? context.l10n.workspaceMissing
                      : workspace.store.location,
                ),
                enabled: _isAndroid || !_isMissing(workspace),
                onTap: () => _openWorkspace(workspace),
                onLongPress: () => _removeWorkspace(workspace),
              ),
            if (_isAndroid)
              ListTile(
                leading: const Icon(Icons.create_new_folder),
                title: Text(context.l10n.addFolder),
                subtitle: Text(context.l10n.addFolderSubtitle),
                onTap: _addWorkspace,
              ),
            const Divider(),
          ],
          ListTile(
            leading: const Icon(Icons.file_open),
            title: Text(context.l10n.openFile),
            subtitle: Text(
              kIsWeb ? context.l10n.readOnly : context.l10n.alsoFromCloud,
            ),
            onTap: _openFile,
          ),
          ListTile(
            leading: const Icon(Icons.menu_book),
            title: Text(context.l10n.norgGuide),
            onTap: _openGuide,
          ),
        ],
      ),
    );
  }
}
