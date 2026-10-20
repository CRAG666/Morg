import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;

import 'document_screen.dart';
import 'prompt_dialog.dart';
import 'settings.dart';
import 'theme_toggle.dart';
import 'workspace/store.dart';
import 'workspace/workspace.dart';
import 'l10n/l10n.dart';

class WorkspaceScreen extends StatefulWidget {
  const WorkspaceScreen({
    super.key,
    required this.workspace,
    this.directory = '',
  });

  final Workspace workspace;
  final String directory;

  @override
  State<WorkspaceScreen> createState() => _WorkspaceScreenState();
}

class _WorkspaceScreenState extends State<WorkspaceScreen> {
  late Future<List<NoteEntry>> _entries = _list();

  NoteStore get _store => widget.workspace.store;

  bool get _isRoot => widget.directory.isEmpty;

  Future<List<NoteEntry>> _list() async {
    final entries = await _store.list(widget.directory);
    return entries
        .where((entry) => !entry.name.startsWith('.'))
        .where((entry) => entry.isDirectory || entry.name.endsWith('.norg'))
        .toList()
      ..sort((a, b) {
        final byKind = (a.isDirectory ? 0 : 1) - (b.isDirectory ? 0 : 1);
        return byKind != 0
            ? byKind
            : a.name.toLowerCase().compareTo(b.name.toLowerCase());
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

  Future<void> _openNote(String path, {String? contents}) async {
    final ref = NoteRef(_store, path);
    if (!await _store.exists(path)) {
      if (!mounted) return;
      await createNote(
        ref,
        author: MorgSettingsScope.of(context).config.author,
        contents: contents,
      );
    }
    await _open(DocumentScreen.note(ref));
  }

  Future<void> _openJournalToday() async {
    final config = MorgSettingsScope.of(context).config;
    final now = DateTime.now();
    String two(int value) => value.toString().padLeft(2, '0');
    final entry = switch (config.journalStrategy) {
      JournalStrategy.nested => p.posix.join(
        '${now.year}',
        two(now.month),
        '${two(now.day)}.norg',
      ),
      JournalStrategy.flat =>
        '${now.year}-${two(now.month)}-${two(now.day)}.norg',
    };
    final template = p.posix.join(config.journalFolder, config.journalTemplate);
    final useTemplate =
        config.useJournalTemplate && await _store.exists(template);
    await _openNote(
      p.posix.join(config.journalFolder, entry),
      contents: useTemplate ? await _store.read(template) : null,
    );
  }

  Future<void> _createNote() async {
    final name = await showDialog<String>(
      context: context,
      builder: (_) => PromptDialog(
        title: context.l10n.newNote,
        hint: context.l10n.newNoteHint,
        confirm: context.l10n.create,
      ),
    );
    final trimmed = name?.trim() ?? '';
    if (trimmed.isEmpty) return;
    final path = p.posix.join(widget.directory, trimmed);
    await _openNote(path.endsWith('.norg') ? path : '$path.norg');
  }

  @override
  Widget build(BuildContext context) {
    final config = MorgSettingsScope.of(context).config;
    return Scaffold(
      appBar: AppBar(
        title: Text(
          _isRoot
              ? widget.workspace.name
              : '${widget.workspace.name}/${widget.directory}',
        ),
        actions: [
          IconButton(
            tooltip: context.l10n.index,
            onPressed: () =>
                _openNote(p.posix.join(widget.directory, config.indexFile)),
            icon: const Icon(Icons.home_outlined),
          ),
          if (_isRoot)
            IconButton(
              tooltip: context.l10n.journalToday,
              onPressed: _openJournalToday,
              icon: const Icon(Icons.today),
            ),
          const ThemeToggleButton(),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        tooltip: context.l10n.newNote,
        onPressed: _createNote,
        child: const Icon(Icons.note_add),
      ),
      body: FutureBuilder(
        future: _entries,
        builder: (context, snapshot) => switch (snapshot) {
          AsyncSnapshot(:final error?) => Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Text(
                context.l10n.couldNotReadAt(_store.location, '$error'),
              ),
            ),
          ),
          AsyncSnapshot(data: final entries?) => RefreshIndicator(
            onRefresh: () async => _refresh(),
            child: ListView(
              children: [
                for (final entry in entries)
                  ListTile(
                    leading: Icon(switch (entry) {
                      NoteEntry(isDirectory: true) => Icons.folder,
                      _ when entry.name.contains('.sync-conflict-') =>
                        Icons.warning_amber,
                      _ => Icons.description_outlined,
                    }),
                    subtitle: entry.name.contains('.sync-conflict-')
                        ? Text(context.l10n.syncConflict)
                        : null,
                    title: Text(
                      entry.isDirectory
                          ? entry.name
                          : p.posix.basenameWithoutExtension(entry.name),
                    ),
                    onTap: () => entry.isDirectory
                        ? _open(
                            WorkspaceScreen(
                              workspace: widget.workspace,
                              directory: entry.path,
                            ),
                          )
                        : _open(
                            DocumentScreen.note(NoteRef(_store, entry.path)),
                          ),
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
