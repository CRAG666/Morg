import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:url_launcher/url_launcher.dart';

import 'editor_screen.dart';
import 'find_screen.dart';
import 'norg/ast.dart';
import 'norg/edits.dart';
import 'norg/markdown.dart';
import 'norg/parser.dart';
import 'norg/targets.dart';
import 'norg_view.dart';
import 'notes.dart';
import 'settings.dart';
import 'workspace/index.dart';
import 'workspace/store.dart';
import 'workspace/workspace.dart';
import 'workspace_screen.dart';
import 'l10n/l10n.dart';

const _historyLimit = 100;
final _queryPrefix = RegExp(r'^([*#$^:/]+)\s*');

enum _DocumentAction {
  editFile,
  browse,
  journalToday,
  journalDate,
  previousDay,
  nextDay,
  exportMarkdown,
}

class DocumentScreen extends StatefulWidget {
  const DocumentScreen({
    super.key,
    required this.note,
    this.initialLocation,
    this.initialLine,
  });

  DocumentScreen.memory(String source, {super.key, required String name})
    : note = NoteRef(MemoryStore(name, {name: source}), name),
      initialLocation = null,
      initialLine = null;

  final NoteRef note;
  final String? initialLocation;
  final int? initialLine;

  @override
  State<DocumentScreen> createState() => _DocumentScreenState();
}

class _DocumentScreenState extends State<DocumentScreen> {
  String? _source;
  List<Block> _blocks = const [];
  Object? _error;
  final _undo = <String>[];
  final _redo = <String>[];
  final _view = GlobalKey<NorgDocumentViewState>();
  List<String> _files = const [];

  @override
  void initState() {
    super.initState();
    _load();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadFiles());
  }

  Future<void> _loadFiles() async {
    final workspace = _workspaces.containing(widget.note);
    if (workspace == null) return;
    final files = await norgFiles(workspace.store);
    if (mounted) setState(() => _files = files);
  }

  List<String> _completions(String query) {
    final match = _queryPrefix.firstMatch(query);
    final prefix = match?[1] ?? '';
    final needle = query.substring(match?.end ?? 0).toLowerCase();
    final candidates = [
      if (!prefix.startsWith(':')) ...DocumentTargets(_blocks).locations,
      if (prefix.isEmpty || prefix.startsWith(':'))
        for (final file in _files) ':\$/${p.posix.withoutExtension(file)}:',
    ];
    return [
      for (final candidate in candidates)
        if (candidate.startsWith(prefix.isEmpty ? '' : prefix[0]) &&
            candidate.toLowerCase().contains(needle))
          candidate,
    ];
  }

  Future<void> _load() async {
    try {
      final note = widget.note;
      final source = await note.store.read(note.path);
      setState(() {
        _source = source;
        _blocks = parseNorg(source);
        _error = null;
      });
    } on FileSystemException catch (error) {
      setState(() => _error = error);
    }
  }

  Future<void> _write(String source, {bool record = true}) async {
    final note = widget.note;
    final previous = _source;
    await note.store.write(note.path, touchUpdated(source, DateTime.now()));
    if (record && previous != null) {
      _undo.add(previous);
      if (_undo.length > _historyLimit) _undo.removeAt(0);
      _redo.clear();
    }
    await _load();
  }

  Future<void> _step(List<String> from, List<String> to) async {
    if (from.isEmpty || _source == null) return;
    to.add(_source!);
    await _guarded(() => _write(from.removeLast(), record: false));
  }

  Future<void> _guarded(Future<void> Function() action) async {
    try {
      await action();
    } on FileSystemException catch (error) {
      _notify((l10n) => l10n.saveFailed('$error'));
    }
  }

  Future<void> _save(String edited) async {
    if (edited != _source) await _write(edited);
  }

  Future<void> _replaceLines(SourceRange range, String text) {
    final lines = _source!.split('\n')
      ..replaceRange(range.start, range.end, text.split('\n'));
    return _guarded(() => _write(lines.join('\n')));
  }

  Future<void> _transform(SourceEdit edit, {String? notice}) async {
    final edited = edit(_source!);
    if (edited == _source) return;
    await _guarded(() => _write(edited));
    if (notice == null || !mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(notice),
          action: SnackBarAction(
            label: context.l10n.undo,
            onPressed: () => _step(_undo, _redo),
          ),
        ),
      );
  }

  Workspaces get _workspaces =>
      Workspaces.of(MorgSettingsScope.of(context).config);

  void _notify(String Function(AppLocalizations l10n) message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message(context.l10n))));
  }

  Future<void> _openLink(String target) async {
    try {
      await _followTarget(_workspaces.resolve(target, from: widget.note));
    } on FileSystemException catch (error) {
      _notify((l10n) => l10n.couldNotOpenBecause(target, '$error'));
    }
  }

  Future<void> _followTarget(LinkTarget target) async {
    switch (target) {
      case UrlTarget(:final uri) when uri.isScheme('file') && !kIsWeb:
        await openWithSystem(uri.toFilePath());
      case UrlTarget(:final uri):
        if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
          _notify((l10n) => l10n.couldNotOpen('$uri'));
        }
      case NorgFileTarget(:final ref, :final location):
        if (!await ref.store.exists(ref.path) && !await _confirmCreate(ref)) {
          return;
        }
        if (!mounted) return;
        await Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) =>
                DocumentScreen(note: ref, initialLocation: location),
          ),
        );
        await _load();
      case ExternalFileTarget(:final ref):
        await ref.store.openExternally(ref.path);
      case LocalTarget(:final location):
        _notify((l10n) => l10n.notFound(location));
      case UnsupportedTarget(:final target):
        _notify((l10n) => l10n.unsupportedLink(target));
    }
  }

  Future<bool> _confirmCreate(NoteRef ref) async {
    final create = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(context.l10n.noteMissingTitle),
        content: Text(
          context.l10n.createNoteQuestion(ref.path, ref.store.location),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(context.l10n.cancel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(context.l10n.create),
          ),
        ],
      ),
    );
    if (!(create ?? false) || !mounted) return false;
    await createNote(ref, author: MorgSettingsScope.of(context).config.author);
    return true;
  }

  Widget? _image(String path) {
    final isSvg = p.extension(path).toLowerCase() == '.svg';
    if (Uri.tryParse(path) case final uri? when uri.hasScheme) {
      return isSvg ? svgFromUrl(path) : Image.network(path);
    }
    final ref = _workspaces.resolvePath(path, from: widget.note);
    if (ref == null) return null;
    if (!isSvg) return Image(image: StoreImage(ref));
    return FutureBuilder(
      future: ref.store.readBytes(ref.path),
      builder: (context, snapshot) => snapshot.hasData
          ? svgFromBytes(snapshot.data!)
          : const SizedBox.shrink(),
    );
  }

  Future<void> _edit() => Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder: (_) => EditorScreen(
        title: widget.note.name,
        source: _source!,
        onSave: _save,
        completions: _completions,
      ),
    ),
  );

  void _push(Widget screen) =>
      Navigator.of(context)
          .push(MaterialPageRoute<void>(builder: (_) => screen));

  Future<void> _openJournal(Workspace workspace, DateTime date) async {
    final config = MorgSettingsScope.of(context).config;
    final ref = await journalEntry(workspace.store, config, date);
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute<void>(builder: (_) => DocumentScreen(note: ref)),
    );
  }

  Future<void> _exportMarkdown() async {
    final markdown = toMarkdown(_source!, _blocks);
    final saved = await FilePicker.saveFile(
      fileName: '${widget.note.name}.md',
      bytes: utf8.encode(markdown),
      mimeType: 'text/markdown',
      dialogTitle: context.l10n.exportMarkdown,
    );
    if (saved != null) _notify((l10n) => l10n.exported);
  }

  Future<void> _act(_DocumentAction action, Workspace? workspace) async {
    final config = MorgSettingsScope.of(context).config;
    final journalDate = journalDateOf(config, widget.note.path);
    switch (action) {
      case _DocumentAction.editFile:
        await _edit();
      case _DocumentAction.browse:
        _push(
          WorkspaceScreen(
            workspace: workspace!,
            directory: widget.note.directory,
          ),
        );
      case _DocumentAction.journalToday:
        await _openJournal(workspace!, DateTime.now());
      case _DocumentAction.journalDate:
        final now = DateTime.now();
        final date = await showDatePicker(
          context: context,
          initialDate: journalDate ?? now,
          firstDate: DateTime(now.year - 30),
          lastDate: DateTime(now.year + 10),
        );
        if (date != null) await _openJournal(workspace!, date);
      case _DocumentAction.previousDay:
        await _openJournal(
          workspace!,
          journalDate!.subtract(const Duration(days: 1)),
        );
      case _DocumentAction.nextDay:
        await _openJournal(
          workspace!,
          journalDate!.add(const Duration(days: 1)),
        );
      case _DocumentAction.exportMarkdown:
        await _exportMarkdown();
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final meta = _blocks.whereType<DocumentMeta>().firstOrNull;
    final editable = _source != null;
    final workspace = _workspaces.containing(widget.note);
    final isJournal =
        journalDateOf(MorgSettingsScope.of(context).config, widget.note.path) !=
        null;
    return Scaffold(
      appBar: AppBar(
        title: Text(meta?.fields['title'] ?? widget.note.name),
        actions: [
          IconButton(
            tooltip: l10n.undo,
            onPressed: _undo.isEmpty ? null : () => _step(_undo, _redo),
            icon: const Icon(Icons.undo),
          ),
          IconButton(
            tooltip: l10n.redo,
            onPressed: _redo.isEmpty ? null : () => _step(_redo, _undo),
            icon: const Icon(Icons.redo),
          ),
          if (workspace != null)
            IconButton(
              tooltip: l10n.search,
              onPressed: () => _push(FindScreen(workspace: workspace)),
              icon: const Icon(Icons.search),
            ),
          Builder(
            builder: (context) => IconButton(
              tooltip: l10n.outline,
              onPressed: Scaffold.of(context).openEndDrawer,
              icon: const Icon(Icons.toc),
            ),
          ),
          PopupMenuButton<_DocumentAction>(
            onSelected: (action) => _act(action, workspace),
            itemBuilder: (context) => [
              for (final (action, icon, label, enabled) in [
                (_DocumentAction.editFile, Icons.edit, l10n.edit, editable),
                (
                  _DocumentAction.browse,
                  Icons.folder_open,
                  l10n.browseFiles,
                  workspace != null,
                ),
                (
                  _DocumentAction.journalToday,
                  Icons.today,
                  l10n.journalToday,
                  workspace != null,
                ),
                (
                  _DocumentAction.journalDate,
                  Icons.calendar_month,
                  l10n.journalOnDate,
                  workspace != null,
                ),
                (
                  _DocumentAction.previousDay,
                  Icons.chevron_left,
                  l10n.previousDay,
                  workspace != null && isJournal,
                ),
                (
                  _DocumentAction.nextDay,
                  Icons.chevron_right,
                  l10n.nextDay,
                  workspace != null && isJournal,
                ),
                (
                  _DocumentAction.exportMarkdown,
                  Icons.ios_share,
                  l10n.exportMarkdown,
                  editable,
                ),
              ])
                if (enabled)
                  PopupMenuItem(
                    value: action,
                    child: ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: Icon(icon),
                      title: Text(label),
                    ),
                  ),
            ],
          ),
        ],
      ),
      endDrawer: Drawer(
        child: SafeArea(
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Text(
                l10n.outline,
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 12),
              Builder(
                builder: (context) => HeadingOutline(
                  blocks: _blocks,
                  onSelect: (line) {
                    Navigator.pop(context);
                    _view.currentState?.jumpToLine(line);
                  },
                ),
              ),
            ],
          ),
        ),
      ),
      body: switch ((_error, _source)) {
        (final error?, _) => Center(child: Text(l10n.couldNotRead('$error'))),
        (_, null) => const Center(child: CircularProgressIndicator()),
        (_, final source?) => NorgDocumentView(
          key: _view,
          blocks: _blocks,
          source: source,
          onEdit: editable ? _replaceLines : null,
          onLink: _openLink,
          onTransform: editable ? _transform : null,
          completions: _completions,
          buildImage: _image,
          initialLocation: widget.initialLocation,
          initialLine: widget.initialLine,
        ),
      },
    );
  }
}
