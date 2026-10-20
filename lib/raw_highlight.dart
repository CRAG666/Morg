import 'dart:math';

import 'package:flutter/painting.dart';

import 'norg/ast.dart';
import 'norg/parser.dart';
import 'theme/norg_theme.dart';

final linkLocation = RegExp(r'^(\*{1,6}|#|\$|\^|\?|/|@|=)\s+(.+)$');
final _detached = RegExp(
  r'^(\s*)(\*+|-+|~+|>+|\$\$?|\^\^?)(\s+)(\([^)]*\)\s+)?(.*)$',
);
final _tag = RegExp(r'^(\s*)([@|=#+.][\w.\-]+)(.*)$');
final _delimiterLine = RegExp(r'^\s*(-{2,}|={2,}|_{2,})\s*$');

const todoGroups = {
  TodoStatus.undone: 'undone',
  TodoStatus.done: 'done',
  TodoStatus.pending: 'pending',
  TodoStatus.needsInput: 'uncertain',
  TodoStatus.onHold: 'on_hold',
  TodoStatus.cancelled: 'cancelled',
  TodoStatus.recurring: 'recurring',
  TodoStatus.urgent: 'urgent',
};

String linkGroup(String target) {
  if (Uri.tryParse(target) case final uri? when uri.hasScheme) {
    return '@neorg.links.location.url';
  }
  if (target.startsWith(':')) return '@neorg.links.file';
  final marker = linkLocation.firstMatch(target)?[1];
  return switch (marker) {
    null => '@neorg.links.location.url',
    '#' || '?' || '=' || '@' => '@neorg.links.location.generic',
    r'$' => '@neorg.links.location.definition',
    '^' => '@neorg.links.location.footnote',
    '/' => '@neorg.links.location.external_file',
    _ => '@neorg.links.location.heading.${marker.length}',
  };
}

typedef _Region = (int start, int end, List<InlineSpan> Function() build);

class RawHighlighter {
  const RawHighlighter(this.theme, this.base);

  final NorgTheme theme;
  final TextStyle base;

  TextStyle _hl(String group, [TextStyle? on]) =>
      theme[group].apply(on ?? base);

  TextSpan highlight(String text) {
    final children = <InlineSpan>[];
    var verbatim = false;
    for (final (index, line) in text.split('\n').indexed) {
      if (index > 0) children.add(const TextSpan(text: '\n'));
      final trimmed = line.trim();
      if (verbatim && trimmed != '@end') {
        children.add(TextSpan(text: line));
        continue;
      }
      verbatim = trimmed.startsWith('@') && trimmed != '@end';
      children.addAll(_line(line));
    }
    return TextSpan(style: base, children: children);
  }

  List<InlineSpan> _line(String line) {
    if (_delimiterLine.hasMatch(line)) {
      return [
        TextSpan(text: line, style: _hl('@neorg.delimiters.horizontal_line')),
      ];
    }
    if (_detached.firstMatch(line) case final match?) {
      final marker = match[2]!;
      final level = min(marker.length, 6);
      final (prefix, content) = switch (marker[0]) {
        '*' => (
          '@neorg.headings.$level.prefix',
          '@neorg.headings.$level.title',
        ),
        '-' => ('@neorg.lists.unordered.prefix', null),
        '~' => ('@neorg.lists.ordered.prefix', null),
        '>' => ('@neorg.quotes.$level.prefix', '@neorg.quotes.$level.content'),
        r'$' => ('@neorg.definitions.prefix', '@neorg.definitions.title'),
        _ => ('@neorg.footnotes.prefix', '@neorg.footnotes.title'),
      };
      final extension = match[4];
      final status = extension == null
          ? null
          : todoStatusOf(extension.trim().replaceAll(RegExp(r'^\(|\)$'), ''));
      return [
        TextSpan(text: match[1]),
        TextSpan(text: marker, style: _hl(prefix)),
        TextSpan(text: match[3]),
        if (extension != null)
          TextSpan(
            text: extension,
            style: status == null
                ? null
                : _hl('@neorg.todo_items.${todoGroups[status]}'),
          ),
        ..._inline(match[5]!, content == null ? base : _hl(content)),
      ];
    }
    if (_tag.firstMatch(line) case final match?) {
      final carryover = '#+.'.contains(match[2]![0]);
      return [
        TextSpan(text: match[1]),
        TextSpan(
          text: match[2],
          style: _hl(
            carryover
                ? '@neorg.tags.carryover.begin'
                : '@neorg.tags.ranged_verbatim.begin',
          ),
        ),
        TextSpan(
          text: match[3],
          style: _hl(
            carryover
                ? '@neorg.tags.carryover.parameters'
                : '@neorg.tags.ranged_verbatim.parameters',
          ),
        ),
      ];
    }
    return _inline(line, base);
  }

  List<InlineSpan> _inline(String raw, TextStyle style) =>
      _nodes(raw, parseInline(raw), style, 0, raw.length);

  List<InlineSpan> _nodes(
    String raw,
    List<Inline> nodes,
    TextStyle style,
    int from,
    int to,
  ) {
    final spans = <InlineSpan>[];
    var cursor = from;
    for (final node in nodes) {
      if (node.start > cursor) {
        spans.add(
          TextSpan(text: raw.substring(cursor, node.start), style: style),
        );
      }
      spans.addAll(_node(raw, node, style));
      cursor = node.end;
    }
    if (cursor < to) {
      spans.add(TextSpan(text: raw.substring(cursor, to), style: style));
    }
    return spans;
  }

  List<InlineSpan> _node(String raw, Inline node, TextStyle style) {
    List<InlineSpan> children(List<Inline> nodes, TextStyle on) =>
        _nodes(raw, nodes, on, nodes.first.start, nodes.last.end);
    _Region inner(List<Inline> nodes, TextStyle on) =>
        (nodes.first.start, nodes.last.end, () => children(nodes, on));

    switch (node) {
      case TextInline():
        return [
          TextSpan(text: raw.substring(node.start, node.end), style: style),
        ];
      case StyledInline(style: final kind, children: final nested):
        final group = '@neorg.markup.${kind.name}';
        return _container(raw, node, _hl('$group.delimiter'), [
          inner(nested, _hl(group, style)),
        ]);
      case VerbatimInline(:final kind, :final text):
        final group = switch (kind) {
          VerbatimKind.code => '@neorg.markup.verbatim',
          VerbatimKind.math => '@neorg.markup.inline_math',
          VerbatimKind.variable => '@neorg.markup.variable',
          VerbatimKind.comment => '@neorg.markup.inline_comment',
        };
        final pad = (node.end - node.start - text.length) ~/ 2;
        final (start, end) = (node.start + pad, node.end - pad);
        return _container(raw, node, _hl('$group.delimiter'), [
          (
            start,
            end,
            () => [
              TextSpan(
                text: raw.substring(start, end),
                style: _hl(group, style),
              ),
            ],
          ),
        ]);
      case AnchorInline(:final description):
        const group = '@neorg.anchors.declaration';
        return _container(raw, node, _hl('$group.delimiter'), [
          inner(description, _hl(group, style)),
        ]);
      case LinkInline(:final target, :final description):
        final targetStart = raw.indexOf('{', node.start) + 1;
        final targetEnd = targetStart + target.length;
        return _container(raw, node, _hl('@neorg.links.location.delimiter'), [
          (
            targetStart,
            targetEnd,
            () => [
              TextSpan(
                text: raw.substring(targetStart, targetEnd),
                style: _hl(linkGroup(target), style),
              ),
            ],
          ),
          if (description.isNotEmpty)
            inner(description, _hl('@neorg.links.description', style)),
        ]);
    }
  }

  List<InlineSpan> _container(
    String raw,
    Inline node,
    TextStyle delimiter,
    List<_Region> regions,
  ) {
    final spans = <InlineSpan>[];
    var cursor = node.start;
    for (final (start, end, build) in regions..sort((a, b) => a.$1 - b.$1)) {
      if (start > cursor) {
        spans.add(
          TextSpan(text: raw.substring(cursor, start), style: delimiter),
        );
      }
      spans.addAll(build());
      cursor = end;
    }
    if (cursor < node.end) {
      spans.add(
        TextSpan(text: raw.substring(cursor, node.end), style: delimiter),
      );
    }
    return spans;
  }
}
