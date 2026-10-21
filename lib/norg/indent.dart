import 'dart:math';

import 'ast.dart';
import 'parser.dart';
import 'structure.dart';

final _leading = RegExp(r'^[ \t]*');
final _headingPrefix = RegExp(r'^\s*(\*+)(\s+)');
final _nestablePrefix = RegExp(r'^(-+|~+|>+)\s+(\([^)]*\)\s+)?');

int _width(String line) => _leading.firstMatch(line)![0]!.length;

List<int?> _targets(List<String> lines, List<Block> blocks) {
  final targets = List<int?>.filled(lines.length, null);

  void set(int line, int indent) {
    if (line >= 0 && line < lines.length) targets[line] = indent;
  }

  void fill(int start, int end, int indent) {
    for (var line = start; line < end; line++) {
      set(line, indent);
    }
  }

  int headingContent(Heading heading) =>
      switch (_headingPrefix.firstMatch(lines[heading.line])) {
        final match? => match[1]!.length + match[2]!.length,
        null => 0,
      };

  void verbatim(int start, int end, int column) {
    set(start, column);
    final closed = end - 1 > start && lines[end - 1].trim().startsWith('@end');
    if (closed) set(end - 1, column);
    final content = [
      for (var line = start + 1; line < (closed ? end - 1 : end); line++)
        if (lines[line].trim().isNotEmpty) line,
    ];
    if (content.isEmpty) return;
    final base = content.map((line) => _width(lines[line])).reduce(min);
    for (final line in content) {
      set(line, column + _width(lines[line]) - base);
    }
  }

  void walk(List<Block> blocks, int column) {
    Block? previous;
    for (final block in blocks) {
      final SourceRange(:start, :end) = block.range;
      var tagLine = start - 1;
      for (var tag = 0; tag < block.tags.length; tag++) {
        while (tagLine >= 0 && lines[tagLine].trim().isEmpty) {
          tagLine--;
        }
        set(tagLine--, column);
      }
      switch (block) {
        case Heading(:final line, :final children):
          set(line, 0);
          walk(children, headingContent(block));
        case ListBlock() || QuoteBlock():
          var content = column;
          for (var line = start; line < end; line++) {
            final trimmed = lines[line].trimLeft();
            if (_nestablePrefix.firstMatch(trimmed) case final match?) {
              set(line, column);
              content = column + match[0]!.length;
            } else {
              set(line, content);
            }
          }
        case CodeBlock() ||
            MathBlock() ||
            ImageBlock() ||
            VerbatimTag() ||
            TableBlock() ||
            DocumentMeta():
          verbatim(start, end, column);
        case RangedBlock(children: final nested) ||
            Definition(content: final nested) ||
            Footnote(content: final nested):
          fill(start, end, column);
          walk(nested, column);
        case DelimiterLine(kind: DelimiterKind.weak) when previous is Heading:
          set(start, headingContent(previous));
        case DelimiterLine(kind: DelimiterKind.strong):
          var above = start - 1;
          while (above >= 0 && lines[above].trim().isEmpty) {
            above--;
          }
          final heading = above < 0 ? null : headingAt(blocks, above);
          set(
            start,
            above < 0
                ? 0
                : heading != null
                ? headingContent(heading)
                : targets[above] ?? _width(lines[above]),
          );
        default:
          fill(start, end, column);
      }
      previous = block;
    }
  }

  walk(blocks, 0);
  return targets;
}

String reindent(
  String source, {
  int start = 0,
  int? end,
  bool dedentExcess = true,
  List<Block>? blocks,
}) {
  final lines = source.split('\n');
  final targets = _targets(lines, blocks ?? parseNorg(source));
  for (
    var line = start;
    line < min(end ?? lines.length, lines.length);
    line++
  ) {
    final target = targets[line];
    if (target == null || lines[line].trim().isEmpty) continue;
    final current = _width(lines[line]);
    if (target == current || (!dedentExcess && target < current)) continue;
    lines[line] = ' ' * target + lines[line].substring(current);
  }
  return lines.join('\n');
}

String reindentChanges(
  String before,
  String after, {
  bool dedentExcess = true,
}) {
  final old = before.split('\n');
  final lines = after.split('\n');
  var head = 0;
  while (head < old.length && head < lines.length && old[head] == lines[head]) {
    head++;
  }
  if (head == old.length && head == lines.length) return after;
  var tail = 0;
  while (tail < old.length - head &&
      tail < lines.length - head &&
      old[old.length - 1 - tail] == lines[lines.length - 1 - tail]) {
    tail++;
  }
  var start = head;
  var end = max(lines.length - tail, head + 1);
  final changedEnd = end;
  final blocks = parseNorg(after);
  for (final block in walkBlocks(blocks)) {
    final (from, to, anchor) = block is Heading
        ? (block.line, subtreeEnd(block), block.line)
        : (block.range.start, block.range.end, null);
    final touched = anchor == null
        ? from < changedEnd && to > head
        : anchor >= head && anchor < changedEnd;
    if (touched) {
      start = min(start, from);
      end = max(end, to);
    }
  }
  return reindent(
    after,
    start: start,
    end: end,
    dedentExcess: dedentExcess,
    blocks: blocks,
  );
}
