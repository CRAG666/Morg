import 'dart:io';

import 'package:flutter/material.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path/path.dart' as p;
import 'package:url_launcher/url_launcher.dart';

import 'editor_screen.dart';
import 'norg/ast.dart';
import 'norg/edits.dart';
import 'norg/parser.dart';
import 'norg_view.dart';
import 'settings.dart';
import 'theme_toggle.dart';
import 'workspace/workspace.dart';

class DocumentScreen extends StatefulWidget {
  DocumentScreen.file(File this.file, {super.key, this.initialLocation})
    : source = null,
      name = p.basenameWithoutExtension(file.path);

  const DocumentScreen.source(
    String this.source, {
    super.key,
    required this.name,
  }) : file = null,
       initialLocation = null;

  final File? file;
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
      final source = widget.source ?? await widget.file!.readAsString();
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
    await widget.file!.writeAsString(touchUpdated(source, DateTime.now()));
    await _load();
  }

  Future<void> _save(String edited) async {
    if (edited != _source) await _write(edited);
  }

  Future<void> _toggleTodo(int line) =>
      _write(cycleTodo(_source!, _blocks, line));

  Workspaces get _workspaces => Workspaces(
    MorgSettingsScope.of(context).config.workspaces,
    home: userHome(),
  );

  void _notify(String message) =>
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(message)));

  Future<void> _openLink(String target) async {
    switch (_workspaces.resolve(target, from: widget.file)) {
      case UrlTarget(:final uri):
        if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
          _notify('No se pudo abrir $uri');
        }
      case NorgFileTarget(:final file, :final location):
        if (!await file.exists() && !await _confirmCreate(file)) return;
        if (!mounted) return;
        await Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) =>
                DocumentScreen.file(file, initialLocation: location),
          ),
        );
        if (widget.file != null) await _load();
      case ExternalFileTarget(:final file):
        final result = await OpenFilex.open(file.path);
        if (result.type != ResultType.done) {
          _notify('No se pudo abrir ${file.path}: ${result.message}');
        }
      case LocalTarget(:final location):
        _notify('No se encontró «$location»');
      case UnsupportedTarget(:final target):
        _notify('Destino no soportado: $target');
    }
  }

  Future<bool> _confirmCreate(File file) async {
    final create = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('La nota no existe'),
        content: Text('¿Crear ${file.path}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Crear'),
          ),
        ],
      ),
    );
    if (!(create ?? false) || !mounted) return false;
    await createNote(file, author: MorgSettingsScope.of(context).config.author);
    return true;
  }

  ImageProvider? _resolveImage(String path) {
    if (Uri.tryParse(path) case final uri? when uri.hasScheme) {
      return NetworkImage(path);
    }
    final file = widget.file;
    if (file == null) return null;
    final resolved = path.startsWith('~') || p.isAbsolute(path)
        ? expandPath(path, home: userHome())
        : p.normalize(p.join(file.parent.path, path));
    return FileImage(File(resolved));
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
    final editable = widget.file != null && _source != null;
    return Scaffold(
      appBar: AppBar(
        title: Text(meta?.fields['title'] ?? widget.name),
        actions: [
          if (editable)
            IconButton(
              tooltip: 'Editar',
              onPressed: _edit,
              icon: const Icon(Icons.edit),
            ),
          const ThemeToggleButton(),
        ],
      ),
      body: switch ((_error, _source)) {
        (final error?, _) => Center(child: Text('No se pudo leer: $error')),
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
  File file, {
  required String author,
  String? contents,
}) async {
  await file.parent.create(recursive: true);
  await file.writeAsString(
    contents ??
        metadataTemplate(
          title: p.basenameWithoutExtension(file.path),
          author: author,
          now: DateTime.now(),
        ),
  );
}
