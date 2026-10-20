import 'dart:math';

import 'ast.dart';

final linkLocation = RegExp(r'^(\*+|#|\$|\^|\?|/|@|=)\s+(.+)$');
final _ignored = RegExp(r'[\s\\]');

String comparable(String title) => title.replaceAll(_ignored, '').toLowerCase();

String linkLabel(String target) =>
    linkLocation.firstMatch(target)?[2] ??
    target.replaceAll(RegExp(r'^:|:$'), '');

String plainText(List<Inline> nodes) => nodes
    .map(
      (node) => switch (node) {
        TextInline(:final text) ||
        VerbatimInline(:final text) ||
        TargetInline(:final text) => text,
        StyledInline(children: final nested) ||
        AnchorInline(description: final nested) => plainText(nested),
        LinkInline(:final target, :final description) =>
          description.isEmpty ? linkLabel(target) : plainText(description),
      },
    )
    .join();

class DocumentTargets {
  DocumentTargets(List<Block> blocks) {
    _blocks(blocks);
  }

  final _headings = <(int level, String title, int line)>[];
  final _definitions = <String, int>{};
  final _footnotes = <String, int>{};
  final _generic = <String, int>{};
  final _anchors = <String, String>{};

  int? lineOf(String location) {
    final match = linkLocation.firstMatch(location);
    if (match == null) return null;
    final marker = match[1]!;
    final title = comparable(match[2]!);
    return switch (marker[0]) {
      '*' =>
        _headings
            .where((heading) => heading.$1 == min(marker.length, 6))
            .where((heading) => heading.$2 == title)
            .firstOrNull
            ?.$3,
      r'$' => _definitions[title],
      '^' => _footnotes[title],
      _ => _generic[title],
    };
  }

  String? anchorTarget(List<Inline> description) =>
      _anchors[comparable(plainText(description))];

  void _remember(Map<String, int> index, String title, int line) =>
      index.putIfAbsent(comparable(title), () => line);

  void _blocks(List<Block> blocks) {
    for (final block in blocks) {
      final line = block.range.start;
      for (final tag in block.tags) {
        if (tag.name == 'name') _remember(_generic, tag.params, line);
      }
      switch (block) {
        case Heading(:final level, :final title, :final children):
          final text = plainText(title);
          _headings.add((level, comparable(text), block.line));
          _remember(_generic, text, block.line);
          _inlines(title, block.line);
          _blocks(children);
        case Definition(:final term, :final content):
          _remember(_definitions, plainText(term), line);
          _remember(_generic, plainText(term), line);
          _blocks(content);
        case Footnote(:final title, :final content):
          _remember(_footnotes, title, line);
          _remember(_generic, title, line);
          _blocks(content);
        case Paragraph(:final content):
          _inlines(content, line);
        case ListBlock(:final items):
          for (final item in items) {
            _inlines(item.content, item.line);
          }
        case QuoteBlock(lines: final quoteLines):
          for (final quote in quoteLines) {
            _inlines(quote.content, line);
          }
        case TableBlock(:final rows):
          for (final cell in rows.expand((row) => row)) {
            _inlines(cell, line);
          }
        case RangedBlock(:final children):
          _blocks(children);
        case DocumentMeta() ||
            CodeBlock() ||
            MathBlock() ||
            VerbatimTag() ||
            ImageBlock() ||
            InfirmTag() ||
            DelimiterLine():
      }
    }
  }

  void _inlines(List<Inline> nodes, int line) {
    for (final node in nodes) {
      switch (node) {
        case TargetInline(:final text):
          _remember(_generic, text, line);
        case LinkInline(:final target, :final description)
            when description.isNotEmpty:
          _anchors.putIfAbsent(
            comparable(plainText(description)),
            () => target,
          );
        case StyledInline(children: final nested):
          _inlines(nested, line);
        default:
      }
    }
  }
}
