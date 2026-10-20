import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:url_launcher/url_launcher.dart';

import 'editor_screen.dart';
import 'norg/ast.dart';
import 'norg/edits.dart';
import 'norg/parser.dart';
import 'norg_view.dart';
import 'settings.dart';
import 'theme_toggle.dart';
import 'workspace/store.dart';
import 'workspace/workspace.dart';
import 'workspace_screen.dart';
import 'l10n/l10n.dart';

class DocumentScreen extends StatefulWidget {
  const DocumentScreen({super.key, required this.note, this.initialLocation});

  DocumentScreen.memory(String source, {super.key, required String name})
    : note = NoteRef(MemoryStore(name, {name: source}), name),
      initialLocation = null;

  final NoteRef note;
  final String? initialLocation;

  @override
  State<DocumentScreen> createState() => _DocumentScreenState();
}

class _DocumentScreenState extends State<DocumentScreen> {
  String? _source;
  List<Block> _blocks = const [];
  Object? _error;

  @override
  void initState() {
    super.initState();
    _load();
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

  Future<void> _write(String source) async {
    final note = widget.note;
    await note.store.write(note.path, touchUpdated(source, DateTime.now()));
    await _load();
  }

  Future<void> _save(String edited) async {
    if (edited != _source) await _write(edited);
  }

  Future<void> _replaceLines(SourceRange range, String text) async {
    final lines = _source!.split('\n')
      ..replaceRange(range.start, range.end, text.split('\n'));
    try {
      await _write(lines.join('\n'));
    } on FileSystemException catch (error) {
      _notify((l10n) => l10n.saveFailed('$error'));
    }
  }

  Future<void> _toggleTodo(int line) async {
    try {
      await _write(cycleTodo(_source!, _blocks, line));
    } on FileSystemException catch (error) {
      _notify((l10n) => l10n.saveFailed('$error'));
    }
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
      ),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final meta = _blocks.whereType<DocumentMeta>().firstOrNull;
    final editable = _source != null;
    return Scaffold(
      appBar: AppBar(
        title: Text(meta?.fields['title'] ?? widget.note.name),
        actions: [
          if (_workspaces.containing(widget.note) case final workspace?)
            IconButton(
              tooltip: context.l10n.browseFiles,
              icon: const Icon(Icons.folder_open),
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => WorkspaceScreen(
                    workspace: workspace,
                    directory: widget.note.directory,
                  ),
                ),
              ),
            ),
          if (editable)
            IconButton(
              tooltip: context.l10n.edit,
              onPressed: _edit,
              icon: const Icon(Icons.edit),
            ),
          const ThemeToggleButton(),
        ],
      ),
      body: switch ((_error, _source)) {
        (final error?, _) => Center(
          child: Text(context.l10n.couldNotRead('$error')),
        ),
        (_, null) => const Center(child: CircularProgressIndicator()),
        (_, final source?) => NorgDocumentView(
          blocks: _blocks,
          source: source,
          onEdit: editable ? _replaceLines : null,
          onLink: _openLink,
          onTodoTap: editable ? _toggleTodo : null,
          buildImage: _image,
          initialLocation: widget.initialLocation,
        ),
      },
    );
  }
}

Future<void> createNote(
  NoteRef ref, {
  required String author,
  String? contents,
}) => ref.store.write(
  ref.path,
  contents ??
      metadataTemplate(title: ref.name, author: author, now: DateTime.now()),
);
