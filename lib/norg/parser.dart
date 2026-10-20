import 'ast.dart';

const _statuses = {
  'x': TodoStatus.done,
  '?': TodoStatus.needsInput,
  '!': TodoStatus.urgent,
  '+': TodoStatus.recurring,
  '-': TodoStatus.pending,
  '=': TodoStatus.onHold,
  '_': TodoStatus.cancelled,
};

const _styles = {
  '*': InlineStyle.bold,
  '/': InlineStyle.italic,
  '_': InlineStyle.underline,
  '-': InlineStyle.strikethrough,
  '!': InlineStyle.spoiler,
  '^': InlineStyle.superscript,
  ',': InlineStyle.subscript,
};

const _verbatims = {
  '`': VerbatimKind.code,
  r'$': VerbatimKind.math,
  '&': VerbatimKind.variable,
};

const _nullModifier = '%';

final _headingLine = RegExp(r'^(\*+)\s+(.*)$');
final _nestableLine = RegExp(r'^(-+|~+|>+)\s+(.*)$');
final _delimiterLine = RegExp(r'^(-{2,}|={2,}|_{2,})$');
final _rangeableLine = RegExp(r'^(\$\$?|\^\^?)\s+(.*)$');
final _rangedTagLine = RegExp(r'^([@|=])([\w.\-]+)\s*(.*)$');
final _carryoverLine = RegExp(
  r'^([#+.])([\p{L}_][\w.\-]*)\s*(.*)$',
  unicode: true,
);
final _extension = RegExp(r'^\(([^)]*)\)\s+(.*)$');
final _tableSeparator = RegExp(r'^[\s|:+\-]+$');
final _wordChar = RegExp(r'[\p{L}\p{N}]', unicode: true);

List<Block> parseNorg(String source) =>
    _BlockParser(source.replaceAll('\r\n', '\n').split(RegExp('[\n\r\f]')))
        .parse();

class _BlockParser {
  _BlockParser(this.lines, {this.offset = 0});

  final List<String> lines;
  final int offset;
  var pos = 0;

  String get current => lines[pos].trim();

  List<Block> parse() {
    final root = <Block>[];
    final openHeadings = <Heading>[];
    void add(Block block) =>
        (openHeadings.isEmpty ? root : openHeadings.last.children).add(block);

    while (pos < lines.length) {
      final line = current;
      if (line.isEmpty) {
        pos++;
        continue;
      }
      if (_delimiterLine.firstMatch(line) case final match?) {
        pos++;
        final marker = match[1]!;
        final kind = switch (marker[0]) {
          '-' => DelimiterKind.weak,
          '=' => DelimiterKind.strong,
          _ => DelimiterKind.horizontal,
        };
        if (kind == DelimiterKind.weak && openHeadings.isNotEmpty) {
          openHeadings.removeLast();
        } else if (kind == DelimiterKind.strong) {
          openHeadings.clear();
        }
        add(DelimiterLine(kind, marker.length));
        continue;
      }
      if (_rangedTagLine.firstMatch(line) case final match?) {
        pos++;
        final block = _rangedTag(match[1]!, match[2]!, match[3]!);
        if (block != null) add(block);
        continue;
      }
      if (_carryoverLine.firstMatch(line) case final match?) {
        pos++;
        if (match[1] == '.') add(InfirmTag(match[2]!, match[3]!));
        continue;
      }
      if (_headingLine.firstMatch(line) case final match?) {
        pos++;
        final level = match[1]!.length.clamp(1, 6);
        final (status, title) = _splitExtension(match[2]!);
        final heading = Heading(
          level,
          parseInline(title),
          status,
          line: offset + pos - 1,
        );
        while (openHeadings.isNotEmpty && openHeadings.last.level >= level) {
          openHeadings.removeLast();
        }
        add(heading);
        openHeadings.add(heading);
        continue;
      }
      if (_nestableLine.firstMatch(line) case final match?) {
        add(match[1]![0] == '>' ? _quote() : _list());
        continue;
      }
      if (_rangeableLine.firstMatch(line) case final match?) {
        pos++;
        add(_rangeable(match[1]!, match[2]!));
        continue;
      }
      add(Paragraph(parseInline(_paragraphText())));
    }
    return root;
  }

  Block? _rangedTag(String prefix, String name, String params) {
    final bodyStart = offset + pos;
    final body = _collectRanged(prefix);
    return switch ((prefix, name)) {
      ('@', 'document.meta') => DocumentMeta(_metaFields(body)),
      ('@', 'code') => CodeBlock(
        params.split(RegExp(r'\s+')).first.nullIfEmpty,
        _dedent(body),
      ),
      ('@', 'table') => TableBlock(_tableRows(body)),
      ('@', _) => CodeBlock(null, _dedent(body)),
      ('|', 'comment') => RangedBlock(name, params, [
        Paragraph([VerbatimInline(VerbatimKind.comment, _dedent(body))]),
      ]),
      ('=', _) => null,
      ('|', 'example') => CodeBlock('norg', _dedent(body)),
      ('|', _) => RangedBlock(
        name,
        params,
        _BlockParser(body, offset: bodyStart).parse(),
      ),
      _ => throw StateError('Unknown ranged tag prefix "$prefix"'),
    };
  }

  List<String> _collectRanged(String prefix) {
    final body = <String>[];
    var depth = 0;
    while (pos < lines.length) {
      final line = current;
      pos++;
      if (line == '${prefix}end') {
        if (depth == 0) return body;
        depth--;
      } else if (prefix != '@' &&
          line.startsWith(prefix) &&
          _rangedTagLine.hasMatch(line)) {
        depth++;
      }
      body.add(lines[pos - 1]);
    }
    return body;
  }

  Block _rangeable(String marker, String title) {
    final isRanged = marker.length == 2;
    final content = isRanged
        ? _BlockParser(_collectUntilLine(marker), offset: offset + pos).parse()
        : [
            if (pos < lines.length &&
                current.isNotEmpty &&
                !_isBlockStart(current))
              Paragraph(parseInline(_paragraphText())),
          ];
    return marker[0] == r'$'
        ? Definition(parseInline(title), content, ranged: isRanged)
        : Footnote(title, content, ranged: isRanged);
  }

  List<String> _collectUntilLine(String closer) {
    final start = pos;
    while (pos < lines.length && current != closer) {
      pos++;
    }
    final body = lines.sublist(start, pos);
    if (pos < lines.length) pos++;
    return body;
  }

  ListBlock _list() {
    final items = <ListItem>[];
    while (pos < lines.length) {
      final match = _nestableLine.firstMatch(current);
      if (match == null || match[1]![0] == '>') break;
      pos++;
      final line = offset + pos - 1;
      final marker = match[1]!;
      final (status, text) = _splitExtension(match[2]!);
      final kind = marker[0] == '~'
          ? NestableKind.ordered
          : NestableKind.unordered;
      items.add(
        ListItem(
          kind,
          marker.length,
          status,
          parseInline(_continuation(text)),
          line: line,
        ),
      );
    }
    return ListBlock(items);
  }

  QuoteBlock _quote() {
    final quoteLines = <QuoteLine>[];
    while (pos < lines.length) {
      final match = _nestableLine.firstMatch(current);
      if (match == null || match[1]![0] != '>') break;
      pos++;
      quoteLines.add(
        QuoteLine(match[1]!.length, parseInline(_continuation(match[2]!))),
      );
    }
    return QuoteBlock(quoteLines);
  }

  String _continuation(String first) {
    final buffer = StringBuffer(first);
    while (pos < lines.length &&
        current.isNotEmpty &&
        !_isBlockStart(current)) {
      buffer.write(' $current');
      pos++;
    }
    return buffer.toString();
  }

  String _paragraphText() {
    final segments = <String>[];
    while (pos < lines.length &&
        current.isNotEmpty &&
        (segments.isEmpty || !_isBlockStart(current))) {
      segments.add(current);
      pos++;
    }
    return segments.join(' ');
  }
}

bool _isBlockStart(String line) =>
    _headingLine.hasMatch(line) ||
    _nestableLine.hasMatch(line) ||
    _delimiterLine.hasMatch(line) ||
    _rangeableLine.hasMatch(line) ||
    _rangedTagLine.hasMatch(line) ||
    _carryoverLine.hasMatch(line);

(TodoStatus?, String) _splitExtension(String text) {
  final match = _extension.firstMatch(text);
  if (match == null) return (null, text);
  final first = match[1]!.split('|').first;
  final status = first.trim().isEmpty
      ? TodoStatus.undone
      : _statuses[first.trim()[0]];
  return (status, match[2]!);
}

Map<String, String> _metaFields(List<String> body) {
  final fields = <String, String>{};
  for (var index = 0; index < body.length; index++) {
    final line = body[index].trim();
    final colon = line.indexOf(':');
    if (colon <= 0) continue;
    var value = line.substring(colon + 1).trim();
    if (value == '[') {
      final values = <String>[];
      while (++index < body.length && body[index].trim() != ']') {
        values.add(body[index].trim());
      }
      value = values.join(', ');
    }
    fields[line.substring(0, colon).trim()] = value;
  }
  return fields;
}

String _dedent(List<String> body) {
  final indents = body
      .where((line) => line.trim().isNotEmpty)
      .map((line) => line.length - line.trimLeft().length);
  final indent = indents.isEmpty ? 0 : indents.reduce((a, b) => a < b ? a : b);
  return body
      .map((line) => line.length < indent ? '' : line.substring(indent))
      .join('\n')
      .trimRight();
}

List<List<List<Inline>>> _tableRows(List<String> body) => [
  for (final line in body.map((line) => line.trim()))
    if (line.isNotEmpty && !_tableSeparator.hasMatch(line))
      [
        for (final cell in _stripPipes(line).split('|'))
          parseInline(cell.trim()),
      ],
];

String _stripPipes(String line) {
  final start = line.startsWith('|') ? 1 : 0;
  final end = line.endsWith('|') && line.length > start
      ? line.length - 1
      : line.length;
  return line.substring(start, end);
}

bool _isWhitespace(String char) => char.trim().isEmpty;

bool _isPunctuation(String char) =>
    !_isWhitespace(char) && !_wordChar.hasMatch(char);

bool _isBoundary(String text, int index) =>
    index < 0 ||
    index >= text.length ||
    _isWhitespace(text[index]) ||
    _isPunctuation(text[index]);

List<Inline> parseInline(String text) {
  final nodes = <Inline>[];
  final plain = StringBuffer();
  void emit(Inline node) {
    if (plain.isNotEmpty) {
      nodes.add(TextInline(plain.toString()));
      plain.clear();
    }
    nodes.add(node);
  }

  var index = 0;
  while (index < text.length) {
    final char = text[index];
    if (char == r'\' && index + 1 < text.length) {
      plain.write(text[index + 1]);
      index += 2;
      continue;
    }
    final linkable = _linkable(text, index) ?? _attached(text, index);
    if (linkable != null) {
      final (node, next) = linkable;
      emit(node);
      index = next;
      continue;
    }
    if (_linkModifier(text, index) case (final node, final next)) {
      emit(node);
      index = next;
      continue;
    }
    plain.write(char);
    index++;
  }
  if (plain.isNotEmpty) nodes.add(TextInline(plain.toString()));
  return nodes;
}

(Inline, int)? _linkable(String text, int index) {
  final char = text[index];
  if (char == '{') {
    final close = text.indexOf('}', index + 1);
    if (close <= index + 1) return null;
    final target = text.substring(index + 1, close);
    final description = _bracketed(text, close + 1);
    return description == null
        ? (LinkInline(target, const []), close + 1)
        : (LinkInline(target, parseInline(description.$1)), description.$2);
  }
  if (char == '[') {
    final description = _bracketed(text, index);
    if (description == null) return null;
    final (label, next) = description;
    if (next < text.length && text[next] == '{') {
      final close = text.indexOf('}', next + 1);
      if (close > next + 1) {
        return (
          LinkInline(text.substring(next + 1, close), parseInline(label)),
          close + 1,
        );
      }
    }
    return (AnchorInline(parseInline(label)), next);
  }
  if (char == '<' &&
      index + 1 < text.length &&
      !_isWhitespace(text[index + 1])) {
    final close = text.indexOf('>', index + 1);
    if (close > index + 1 && !_isWhitespace(text[close - 1])) {
      return (TextInline(text.substring(index + 1, close)), close + 1);
    }
  }
  return null;
}

(Inline, int)? _linkModifier(String text, int index) {
  final isWordBefore = index > 0 && _wordChar.hasMatch(text[index - 1]);
  if (text[index] != ':' || !isWordBefore || index + 1 >= text.length) {
    return null;
  }
  final attached = _attached(text, index + 1);
  if (attached == null) return null;
  final (node, end) = attached;
  final closes =
      end + 1 < text.length &&
      text[end] == ':' &&
      _wordChar.hasMatch(text[end + 1]);
  return (node, closes ? end + 1 : end);
}

(String, int)? _bracketed(String text, int index) {
  if (index >= text.length || text[index] != '[') return null;
  final close = text.indexOf(']', index + 1);
  if (close <= index + 1) return null;
  return (text.substring(index + 1, close), close + 1);
}

(Inline, int)? _attached(String text, int index) {
  final char = text[index];
  final isModifier =
      _styles.containsKey(char) ||
      _verbatims.containsKey(char) ||
      char == _nullModifier;
  if (!isModifier ||
      !_isBoundary(text, index - 1) ||
      index + 1 >= text.length) {
    return null;
  }
  final next = text[index + 1];
  if (_isWhitespace(next) || next == char) return null;

  final freeFormClose = next == '|'
      ? _freeFormClose(text, index + 2, char)
      : null;
  final freeForm = freeFormClose != null;
  final contentStart = index + (freeForm ? 2 : 1);
  final close = freeFormClose ?? _standardClose(text, contentStart, char);
  if (close == null) return null;

  final content = text.substring(contentStart, freeForm ? close - 1 : close);
  final end = close + 1;
  if (char == _nullModifier) {
    return (VerbatimInline(VerbatimKind.comment, content), end);
  }
  if (_verbatims[char] case final kind?) {
    return (VerbatimInline(kind, content), end);
  }
  return (StyledInline(_styles[char]!, parseInline(content)), end);
}

int? _freeFormClose(String text, int start, String char) {
  for (var index = start + 1; index < text.length; index++) {
    if (text[index] == char &&
        text[index - 1] == '|' &&
        _isBoundary(text, index + 1)) {
      return index;
    }
  }
  return null;
}

int? _standardClose(String text, int start, String char) {
  final verbatim = _verbatims.containsKey(char);
  for (var index = start + 1; index < text.length; index++) {
    final current = text[index];
    if (!verbatim && current == r'\') {
      index++;
      continue;
    }
    if (!verbatim && current == '{') {
      final close = text.indexOf('}', index);
      if (close > index) index = close;
      continue;
    }
    if (current == char &&
        !_isWhitespace(text[index - 1]) &&
        _isBoundary(text, index + 1)) {
      return index;
    }
  }
  return null;
}

extension on String {
  String? get nullIfEmpty => isEmpty ? null : this;
}
