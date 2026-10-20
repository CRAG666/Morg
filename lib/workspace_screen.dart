import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;

import 'document_screen.dart';
import 'settings.dart';
import 'theme_toggle.dart';
import 'workspace/workspace.dart';

class WorkspaceScreen extends StatefulWidget {
  const WorkspaceScreen({
    super.key,
    required this.workspace,
    required this.directory,
  });

  final Workspace workspace;
  final Directory directory;

  @override
  State<WorkspaceScreen> createState() => _WorkspaceScreenState();
}

class _WorkspaceScreenState extends State<WorkspaceScreen> {
  late Future<List<FileSystemEntity>> _entries = _list();

  bool get _isRoot =>
      p.equals(widget.directory.path, widget.workspace.root.path);

  Future<List<FileSystemEntity>> _list() async {
    final entries = await widget.directory
        .list()
        .where((entity) => !p.basename(entity.path).startsWith('.'))
        .where((entity) => entity is Directory || entity.path.endsWith('.norg'))
        .toList();
    return entries..sort((a, b) {
      final byKind = (a is Directory ? 0 : 1) - (b is Directory ? 0 : 1);
      return byKind != 0
          ? byKind
          : p
                .basename(a.path)
                .toLowerCase()
                .compareTo(p.basename(b.path).toLowerCase());
    });
  }

  void _refresh() => setState(() {
    _entries = _list();
  });

  Future<void> _open(Widget screen) async {
    await Navigator.of(context)
        .push(MaterialPageRoute<void>(builder: (_) => screen));
    if (mounted) _refresh();
  }

  Future<void> _openNote(File file, {String? contents}) async {
    if (!await file.exists()) {
      if (!mounted) return;
      await createNote(
        file,
        author: MorgSettingsScope.of(context).config.author,
        contents: contents,
      );
    }
    await _open(DocumentScreen.file(file));
  }

  Future<void> _openJournalToday() async {
    final config = MorgSettingsScope.of(context).config;
    final now = DateTime.now();
    String two(int value) => value.toString().padLeft(2, '0');
    final entry = switch (config.journalStrategy) {
      JournalStrategy.nested => p.join(
        '${now.year}',
        two(now.month),
        '${two(now.day)}.norg',
      ),
      JournalStrategy.flat =>
        '${now.year}-${two(now.month)}-${two(now.day)}.norg',
    };
    final journal = p.join(widget.workspace.root.path, config.journalFolder);
    final template = File(p.join(journal, config.journalTemplate));
    final useTemplate = config.useJournalTemplate && await template.exists();
    await _openNote(
      File(p.join(journal, entry)),
      contents: useTemplate ? await template.readAsString() : null,
    );
  }

  Future<void> _createNote() async {
    final name = await showDialog<String>(
      context: context,
      builder: (_) => const _NoteNameDialog(),
    );
    final trimmed = name?.trim() ?? '';
    if (trimmed.isEmpty) return;
    final path = p.join(widget.directory.path, trimmed);
    await _openNote(File(path.endsWith('.norg') ? path : '$path.norg'));
  }

  @override
  Widget build(BuildContext context) {
    final config = MorgSettingsScope.of(context).config;
    final index = File(p.join(widget.directory.path, config.indexFile));
    final relative = p.relative(
      widget.directory.path,
      from: widget.workspace.root.path,
    );
    return Scaffold(
      appBar: AppBar(
        title: Text(
          _isRoot
              ? widget.workspace.name
              : '${widget.workspace.name}/$relative',
        ),
        actions: [
          IconButton(
            tooltip: 'Índice',
            onPressed: () => _openNote(index),
            icon: const Icon(Icons.home_outlined),
          ),
          if (_isRoot)
            IconButton(
              tooltip: 'Diario de hoy',
              onPressed: _openJournalToday,
              icon: const Icon(Icons.today),
            ),
          const ThemeToggleButton(),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        tooltip: 'Nueva nota',
        onPressed: _createNote,
        child: const Icon(Icons.note_add),
      ),
      body: FutureBuilder(
        future: _entries,
        builder: (context, snapshot) => switch (snapshot) {
          AsyncSnapshot(:final error?) => Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Text('No se pudo leer ${widget.directory.path}:\n$error'),
            ),
          ),
          AsyncSnapshot(data: final entries?) => RefreshIndicator(
            onRefresh: () async => _refresh(),
            child: ListView(
              children: [
                for (final entity in entries)
                  ListTile(
                    leading: Icon(
                      entity is Directory
                          ? Icons.folder
                          : Icons.description_outlined,
                    ),
                    title: Text(
                      entity is Directory
                          ? p.basename(entity.path)
                          : p.basenameWithoutExtension(entity.path),
                    ),
                    onTap: () => entity is Directory
                        ? _open(
                            WorkspaceScreen(
                              workspace: widget.workspace,
                              directory: entity,
                            ),
                          )
                        : _open(DocumentScreen.file(File(entity.path))),
                  ),
              ],
            ),
          ),
          _ => const Center(child: CircularProgressIndicator()),
        },
      ),
    );
  }
}

class _NoteNameDialog extends StatefulWidget {
  const _NoteNameDialog();

  @override
  State<_NoteNameDialog> createState() => _NoteNameDialogState();
}

class _NoteNameDialogState extends State<_NoteNameDialog> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Nueva nota'),
    content: TextField(
      controller: _controller,
      autofocus: true,
      decoration: const InputDecoration(hintText: 'nombre o carpeta/nombre'),
      onSubmitted: (value) => Navigator.pop(context, value),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Cancelar'),
      ),
      TextButton(
        onPressed: () => Navigator.pop(context, _controller.text),
        child: const Text('Crear'),
      ),
    ],
  );
}
