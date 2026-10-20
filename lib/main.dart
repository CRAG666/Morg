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
    final settings = MorgSettingsScope.of(context);
    return MaterialApp(
      title: 'Morg',
      debugShowCheckedModeBanner: false,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      theme: _theme(settings.theme.light, Brightness.light),
      darkTheme: _theme(settings.theme.dark, Brightness.dark),
      themeMode: settings.config.themeMode,
      locale: settings.config.locale,
      home: const HomeScreen(),
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
      _push(DocumentScreen(note: NoteRef(store, document.name)));
      return;
    }
    final file = await FilePicker.pickFile(
      dialogTitle: context.l10n.pickNorgFile,
    );
    if (file == null || !mounted) return;
    final path = kIsWeb ? null : file.path;
    if (path != null) {
      final store = LocalStore(File(path).parent);
      _push(DocumentScreen(note: NoteRef(store, p.basename(path))));
      return;
    }
    final source = utf8.decode(await file.readAsBytes(), allowMalformed: true);
    _push(DocumentScreen.memory(source, name: file.name));
  }

  Future<void> _openGuide() async {
    final asset = context.l10n.guideAsset;
    final source = await rootBundle.loadString(asset);
    _push(DocumentScreen.memory(source, name: 'guide'));
  }

  Future<String?> _pickFolder({String? initialUri}) async {
    if (!_isAndroid) {
      return FilePicker.getDirectoryPath(
        dialogTitle: context.l10n.addWorkspace,
      );
    }
    final folder = await _saf.pickDirectory(
      initialUri: initialUri,
      writePermission: true,
      persistablePermission: true,
    );
    if (folder == null) return null;
    final local = _storageGranted ? localPathForTree(folder.uri) : null;
    return local ?? folder.uri;
  }

  Future<String?> _askName({
    required String initial,
    required String confirm,
  }) async {
    final name = await showDialog<String>(
      context: context,
      builder: (_) => PromptDialog(
        title: context.l10n.workspaceName,
        hint: context.l10n.workspaceNameHint,
        confirm: confirm,
        initial: initial,
      ),
    );
    final trimmed = name?.trim() ?? '';
    return trimmed.isEmpty ? null : trimmed;
  }

  Future<void> _addWorkspace() async {
    final controller = MorgSettingsScope.controllerOf(context);
    final location = await _pickFolder();
    if (location == null || !mounted) return;
    final name = await _askName(
      initial: Uri.decodeComponent(location).split(RegExp('[:/]')).last,
      confirm: context.l10n.add,
    );
    if (name != null) await controller.setWorkspace(name, location);
  }

  bool _isMissing(Workspace workspace) => switch (workspace.store) {
    LocalStore(:final root) => !root.existsSync(),
    _ => false,
  };

  Future<Workspace?> _relocate(Workspace workspace) async {
    final controller = MorgSettingsScope.controllerOf(context);
    final store = workspace.store;
    final location = await _pickFolder(
      initialUri: store is SafStore ? store.treeUri : null,
    );
    if (location == null) return null;
    await controller.setWorkspace(workspace.name, location);
    return Workspaces.of(controller.value.config).all[workspace.name];
  }

  Future<Workspace?> _accessible(Workspace workspace) async {
    final lostAccess = switch (workspace.store) {
      SafStore(:final treeUri) => !await _saf.hasPersistedPermission(
        treeUri,
        checkWrite: true,
      ),
      _ => _isMissing(workspace),
    };
    return lostAccess ? _relocate(workspace) : workspace;
  }

  Future<void> _openWorkspace(Workspace workspace) async {
    final target = await _accessible(workspace);
    if (target == null || !mounted) return;
    final config = MorgSettingsScope.of(context).config;
    final index = NoteRef(target.store, config.indexFile);
    if (await target.store.exists(index.path)) {
      if (mounted) _push(DocumentScreen(note: index));
      return;
    }
    if (!mounted) return;
    final create = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(context.l10n.noIndexTitle(config.indexFile)),
        content: Text(context.l10n.noIndexBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(context.l10n.browseFiles),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(context.l10n.create),
          ),
        ],
      ),
    );
    if (create == null || !mounted) return;
    if (create) {
      await createNote(index, author: config.author);
      if (mounted) _push(DocumentScreen(note: index));
    } else {
      _push(WorkspaceScreen(workspace: target));
    }
  }

  Future<void> _workspaceMenu(Workspace workspace) async {
    final action = await showModalBottomSheet<_WorkspaceAction>(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              title: Text(
                workspace.name,
                style: Theme.of(context).textTheme.titleMedium,
              ),
              subtitle: Text(workspace.store.location),
            ),
            for (final (action, icon, label) in [
              (
                _WorkspaceAction.browse,
                Icons.folder_open,
                context.l10n.browseFiles,
              ),
              (
                _WorkspaceAction.relocate,
                Icons.drive_file_move,
                context.l10n.changeFolder,
              ),
              (_WorkspaceAction.rename, Icons.edit, context.l10n.rename),
              (
                _WorkspaceAction.remove,
                Icons.delete_outline,
                context.l10n.remove,
              ),
            ])
              ListTile(
                leading: Icon(icon),
                title: Text(label),
                onTap: () => Navigator.pop(context, action),
              ),
          ],
        ),
      ),
    );
    if (!mounted) return;
    switch (action) {
      case _WorkspaceAction.browse:
        if (await _accessible(workspace) case final target? when mounted) {
          _push(WorkspaceScreen(workspace: target));
        }
      case _WorkspaceAction.relocate:
        await _relocate(workspace);
      case _WorkspaceAction.rename:
        final controller = MorgSettingsScope.controllerOf(context);
        final name = await _askName(
          initial: workspace.name,
          confirm: context.l10n.rename,
        );
        if (name != null && name != workspace.name) {
          await controller.renameWorkspace(workspace.name, name);
        }
      case _WorkspaceAction.remove:
        await _removeWorkspace(workspace);
      case null:
    }
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
    final workspaces = kIsWeb ? null : Workspaces.of(config);
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
      floatingActionButton: workspaces == null
          ? null
          : FloatingActionButton.extended(
              onPressed: _addWorkspace,
              icon: const Icon(Icons.create_new_folder),
              label: Text(context.l10n.addWorkspace),
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
            if (workspaces.all.isEmpty)
              ListTile(
                leading: const Icon(Icons.info_outline),
                title: Text(context.l10n.noWorkspaces),
              ),
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
                onLongPress: () => _workspaceMenu(workspace),
              ),
            const Divider(),
          ],
          ListTile(
            leading: const Icon(Icons.file_open),
            title: Text(context.l10n.openFile),
            subtitle: _isAndroid ? Text(context.l10n.alsoFromCloud) : null,
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

enum _WorkspaceAction { browse, relocate, rename, remove }
