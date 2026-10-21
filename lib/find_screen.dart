import 'package:flutter/material.dart';

import 'document_screen.dart';
import 'l10n/l10n.dart';
import 'norg/ast.dart';
import 'norg/edits.dart';
import 'norg/structure.dart';
import 'todo_menu.dart';
import 'workspace/index.dart';
import 'workspace/store.dart';
import 'workspace/workspace.dart';

enum FindTab { search, tasks, agenda }

const _statusOrder = [
  TodoStatus.urgent,
  TodoStatus.pending,
  TodoStatus.undone,
  TodoStatus.needsInput,
  TodoStatus.onHold,
  TodoStatus.recurring,
  TodoStatus.done,
  TodoStatus.cancelled,
];
const _closed = {TodoStatus.done, TodoStatus.cancelled};
const _dateMarkers = ['<', '>', '@'];
const _maxMatches = 300;

class _Match {
  const _Match(this.note, this.line, this.text);
  final IndexedNote note;
  final int line;
  final String text;
}

class _NoteTask {
  const _NoteTask(this.note, this.task);
  final IndexedNote note;
  final TaskEntry task;
}

class _Dated {
  const _Dated(this.entry, this.marker, this.date);
  final _NoteTask entry;
  final String marker;
  final DateTime date;
}

bool Function(String text) _matcher(String query) {
  final terms = query.trim().split(RegExp(r'\s+')).where((t) => t.isNotEmpty);
  final alternatives = [
    for (final term in terms)
      [
        for (final option in term.split('|'))
          if (option.isNotEmpty) option,
      ],
  ];
  return (text) {
    final lower = text.toLowerCase();
    return alternatives.every(
      (options) => options.any(
        (option) => option.toLowerCase() == option
            ? lower.contains(option)
            : text.contains(option),
      ),
    );
  };
}

class FindScreen extends StatefulWidget {
  const FindScreen({
    super.key,
    required this.workspace,
    this.initialTab = FindTab.search,
  });

  final Workspace workspace;
  final FindTab initialTab;

  @override
  State<FindScreen> createState() => _FindScreenState();
}

class _FindScreenState extends State<FindScreen> {
  late Future<List<IndexedNote>> _notes = indexNotes(widget.workspace.store);
  final _query = TextEditingController();
  final _statuses = {..._statusOrder}..removeAll(_closed);

  @override
  void dispose() {
    _query.dispose();
    super.dispose();
  }

  void _refresh() => setState(() {
    _notes = indexNotes(widget.workspace.store);
  });

  Future<void> _open(IndexedNote note, int line) async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => DocumentScreen(note: note.ref, initialLine: line),
      ),
    );
    if (mounted) _refresh();
  }

  Future<void> _edit(IndexedNote note, SourceEdit edit) async {
    try {
      await note.ref.store.write(
        note.ref.path,
        touchUpdated(edit(note.source), DateTime.now()),
      );
    } on Exception catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.l10n.saveFailed('$error'))),
        );
      }
    }
    if (mounted) _refresh();
  }

  @override
  Widget build(BuildContext context) => DefaultTabController(
    length: FindTab.values.length,
    initialIndex: widget.initialTab.index,
    child: Scaffold(
      appBar: AppBar(
        title: TextField(
          controller: _query,
          autofocus: widget.initialTab == FindTab.search,
          decoration: InputDecoration(
            hintText: context.l10n.searchHint(widget.workspace.name),
            border: InputBorder.none,
          ),
          onChanged: (_) => setState(() {}),
        ),
        actions: [
          if (_query.text.isNotEmpty)
            IconButton(
              tooltip: context.l10n.clear,
              icon: const Icon(Icons.clear),
              onPressed: () => setState(_query.clear),
            ),
        ],
        bottom: TabBar(
          tabs: [
            Tab(text: context.l10n.search),
            Tab(text: context.l10n.tasks),
            Tab(text: context.l10n.agenda),
          ],
        ),
      ),
      body: FutureBuilder(
        future: _notes,
        builder: (context, snapshot) => switch (snapshot) {
          AsyncSnapshot(:final error?) => Center(
            child: Text(
              context.l10n.couldNotReadAt(
                widget.workspace.store.location,
                '$error',
              ),
            ),
          ),
          AsyncSnapshot(data: final notes?) => TabBarView(
            children: [_searchResults(notes), _taskList(notes), _agenda(notes)],
          ),
          _ => const Center(child: CircularProgressIndicator()),
        },
      ),
    ),
  );

  Widget _empty() => Center(child: Text(context.l10n.noResults));

  Widget _searchResults(List<IndexedNote> notes) {
    final query = _query.text.trim();
    if (query.isEmpty) return const SizedBox.shrink();
    final matches = _matcher(query);
    final results = <_Match>[];
    for (final note in notes) {
      if (matches(note.title)) results.add(_Match(note, 0, note.title));
      for (final (line, text) in note.source.split('\n').indexed) {
        if (results.length >= _maxMatches) break;
        if (text.trim().isNotEmpty && matches(text)) {
          results.add(_Match(note, line, text.trim()));
        }
      }
    }
    if (results.isEmpty) return _empty();
    return ListView.builder(
      itemCount: results.length,
      itemBuilder: (context, index) {
        final match = results[index];
        final first = index == 0 || results[index - 1].note != match.note;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (first)
              ListTile(
                dense: true,
                leading: const Icon(Icons.description_outlined),
                title: Text(
                  match.note.title,
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                subtitle: Text(match.note.ref.path),
                onTap: () => _open(match.note, 0),
              ),
            if (match.line > 0 || match.text != match.note.title)
              ListTile(
                contentPadding: const EdgeInsets.only(left: 56, right: 16),
                title: Text(match.text, maxLines: 2),
                trailing: Text('${match.line + 1}'),
                onTap: () => _open(match.note, match.line),
              ),
          ],
        );
      },
    );
  }

  Iterable<_NoteTask> _tasks(List<IndexedNote> notes) sync* {
    final matches = _matcher(_query.text);
    for (final note in notes) {
      for (final task in tasksOf(note.blocks)) {
        if (matches(task.title)) yield _NoteTask(note, task);
      }
    }
  }

  Widget _taskTile(_NoteTask entry, {String? date}) {
    final _NoteTask(:note, :task) = entry;
    final year = DateTime.now().year;
    final details = [
      note.title,
      ?date,
      if (task.priority case final priority?) context.l10n.priority(priority),
    ];
    return ListTile(
      leading: GestureDetector(
        onTap: () =>
            _edit(note, (source) => cycleTodo(source, note.blocks, task.line)),
        onLongPressStart: (press) async {
          final edit = await pickTaskEdit(
            context,
            position: press.globalPosition,
            blocks: note.blocks,
            line: task.line,
            status: task.status,
            due: task.date('<', defaultYear: year),
          );
          if (edit != null) await _edit(note, edit);
        },
        child: SizedBox(
          width: 48,
          child: Text(
            todoIcon(context, task.status),
            style: todoStyle(context, task.status),
          ),
        ),
      ),
      title: Text(task.title),
      subtitle: Text(details.join(' · ')),
      onTap: () => _open(note, task.line),
    );
  }

  Widget _taskList(List<IndexedNote> notes) {
    final year = DateTime.now().year;
    final far = DateTime(9999);
    final tasks =
        _tasks(notes)
            .where((entry) => _statuses.contains(entry.task.status))
            .toList()
          ..sort((a, b) {
            final byStatus =
                _statusOrder.indexOf(a.task.status) -
                _statusOrder.indexOf(b.task.status);
            if (byStatus != 0) return byStatus;
            return (a.task.date('<', defaultYear: year) ?? far).compareTo(
              b.task.date('<', defaultYear: year) ?? far,
            );
          });
    return Column(
      children: [
        SizedBox(
          height: 56,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
            children: [
              for (final status in _statusOrder)
                Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: FilterChip(
                    label: Text(
                      '${todoIcon(context, status)} '
                      '${todoLabel(context.l10n, status)}',
                    ),
                    selected: _statuses.contains(status),
                    onSelected: (selected) => setState(() {
                      selected
                          ? _statuses.add(status)
                          : _statuses.remove(status);
                    }),
                  ),
                ),
            ],
          ),
        ),
        Expanded(
          child: tasks.isEmpty
              ? _empty()
              : ListView.builder(
                  itemCount: tasks.length,
                  itemBuilder: (context, index) => _taskTile(tasks[index]),
                ),
        ),
      ],
    );
  }

  String _dateLabel(_Dated dated) {
    final l10n = context.l10n;
    final day = MaterialLocalizations.of(context).formatMediumDate(dated.date);
    return switch (dated.marker) {
      '<' => l10n.dueOn(day),
      '>' => l10n.startsOn(day),
      _ => l10n.happensOn(day),
    };
  }

  String _dayHeader(DateTime day, DateTime today) {
    final l10n = context.l10n;
    final difference = DateUtils.dateOnly(day).difference(today).inDays;
    return switch (difference) {
      0 => l10n.today,
      1 => l10n.tomorrow,
      _ => MaterialLocalizations.of(context).formatFullDate(day),
    };
  }

  Widget _agenda(List<IndexedNote> notes) {
    final year = DateTime.now().year;
    final today = DateUtils.dateOnly(DateTime.now());
    final dated = [
      for (final entry in _tasks(notes))
        if (!_closed.contains(entry.task.status))
          for (final marker in _dateMarkers)
            if (entry.task.date(marker, defaultYear: year) case final date?)
              _Dated(entry, marker, date),
    ]..sort((a, b) => a.date.compareTo(b.date));
    final overdue = [
      for (final item in dated)
        if (item.marker == '<' && item.date.isBefore(today)) item,
    ];
    final upcoming = [
      for (final item in dated)
        if (!item.date.isBefore(today)) item,
    ];
    if (overdue.isEmpty && upcoming.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(context.l10n.noDatedTasks, textAlign: TextAlign.center),
        ),
      );
    }
    Widget header(String text, {Color? color}) => Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
      child: Text(
        text,
        style: Theme.of(context).textTheme.titleSmall?.copyWith(color: color),
      ),
    );
    return ListView(
      children: [
        if (overdue.isNotEmpty) ...[
          header(
            context.l10n.overdue,
            color: Theme.of(context).colorScheme.error,
          ),
          for (final item in overdue)
            _taskTile(item.entry, date: _dateLabel(item)),
        ],
        for (final (index, item) in upcoming.indexed) ...[
          if (index == 0 ||
              !DateUtils.isSameDay(upcoming[index - 1].date, item.date))
            header(_dayHeader(item.date, today)),
          _taskTile(item.entry, date: _dateLabel(item)),
        ],
      ],
    );
  }
}
