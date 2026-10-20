import 'dart:io';

import 'package:flutter/material.dart';
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
import 'l10n/l10n.dart';

class DocumentScreen extends StatefulWidget {
  DocumentScreen.note(NoteRef this.note, {super.key, this.initialLocation})
    : source = null,
      name = note.name;

  const DocumentScreen.source(
    String this.source, {
    super.key,
    required this.name,
  }) : note = null,
       initialLocation = null;

  final NoteRef? note;
  final String? source;
  final String name;
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
      final source = widget.source ?? await note!.store.read(note.path);
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
    final note = widget.note!;
    await note.store.write(note.path, touchUpdated(source, DateTime.now()));
    await _load();
  }

  Future<void> _save(String edited) async {
    if (edited != _source) await _write(edited);
  }

  Future<void> _toggleTodo(int line) async {
    try {
      await _write(cycleTodo(_source!, _blocks, line));
    } on FileSystemException catch (error) {
      _notify((l10n) => l10n.saveFailed('$error'));
    }
  }

  Workspaces get _workspaces => Workspaces(
    MorgSettingsScope.of(context).config.workspaces,
    home: userHome(),
  );

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
            builder: (_) => DocumentScreen.note(ref, initialLocation: location),
          ),
        );
        if (widget.note != null) await _load();
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

  ImageProvider? _resolveImage(String path) {
    if (Uri.tryParse(path) case final uri? when uri.hasScheme) {
      return NetworkImage(path);
    }
    final ref = _workspaces.resolvePath(path, from: widget.note);
    return ref == null ? null : StoreImage(ref);
  }

  Future<void> _edit() => Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder: (_) =>
          EditorScreen(title: widget.name, source: _source!, onSave: _save),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final meta = _blocks.whereType<DocumentMeta>().firstOrNull;
    final editable = widget.note != null && _source != null;
    return Scaffold(
      appBar: AppBar(
        title: Text(meta?.fields['title'] ?? widget.name),
        actions: [
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
        _ => NorgDocumentView(
          blocks: _blocks,
          onLink: _openLink,
          onTodoTap: editable ? _toggleTodo : null,
          resolveImage: _resolveImage,
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
