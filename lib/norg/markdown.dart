import 'package:path/path.dart' as p;

import 'ast.dart';
import 'targets.dart';

final _special = RegExp(r'([\\`*_\[\]<])');
final _slugIgnored = RegExp(r'[^\p{L}\p{N}\s-]', unicode: true);

String _slug(String title) => title
    .toLowerCase()
    .replaceAll(_slugIgnored, '')
    .trim()
    .replaceAll(RegExp(r'\s+'), '-');

String toMarkdown(String source, List<Block> blocks) => _MarkdownWriter(
  source.split('\n'),
  DocumentTargets(blocks),
).document(blocks);

class _MarkdownWriter {
  _MarkdownWriter(this.lines, this.targets);

  final List<String> lines;
  final DocumentTargets targets;

  String document(List<Block> blocks) =>
      '${_blocks(blocks).where((chunk) => chunk.isNotEmpty).join('\n\n')}\n';

  List<String> _blocks(List<Block> blocks) => [
    for (final block in blocks)
      if (!block.tags.any((tag) => tag.name == 'comment')) ..._block(block),
  ];

  List<String> _block(Block block) => switch (block) {
    DocumentMeta(:final fields) => [
      [
        '---',
        for (final entry in fields.entries) '${entry.key}: ${entry.value}',
        '---',
      ].join('\n'),
    ],
    Heading(:final level, :final title, :final children) => [
      '${'#' * (level > 6 ? 6 : level)} ${_inlines(title)}',
      ..._blocks(children),
    ],
    Paragraph(:final content) => [_inlines(content)],
    ListBlock(:final items) => [
      [
        for (final item in items)
          '${'    ' * (item.level - 1)}'
              '${item.kind == NestableKind.ordered ? '1.' : '-'} '
              '${_checkbox(item.status)}${_inlines(item.content)}',
      ].join('\n'),
    ],
    QuoteBlock(lines: final quoteLines) => [
      [
        for (final line in quoteLines)
          '${'>' * line.level} ${_inlines(line.content)}',
      ].join('\n'),
    ],
    CodeBlock(:final language, :final code) => [
      '```${language ?? ''}\n$code\n```',
    ],
    MathBlock(:final tex) => ['\$\$\n$tex\n\$\$'],
    TableBlock(:final rows) when rows.isNotEmpty => [
      [
        _row(rows.first),
        '|${' --- |' * rows.first.length}',
        for (final row in rows.skip(1)) _row(row),
      ].join('\n'),
    ],
    Definition(:final term, :final content) => [
      '**${_inlines(term)}**',
      ..._blocks(content),
    ],
    Footnote(:final title, :final content) => [
      '[^${_slug(title)}]: ${_blocks(content).join(' ')}',
    ],
    RangedBlock(name: 'comment') => const [],
    RangedBlock(:final children) => _blocks(children),
    InfirmTag(name: 'image', :final params) => ['![]($params)'],
    ImageBlock(:final format, :final data) => [
      '![](data:image/$format;base64,$data)',
    ],
    VerbatimTag(:final range) => [
      '```\n${lines.sublist(range.start, range.end).join('\n')}\n```',
    ],
    DelimiterLine(kind: DelimiterKind.horizontal) => ['***'],
    TableBlock() || InfirmTag() || DelimiterLine() => const [],
  };

  String _checkbox(TodoStatus? status) => switch (status) {
    null => '',
    TodoStatus.done => '[x] ',
    _ => '[ ] ',
  };

  String _row(List<List<Inline>> cells) =>
      '| ${cells.map(_inlines).join(' | ')} |';

  String _inlines(List<Inline> nodes) => nodes.map(_inline).join();

  String _inline(Inline node) => switch (node) {
    TextInline(:final text) => text.replaceAllMapped(
      _special,
      (match) => '\\${match[1]}',
    ),
    TargetInline(:final text) => text,
    StyledInline(:final style, :final children) => switch (style) {
      InlineStyle.bold => '**${_inlines(children).trim()}**',
      InlineStyle.italic => '*${_inlines(children).trim()}*',
      InlineStyle.underline => '<u>${_inlines(children)}</u>',
      InlineStyle.strikethrough => '~~${_inlines(children).trim()}~~',
      InlineStyle.superscript => '<sup>${_inlines(children)}</sup>',
      InlineStyle.subscript => '<sub>${_inlines(children)}</sub>',
      InlineStyle.spoiler => _inlines(children),
    },
    VerbatimInline(:final kind, :final text) => switch (kind) {
      VerbatimKind.code => text.contains('`') ? '`` $text ``' : '`$text`',
      VerbatimKind.math => '\$$text\$',
      VerbatimKind.variable => text,
      VerbatimKind.comment => '',
    },
    AnchorInline(:final description) => switch (targets.anchorTarget(
      description,
    )) {
      final target? => _link(target, description),
      null => _inlines(description),
    },
    LinkInline(:final target, :final description) => _link(target, description),
  };

  String _link(String target, List<Inline> description) {
    final label = description.isEmpty
        ? linkLabel(target)
        : _inlines(description);
    if (target.startsWith('@ ')) return label;
    if (linkLocation.firstMatch(target) case final match?
        when match[1] == '^') {
      return '[^${_slug(match[2]!)}]';
    }
    return '[$label](${_destination(target)})';
  }

  String _destination(String target) {
    if (Uri.tryParse(target) case final uri? when uri.hasScheme) return target;
    if (target.startsWith('/ ')) return target.substring(2).trim();
    if (target.startsWith(':')) {
      final close = target.indexOf(':', 1);
      if (close > 0) {
        final file = target
            .substring(1, close)
            .replaceFirst(RegExp(r'^\$[^/]*/'), '');
        final location = target.substring(close + 1).trim();
        final anchor = linkLocation.firstMatch(location)?[2];
        return '${p.posix.withoutExtension(file)}.md'
            '${anchor == null ? '' : '#${_slug(anchor)}'}';
      }
    }
    return switch (linkLocation.firstMatch(target)?[2]) {
      final title? => '#${_slug(title)}',
      null => target,
    };
  }
}
