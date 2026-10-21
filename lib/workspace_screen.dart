import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;

import 'document_screen.dart';
import 'find_screen.dart';
import 'notes.dart';
import 'settings.dart';
import 'theme_toggle.dart';
import 'workspace/index.dart';
import 'workspace/store.dart';
import 'workspace/workspace.dart';
import 'l10n/l10n.dart';

enum _WorkspaceMenu { journalDate, summary }

const _summaryFile = 'summary.norg';

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
    await _open(DocumentScreen(note: ref));
  }

  Future<void> _openJournal(DateTime date) async {
    final config = MorgSettingsScope.of(context).config;
    final ref = await journalEntry(_store, config, date);
    await _open(DocumentScreen(note: ref));
  }

  Future<void> _pickJournalDate() async {
    final now = DateTime.now();
    final date = await showDatePicker(
      context: context,
      initialDate: now,
      firstDate: DateTime(now.year - 30),
      lastDate: DateTime(now.year + 10),
    );
    if (date != null) await _openJournal(date);
  }

  Future<void> _summary() async {
    final l10n = context.l10n;
    final summary = workspaceSummary(
      await indexNotes(_store),
      uncategorized: l10n.uncategorized,
    );
    if (await _store.exists(_summaryFile)) {
      if (!mounted) return;
      final replace = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          content: Text(l10n.replaceFileQuestion(_summaryFile)),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text(l10n.cancel),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: Text(l10n.replace),
            ),
          ],
        ),
      );
      if (!(replace ?? false)) return;
    }
    await _store.write(_summaryFile, '$summary\n');
    await _open(DocumentScreen(note: NoteRef(_store, _summaryFile)));
  }

  Future<void> _createNote() async {
    final ref = await askNewNote(context, _store, directory: widget.directory);
    if (ref != null) await _open(DocumentScreen(note: ref));
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
              onPressed: () => _openJournal(DateTime.now()),
              icon: const Icon(Icons.today),
            ),
          IconButton(
            tooltip: context.l10n.search,
            onPressed: () => _open(FindScreen(workspace: widget.workspace)),
            icon: const Icon(Icons.search),
          ),
          IconButton(
            tooltip: context.l10n.agenda,
            onPressed: () => _open(
              FindScreen(
                workspace: widget.workspace,
                initialTab: FindTab.agenda,
              ),
            ),
            icon: const Icon(Icons.event_note),
          ),
          const ThemeToggleButton(),
          PopupMenuButton<_WorkspaceMenu>(
            onSelected: (action) => switch (action) {
              _WorkspaceMenu.journalDate => _pickJournalDate(),
              _WorkspaceMenu.summary => _summary(),
            },
            itemBuilder: (context) => [
              PopupMenuItem(
                value: _WorkspaceMenu.journalDate,
                child: ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.calendar_month),
                  title: Text(context.l10n.journalOnDate),
                ),
              ),
              PopupMenuItem(
                value: _WorkspaceMenu.summary,
                child: ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.summarize),
                  title: Text(context.l10n.summary),
                ),
              ),
            ],
          ),
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
                            DocumentScreen(note: NoteRef(_store, entry.path)),
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
