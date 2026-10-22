import 'dart:math';

import 'ast.dart';
import 'dates.dart';
import 'targets.dart';

final _headingPrefix = RegExp(r'^(\s*)(\*+)(?=\s)');
final _itemPrefix = RegExp(r'^(\s*)(-+|~+)(?=\s)');

Iterable<Block> walkBlocks(List<Block> blocks) sync* {
  for (final block in blocks) {
    yield block;
    switch (block) {
      case Heading(children: final nested) ||
          RangedBlock(children: final nested) ||
          Definition(content: final nested) ||
          Footnote(content: final nested):
        yield* walkBlocks(nested);
      default:
    }
  }
}

Iterable<Heading> headingsOf(List<Block> blocks) =>
    walkBlocks(blocks).whereType<Heading>();

Heading? headingAt(List<Block> blocks, int line) =>
    headingsOf(blocks).where((heading) => heading.line == line).firstOrNull;

ListItem? listItemAt(List<Block> blocks, int line) =>
    walkBlocks(blocks)
        .whereType<ListBlock>()
        .expand((list) => list.items)
        .where((item) => item.line == line)
        .firstOrNull;

int subtreeEnd(Block block) => switch (block) {
  Heading(:final children) => children.fold(
    block.range.end,
    (end, child) => max(end, subtreeEnd(child)),
  ),
  _ => block.range.end,
};

sealed class _Element {
  const _Element();
}

class _HeadingElement extends _Element {
  const _HeadingElement(this.heading, this.siblings);
  final Heading heading;
  final List<Block> siblings;
}

class _ItemElement extends _Element {
  const _ItemElement(this.items, this.index);
  final List<ListItem> items;
  final int index;

  ListItem get item => items[index];

  int get lastDescendant {
    var last = index;
    while (last + 1 < items.length && items[last + 1].level > item.level) {
      last++;
    }
    return last;
  }

  (int, int) get span => (item.line, items[lastDescendant].range.end);

  Iterable<int> get siblings sync* {
    var start = index;
    while (start > 0 && items[start - 1].level >= item.level) {
      start--;
    }
    for (var other = start; other < items.length; other++) {
      if (items[other].level < item.level) return;
      if (items[other].level == item.level) yield other;
    }
  }
}

_Element? _elementAt(List<Block> blocks, int line) {
  for (final block in blocks) {
    final found = switch (block) {
      Heading() when block.line == line => _HeadingElement(block, blocks),
      ListBlock(:final items) => switch (items.indexWhere(
        (item) => item.line == line,
      )) {
        -1 => null,
        final position => _ItemElement(items, position),
      },
      Heading(children: final nested) ||
      RangedBlock(children: final nested) ||
      Definition(content: final nested) ||
      Footnote(content: final nested) => _elementAt(nested, line),
      _ => null,
    };
    if (found != null) return found;
  }
  return null;
}

String? changeLevel(String source, List<Block> blocks, int line, int delta) {
  final lines = source.split('\n');
  final (pattern, start, end) = switch (_elementAt(blocks, line)) {
    _HeadingElement(:final heading) => (
      _headingPrefix,
      heading.line,
      subtreeEnd(heading),
    ),
    final _ItemElement element => (
      _itemPrefix,
      element.span.$1,
      element.span.$2,
    ),
    null => (null, 0, 0),
  };
  if (pattern == null) return null;
  final ownLevel = pattern.firstMatch(lines[start])![2]!.length;
  if (ownLevel + delta < 1) return null;
  for (var index = start; index < end; index++) {
    lines[index] = lines[index].replaceFirstMapped(pattern, (match) {
      final marker = match[2]!;
      final level = max(1, marker.length + delta);
      return '${match[1]}${marker[0] * level}';
    });
  }
  return lines.join('\n');
}

String? move(String source, List<Block> blocks, int line, int direction) {
  final spans = switch (_elementAt(blocks, line)) {
    _HeadingElement(:final heading, :final siblings) => () {
      final headings = siblings.whereType<Heading>().toList();
      final index = headings.indexOf(heading);
      final other = index + direction;
      if (other < 0 || other >= headings.length) return null;
      (int, int) span(Heading heading) => (heading.line, subtreeEnd(heading));
      return (span(heading), span(headings[other]));
    }(),
    final _ItemElement element => () {
      final siblings = element.siblings.toList();
      final index = siblings.indexOf(element.index);
      final other = index + direction;
      if (other < 0 || other >= siblings.length) return null;
      return (element.span, _ItemElement(element.items, siblings[other]).span);
    }(),
    null => null,
  };
  if (spans == null) return null;
  final (own, other) = spans;
  final (first, second) = own.$1 < other.$1 ? (own, other) : (other, own);
  final lines = source.split('\n');
  lines.replaceRange(first.$1, second.$2, [
    ...lines.sublist(second.$1, second.$2),
    ...lines.sublist(first.$2, second.$1),
    ...lines.sublist(first.$1, first.$2),
  ]);
  return lines.join('\n');
}

String? toggleListKind(String source, List<Block> blocks, int line) {
  if (_elementAt(blocks, line) case final _ItemElement element) {
    final lines = source.split('\n');
    final marker = element.item.kind == NestableKind.ordered ? '-' : '~';
    for (final sibling in element.siblings) {
      final itemLine = element.items[sibling].line;
      lines[itemLine] = lines[itemLine].replaceFirstMapped(
        _itemPrefix,
        (match) => '${match[1]}${marker * match[2]!.length}',
      );
    }
    return lines.join('\n');
  }
  return null;
}

String? deleteElement(String source, List<Block> blocks, int line) {
  final (start, end) = switch (_elementAt(blocks, line)) {
    _HeadingElement(:final heading) => (heading.line, subtreeEnd(heading)),
    final _ItemElement element => element.span,
    null => (-1, -1),
  };
  if (start < 0) return null;
  final lines = source.split('\n')..removeRange(start, end);
  final blankAround =
      start > 0 &&
      start < lines.length &&
      lines[start - 1].trim().isEmpty &&
      lines[start].trim().isEmpty;
  if (blankAround) lines.removeAt(start);
  return lines.join('\n');
}

(int done, int total)? progressOfHeading(Heading heading) =>
    _progress(heading.children.whereType<Heading>().map((child) => child.task));

List<(int done, int total)?> progressOfItems(List<ListItem> items) {
  final done = List.filled(items.length, 0);
  final total = List.filled(items.length, 0);
  final open = <int>[];
  for (final (index, item) in items.indexed) {
    while (open.isNotEmpty && items[open.last].level >= item.level) {
      open.removeLast();
    }
    if (open.isNotEmpty &&
        items[open.last].level == item.level - 1 &&
        _counted.contains(item.status)) {
      total[open.last]++;
      if (item.status == TodoStatus.done) done[open.last]++;
    }
    open.add(index);
  }
  return [
    for (var index = 0; index < items.length; index++)
      total[index] == 0 ? null : (done[index], total[index]),
  ];
}

const _counted = {
  TodoStatus.done,
  TodoStatus.pending,
  TodoStatus.undone,
  TodoStatus.urgent,
};

(int, int)? _progress(Iterable<TaskExtension?> tasks) {
  final counted = [
    for (final task in tasks)
      if (task?.status case final status? when _counted.contains(status))
        status,
  ];
  if (counted.isEmpty) return null;
  return (
    counted.where((status) => status == TodoStatus.done).length,
    counted.length,
  );
}

String progressLabel((int, int) progress) {
  final (done, total) = progress;
  return '[$done/$total] (${done * 100 ~/ total}%)';
}

class TaskEntry {
  const TaskEntry(this.line, this.status, this.title, this.details);

  final int line;
  final TodoStatus status;
  final String title;
  final List<String> details;

  DateTime? date(String marker, {required int defaultYear}) =>
      taskDate(details, marker, defaultYear: defaultYear);

  String? get priority => details
      .where((detail) => detail.startsWith('# '))
      .map((detail) => detail.substring(2).trim())
      .firstOrNull;
}

Iterable<TaskEntry> tasksOf(List<Block> blocks) sync* {
  TaskEntry? entry(int line, TaskExtension? task, List<Inline> title) =>
      switch (task) {
        TaskExtension(:final status?, :final details) => TaskEntry(
          line,
          status,
          plainText(title),
          details,
        ),
        _ => null,
      };

  for (final block in walkBlocks(blocks)) {
    final entries = switch (block) {
      Heading(:final line, :final task, :final title) => [
        entry(line, task, title),
      ],
      ListBlock(:final items) => [
        for (final item in items) entry(item.line, item.task, item.content),
      ],
      Definition(:final task, :final term) => [
        entry(block.range.start, task, term),
      ],
      Footnote(:final task, :final title) => [
        entry(block.range.start, task, [TextInline(title)]),
      ],
      _ => const <TaskEntry?>[],
    };
    yield* entries.nonNulls;
  }
}

DateTime? taskDate(
  List<String> details,
  String marker, {
  required int defaultYear,
}) => switch (details
    .where((detail) => detail.startsWith('$marker '))
    .firstOrNull) {
  final detail? => parseNorgDate(detail.substring(2), defaultYear: defaultYear),
  null => null,
};
