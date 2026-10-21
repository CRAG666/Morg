import 'dart:convert';
import 'dart:typed_data';

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

List<Block> parseNorg(String source) => _BlockParser(
  const LineSplitter().convert(
    source.contains('\f') ? source.replaceAll('\f', '\n') : source,
  ),
).parse();

class _BlockParser {
  _BlockParser(this.lines, {this.offset = 0});

  final List<String> lines;
  final int offset;
  late final _trimmed = [for (final line in lines) line.trim()];
  var pos = 0;

  String get current => _trimmed[pos];

  List<Block> parse() {
    final root = <Block>[];
    final openHeadings = <Heading>[];
    var blockStart = offset;
    var pendingTags = <CarryoverTag>[];
    void add(Block block) {
      block
        ..range = SourceRange(blockStart, offset + pos)
        ..tags = pendingTags;
      pendingTags = [];
      (openHeadings.isEmpty ? root : openHeadings.last.children).add(block);
    }

    while (pos < lines.length) {
      blockStart = offset + pos;
      final line = current;
      if (line.isEmpty) {
        pos++;
        continue;
      }
      if (!_mayStartBlock(line)) {
        add(Paragraph(parseInline(_paragraphText())));
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
        if (match[1] == '.') {
          add(InfirmTag(match[2]!, match[3]!));
        } else {
          pendingTags.add(CarryoverTag(match[1]!, match[2]!, match[3]!));
        }
        continue;
      }
      if (_headingLine.firstMatch(line) case final match?) {
        pos++;
        final level = match[1]!.length.clamp(1, 6);
        final (task, title) = _splitExtension(match[2]!);
        final heading = Heading(
          level,
          parseInline(title),
          task,
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
      ('@', 'math') => MathBlock(dedent(body)),
      ('@', 'image') => ImageBlock(
        params.split(RegExp(r'\s+')).first,
        body.join().replaceAll(RegExp(r'\s'), ''),
      ),
      ('@', 'code') => CodeBlock(
        params.split(RegExp(r'\s+')).first.nullIfEmpty,
        dedent(body),
      ),
      ('@', 'table') => TableBlock(_tableRows(body)),
      ('@', _) => VerbatimTag(),
      ('|', 'comment') => RangedBlock(name, params, [
        Paragraph([VerbatimInline(VerbatimKind.comment, dedent(body))]),
      ]),
      ('=', _) => null,
      ('|', 'example') => CodeBlock('norg', dedent(body)),
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

  Block _rangeable(String marker, String text) {
    final (task, title) = _splitExtension(text);
    final isRanged = marker.length == 2;
    final bodyStart = offset + pos;
    final content = isRanged
        ? _BlockParser(_collectUntilLine(marker), offset: bodyStart).parse()
        : [
            if (pos < lines.length &&
                current.isNotEmpty &&
                !_isBlockStart(current))
              Paragraph(parseInline(_paragraphText())),
          ];
    return marker[0] == r'$'
        ? Definition(parseInline(title), content, ranged: isRanged, task: task)
        : Footnote(title, content, ranged: isRanged, task: task);
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
      final (task, text) = _splitExtension(match[2]!);
      final kind = marker[0] == '~'
          ? NestableKind.ordered
          : NestableKind.unordered;
      final content = parseInline(_continuation(text));
      items.add(
        ListItem(
          kind,
          marker.length,
          task,
          content,
          line: line,
          range: SourceRange(line, offset + pos),
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
      final (task, text) = _splitExtension(match[2]!);
      quoteLines.add(
        QuoteLine(
          match[1]!.length,
          parseInline(_continuation(text)),
          task: task,
        ),
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

const _blockStartChars = r'*-~>$^@|=#+._';

bool _mayStartBlock(String line) => _blockStartChars.contains(line[0]);

bool _isBlockStart(String line) =>
    _mayStartBlock(line) &&
    (_headingLine.hasMatch(line) ||
        _nestableLine.hasMatch(line) ||
        _delimiterLine.hasMatch(line) ||
        _rangeableLine.hasMatch(line) ||
        _rangedTagLine.hasMatch(line) ||
        _carryoverLine.hasMatch(line));

(TaskExtension?, String) _splitExtension(String text) {
  final match = _extension.firstMatch(text);
  if (match == null) return (null, text);
  final segments = match[1]!.split('|');
  final statusIndex = segments.indexWhere(isStatusSegment);
  final details = [
    for (final (index, segment) in segments.indexed)
      if (index != statusIndex && segment.trim().isNotEmpty) segment.trim(),
  ];
  return (
    TaskExtension(
      statusIndex < 0 ? null : _segmentStatus(segments[statusIndex]),
      details,
    ),
    match[2]!,
  );
}

bool isStatusSegment(String segment) {
  final trimmed = segment.trim();
  return trimmed.isEmpty ||
      _statuses.containsKey(trimmed) ||
      (trimmed.startsWith('+') && trimmed.length > 1 && trimmed[1] == ' ');
}

TodoStatus _segmentStatus(String segment) {
  final trimmed = segment.trim();
  return trimmed.isEmpty ? TodoStatus.undone : _statuses[trimmed[0]]!;
}

TodoStatus? todoStatusOf(String extension) =>
    switch (extension.split('|').where(isStatusSegment).firstOrNull) {
      final segment? => _segmentStatus(segment),
      null => null,
    };

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

String dedent(List<String> body) {
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

const _backslash = 0x5C;
const _openBrace = 0x7B;
const _closeBrace = 0x7D;
const _openBracket = 0x5B;
const _closeBracket = 0x5D;
const _lessThan = 0x3C;
const _greaterThan = 0x3E;
const _colon = 0x3A;
const _pipe = 0x7C;
const _freeFormKey = 0x10000;

final _styleCodes = {
  for (final MapEntry(:key, :value) in _styles.entries)
    key.codeUnitAt(0): value,
};
final _verbatimCodes = {
  for (final MapEntry(:key, :value) in _verbatims.entries)
    key.codeUnitAt(0): value,
};
final _nullCode = _nullModifier.codeUnitAt(0);

final _unicodeWhitespace = <int, bool>{};
final _unicodeWord = <int, bool>{};

final _inlineStarts = () {
  final table = Uint8List(0x80);
  for (final char in r'\{[<:*/_-!^,`$&%'.split('')) {
    table[char.codeUnitAt(0)] = 1;
  }
  return table;
}();

bool _isWhitespace(int code) => code < 0x80
    ? code == 0x20 || (code >= 0x09 && code <= 0x0D)
    : _unicodeWhitespace[code] ??= String.fromCharCode(code).trim().isEmpty;

bool _isWord(int code) => code < 0x80
    ? (code >= 0x30 && code <= 0x39) ||
          ((code | 0x20) >= 0x61 && (code | 0x20) <= 0x7A)
    : _unicodeWord[code] ??= _wordChar.hasMatch(String.fromCharCode(code));

List<Inline> parseInline(String text, [int base = 0]) =>
    _InlineParser(text, base).parse();

class _InlineParser {
  _InlineParser(this.text, this.base) : codes = text.codeUnits;

  final String text;
  final int base;
  final List<int> codes;
  final _failedFrom = <int, int>{};
  final _failedVisits = <int, Uint8List>{};

  int get length => codes.length;

  bool _isBoundary(int index) =>
      index < 0 || index >= length || !_isWord(codes[index]);

  int _indexOf(int code, int from) {
    if (from >= (_failedFrom[code] ?? length + 1)) return -1;
    final found = text.indexOf(String.fromCharCode(code), from);
    if (found < 0) _failedFrom[code] = from;
    return found;
  }

  List<Inline> parse() {
    final nodes = <Inline>[];
    final plain = StringBuffer();
    var textStart = base;
    void emitText(int end) {
      if (plain.isEmpty) return;
      nodes.add(TextInline(plain.toString(), start: textStart, end: end));
      plain.clear();
    }

    void emit(Inline node) {
      emitText(node.start);
      nodes.add(node);
      textStart = node.end;
    }

    var runStart = 0;
    var index = 0;
    void flushRun() {
      if (runStart < index) plain.write(text.substring(runStart, index));
    }

    while (index < length) {
      final code = codes[index];
      if (code >= 0x80 || _inlineStarts[code] == 0) {
        index++;
        continue;
      }
      if (code == _backslash && index + 1 < length) {
        flushRun();
        plain.writeCharCode(codes[index + 1]);
        index += 2;
        runStart = index;
        continue;
      }
      final parsed =
          _linkable(index) ?? _attached(index) ?? _linkModifier(index);
      if (parsed != null) {
        flushRun();
        final (node, next) = parsed;
        emit(node);
        index = next;
        runStart = index;
        continue;
      }
      index++;
    }
    flushRun();
    emitText(base + length);
    return nodes;
  }

  (Inline, int)? _linkable(int index) {
    final code = codes[index];
    if (code == _openBrace) {
      final close = _indexOf(_closeBrace, index + 1);
      if (close <= index + 1) return null;
      final target = text.substring(index + 1, close);
      final description = _bracketed(close + 1);
      if (description == null) {
        return (_link(target, const [], index, close + 1), close + 1);
      }
      final (label, next) = description;
      final children = parseInline(label, base + close + 2);
      return (_link(target, children, index, next), next);
    }
    if (code == _openBracket) {
      final description = _bracketed(index);
      if (description == null) return null;
      final (label, next) = description;
      if (next < length && codes[next] == _openBrace) {
        final close = _indexOf(_closeBrace, next + 1);
        if (close > next + 1) {
          final target = text.substring(next + 1, close);
          final children = parseInline(label, base + index + 1);
          return (_link(target, children, index, close + 1), close + 1);
        }
      }
      return (
        AnchorInline(
          parseInline(label, base + index + 1),
          start: base + index,
          end: base + next,
        ),
        next,
      );
    }
    if (code == _lessThan &&
        index + 1 < length &&
        !_isWhitespace(codes[index + 1])) {
      final close = _indexOf(_greaterThan, index + 1);
      if (close > index + 1 && !_isWhitespace(codes[close - 1])) {
        final node = TargetInline(
          text.substring(index + 1, close),
          start: base + index,
          end: base + close + 1,
        );
        return (node, close + 1);
      }
    }
    return null;
  }

  LinkInline _link(String target, List<Inline> children, int start, int end) =>
      LinkInline(target, children, start: base + start, end: base + end);

  (Inline, int)? _linkModifier(int index) {
    if (codes[index] != _colon ||
        index == 0 ||
        index + 1 >= length ||
        !_isWord(codes[index - 1])) {
      return null;
    }
    final attached = _attached(index + 1);
    if (attached == null) return null;
    final (node, end) = attached;
    final closes =
        end + 1 < length && codes[end] == _colon && _isWord(codes[end + 1]);
    return (node, closes ? end + 1 : end);
  }

  (String, int)? _bracketed(int index) {
    if (index >= length || codes[index] != _openBracket) return null;
    final close = _indexOf(_closeBracket, index + 1);
    if (close <= index + 1) return null;
    return (text.substring(index + 1, close), close + 1);
  }

  (Inline, int)? _attached(int index) {
    final code = codes[index];
    final isModifier =
        _styleCodes.containsKey(code) ||
        _verbatimCodes.containsKey(code) ||
        code == _nullCode;
    if (!isModifier || index + 1 >= length) return null;
    final next = codes[index + 1];
    if (_isWhitespace(next) || next == code || !_isBoundary(index - 1)) {
      return null;
    }

    final freeFormClose = next == _pipe
        ? _freeFormClose(index + 2, code)
        : null;
    final freeForm = freeFormClose != null;
    final contentStart = index + (freeForm ? 2 : 1);
    final close = freeFormClose ?? _standardClose(contentStart, code);
    if (close == null) return null;

    final content = text.substring(contentStart, freeForm ? close - 1 : close);
    final end = close + 1;
    final (start, stop) = (base + index, base + end);
    if (code == _nullCode) {
      return (
        VerbatimInline(VerbatimKind.comment, content, start: start, end: stop),
        end,
      );
    }
    if (_verbatimCodes[code] case final kind?) {
      return (VerbatimInline(kind, content, start: start, end: stop), end);
    }
    final children = parseInline(content, base + contentStart);
    return (
      StyledInline(_styleCodes[code]!, children, start: start, end: stop),
      end,
    );
  }

  int? _freeFormClose(int start, int code) {
    final key = code | _freeFormKey;
    if (start >= (_failedFrom[key] ?? length + 1)) return null;
    for (var index = start + 1; index < length; index++) {
      if (codes[index] == code &&
          codes[index - 1] == _pipe &&
          _isBoundary(index + 1)) {
        return index;
      }
    }
    _failedFrom[key] = start;
    return null;
  }

  int? _standardClose(int start, int code) {
    if (_verbatimCodes.containsKey(code)) return _verbatimClose(start, code);
    final failed = _failedVisits[code] ??= Uint8List(length);
    final visits = <int>[];
    for (var index = start + 1; index < length; index++) {
      if (failed[index] == 1) break;
      visits.add(index);
      final current = codes[index];
      if (current == _backslash) {
        index++;
        continue;
      }
      if (current == _openBrace) {
        final close = _indexOf(_closeBrace, index);
        if (close > index) index = close;
        continue;
      }
      if (_closes(index, code)) return index;
    }
    for (final index in visits) {
      failed[index] = 1;
    }
    return null;
  }

  int? _verbatimClose(int start, int code) {
    if (start >= (_failedFrom[code] ?? length + 1)) return null;
    for (var index = start + 1; index < length; index++) {
      if (_closes(index, code)) return index;
    }
    _failedFrom[code] = start;
    return null;
  }

  bool _closes(int index, int code) =>
      codes[index] == code &&
      !_isWhitespace(codes[index - 1]) &&
      _isBoundary(index + 1);
}

extension on String {
  String? get nullIfEmpty => isEmpty ? null : this;
}
