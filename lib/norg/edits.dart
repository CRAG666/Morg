import 'ast.dart';
import 'dates.dart';
import 'parser.dart';

const statusChars = {
  TodoStatus.undone: ' ',
  TodoStatus.done: 'x',
  TodoStatus.pending: '-',
  TodoStatus.onHold: '=',
  TodoStatus.cancelled: '_',
  TodoStatus.urgent: '!',
  TodoStatus.recurring: '+',
  TodoStatus.needsInput: '?',
};
const _order = [TodoStatus.undone, TodoStatus.done, TodoStatus.pending];
const _orderWithChildren = [TodoStatus.undone, TodoStatus.done];

final _detachedPrefix = RegExp(
  r'(\s*(?:\*+|-+|~+|\$\$?|\^\^?)\s+)(\(([^)]*)\)\s+)?',
);
final _updatedField = RegExp(r'^(\s*updated\s*:\s*).*$');

String cycleTodo(String source, List<Block> blocks, int line) =>
    _updateTodo(source, blocks, line, null);

String setTodo(
  String source,
  List<Block> blocks,
  int line,
  TodoStatus status,
) => _updateTodo(source, blocks, line, status);

String _updateTodo(
  String source,
  List<Block> blocks,
  int line,
  TodoStatus? chosen,
) {
  final lines = source.split('\n');
  switch (_locate(blocks, line)) {
    case Heading(:final status) ||
        Definition(task: TaskExtension(:final status)?) ||
        Footnote(task: TaskExtension(:final status)?):
      lines[line] = _withStatus(lines[line], chosen ?? _next(_order, status));
    case (List<ListItem> items, int index):
      _updateListItem(lines, items, index, chosen);
    case _:
      throw ArgumentError.value(line, 'line', 'No TODO item on this line');
  }
  return lines.join('\n');
}

Object? _locate(List<Block> blocks, int line) {
  for (final block in blocks) {
    final found = switch (block) {
      Heading() when block.line == line => block,
      Definition() || Footnote() when block.range.start == line => block,
      Heading(children: final nested) ||
      RangedBlock(children: final nested) ||
      Definition(content: final nested) ||
      Footnote(content: final nested) => _locate(nested, line),
      ListBlock(:final items) => switch (items.indexWhere(
        (item) => item.line == line,
      )) {
        -1 => null,
        final index => (items, index),
      },
      _ => null,
    };
    if (found != null) return found;
  }
  return null;
}

TodoStatus _next(List<TodoStatus> order, TodoStatus? current) {
  final index = current == null ? -1 : order.indexOf(current);
  return index < 0 ? order.first : order[(index + 1) % order.length];
}

void _updateListItem(
  List<String> lines,
  List<ListItem> items,
  int index,
  TodoStatus? chosen,
) {
  final statuses = [for (final item in items) item.status];

  Iterable<int> children(int parent) sync* {
    for (var child = parent + 1; child < items.length; child++) {
      final level = items[child].level;
      if (level <= items[parent].level) return;
      if (level == items[parent].level + 1) yield child;
    }
  }

  int? parentOf(int child) {
    for (var parent = child - 1; parent >= 0; parent--) {
      if (items[parent].level < items[child].level) return parent;
    }
    return null;
  }

  final hasTodoChildren = children(index)
      .any((child) => statuses[child] != null);
  final next =
      chosen ??
      _next(hasTodoChildren ? _orderWithChildren : _order, statuses[index]);

  void makeAll(int item) {
    if (statuses[item] == next) return;
    statuses[item] = next;
    for (final child in children(item)) {
      if (items[child].kind == items[item].kind) makeAll(child);
    }
  }

  makeAll(index);
  for (
    var parent = parentOf(index);
    parent != null;
    parent = parentOf(parent)
  ) {
    if (statuses[parent] == null) break;
    final computed = _parentStatus([
      for (final child in children(parent)) ?statuses[child],
    ]);
    if (computed == null) break;
    statuses[parent] = computed;
  }

  for (final (position, item) in items.indexed) {
    if (statuses[position] case final status? when status != item.status) {
      lines[item.line] = _withStatus(lines[item.line], status);
    }
  }
}

TodoStatus? _parentStatus(List<TodoStatus> children) {
  final counted = children.where((status) => status != TodoStatus.cancelled);
  final total = counted.length;
  if (total == 0) return null;
  int count(TodoStatus status) => counted.where((s) => s == status).length;
  final done = count(TodoStatus.done);
  final uncertain = count(TodoStatus.needsInput);
  final onHold = count(TodoStatus.onHold);
  if (uncertain > 0 && done + uncertain == total) return TodoStatus.needsInput;
  if (onHold > 0 && done + onHold + uncertain == total) {
    return TodoStatus.onHold;
  }
  if (count(TodoStatus.pending) > 0) return TodoStatus.pending;
  if (done == total) return TodoStatus.done;
  if (done == 0) return TodoStatus.undone;
  return TodoStatus.pending;
}

String _withStatus(String line, TodoStatus status) =>
    _withSegments(line, (segments) {
      final char = statusChars[status]!;
      final index = segments.indexWhere(isStatusSegment);
      return index < 0 ? [char, ...segments] : (segments..[index] = char);
    });

String setTaskDate(String source, int line, String marker, DateTime? date) {
  final lines = source.split('\n');
  lines[line] = _withSegments(lines[line], (segments) {
    final kept = segments
        .where((segment) => !segment.trim().startsWith('$marker '))
        .toList();
    return [...kept, if (date != null) '$marker ${norgDate(date)}'];
  });
  return lines.join('\n');
}

String _withSegments(
  String line,
  List<String> Function(List<String> segments) update,
) {
  final match = _detachedPrefix.matchAsPrefix(line);
  if (match == null) {
    throw ArgumentError.value(line, 'line', 'Not a detached modifier');
  }
  final prefix = match[1]!;
  final segments = update(match[2] == null ? [] : match[3]!.split('|'));
  final rest = line.substring(match.end);
  return segments.isEmpty
      ? '$prefix$rest'
      : '$prefix(${segments.join('|')}) $rest';
}

String touchUpdated(String source, DateTime now) {
  final lines = source.split('\n');
  final start = lines.indexWhere((line) => line.trim() == '@document.meta');
  if (start < 0) return source;
  for (var index = start + 1; index < lines.length; index++) {
    if (lines[index].trim() == '@end') break;
    if (_updatedField.firstMatch(lines[index]) case final match?) {
      lines[index] = '${match[1]}${norgTimestamp(now)}';
      return lines.join('\n');
    }
  }
  return source;
}

String norgTimestamp(DateTime time) {
  String two(int value) => value.toString().padLeft(2, '0');
  final offset = time.timeZoneOffset;
  final sign = offset.isNegative ? '-' : '+';
  final minutes = offset.inMinutes.abs();
  return '${time.year}-${two(time.month)}-${two(time.day)}'
      'T${two(time.hour)}:${two(time.minute)}:${two(time.second)}'
      '$sign${two(minutes ~/ 60)}${two(minutes % 60)}';
}

String metadataTemplate({
  required String title,
  required String author,
  required DateTime now,
}) {
  final timestamp = norgTimestamp(now);
  return [
    '@document.meta',
    'title: $title',
    'description: ',
    'authors: $author',
    'categories: ',
    'created: $timestamp',
    'updated: $timestamp',
    'version: 1.1.1',
    '@end',
    '',
  ].join('\n');
}
