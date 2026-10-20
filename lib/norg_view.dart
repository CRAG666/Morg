import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:re_highlight/languages/all.dart';
import 'package:re_highlight/re_highlight.dart';
import 'package:url_launcher/url_launcher.dart';

import 'config/concealer_config.dart';
import 'highlight/bibtex.dart';
import 'norg/ast.dart';
import 'settings.dart';
import 'theme/norg_theme.dart';

final _highlighter = Highlight()
  ..registerLanguages(builtinAllLanguages)
  ..registerLanguage('bibtex', langBibtex);
final _linkLocation = RegExp(r'^(\*{1,6}|#|\$|\^|\?|/|@|=)\s+(.+)$');

const _todoGroups = {
  TodoStatus.undone: 'undone',
  TodoStatus.done: 'done',
  TodoStatus.pending: 'pending',
  TodoStatus.needsInput: 'uncertain',
  TodoStatus.onHold: 'on_hold',
  TodoStatus.cancelled: 'cancelled',
  TodoStatus.recurring: 'recurring',
  TodoStatus.urgent: 'urgent',
};

String plainText(List<Inline> nodes) => nodes
    .map(
      (node) => switch (node) {
        TextInline(:final text) || VerbatimInline(:final text) => text,
        StyledInline(children: final nested) ||
        AnchorInline(description: final nested) => plainText(nested),
        LinkInline(:final target, :final description) =>
          description.isEmpty ? _linkLabel(target) : plainText(description),
      },
    )
    .join();

String _linkLabel(String target) =>
    _linkLocation.firstMatch(target)?[2] ??
    target.replaceAll(RegExp(r'^:|:$'), '');

String _linkGroup(String target) {
  if (Uri.tryParse(target) case final uri? when uri.hasScheme) {
    return '@neorg.links.location.url';
  }
  if (target.startsWith(':')) return '@neorg.links.file';
  final marker = _linkLocation.firstMatch(target)?[1];
  return switch (marker) {
    null => '@neorg.links.location.url',
    '#' || '?' || '=' || '@' => '@neorg.links.location.generic',
    r'$' => '@neorg.links.location.definition',
    '^' => '@neorg.links.location.footnote',
    '/' => '@neorg.links.location.external_file',
    _ => '@neorg.links.location.heading.${marker.length}',
  };
}

Iterable<Heading> _headings(List<Block> blocks) sync* {
  for (final block in blocks) {
    switch (block) {
      case Heading(:final children):
        yield block;
        yield* _headings(children);
      case RangedBlock(children: final nested) ||
          Definition(content: final nested) ||
          Footnote(content: final nested):
        yield* _headings(nested);
      default:
    }
  }
}

class NorgDocumentView extends StatefulWidget {
  const NorgDocumentView({
    super.key,
    required this.blocks,
    this.onLink,
    this.onTodoTap,
    this.resolveImage,
    this.initialLocation,
  });

  final List<Block> blocks;
  final ValueChanged<String>? onLink;
  final ValueChanged<int>? onTodoTap;
  final ImageProvider? Function(String path)? resolveImage;
  final String? initialLocation;

  @override
  State<NorgDocumentView> createState() => _NorgDocumentViewState();
}

class _NorgDocumentViewState extends State<NorgDocumentView> {
  final _collapsed = <int>{};
  final _headingKeys = <int, GlobalKey>{};
  final _recognizers = <TapGestureRecognizer>[];

  late ConcealerConfig _icons;
  late NorgTheme _theme;
  late TextStyle _base;
  late double _charWidth;

  @override
  void initState() {
    super.initState();
    if (widget.initialLocation case final location?) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _jumpTo(location));
    }
  }

  @override
  void dispose() {
    _disposeRecognizers();
    super.dispose();
  }

  void _disposeRecognizers() {
    for (final recognizer in _recognizers) {
      recognizer.dispose();
    }
    _recognizers.clear();
  }

  TextStyle _hl(String group, [TextStyle? base]) =>
      _theme[group].apply(base ?? _base);

  @override
  Widget build(BuildContext context) {
    _disposeRecognizers();
    final settings = MorgSettingsScope.of(context);
    _icons = settings.concealer;
    _theme = settings.theme.of(Theme.of(context).brightness);
    _base = Theme.of(context).textTheme.bodyMedium!
        .copyWith(color: _theme.foreground, height: 1.4);
    final painter = TextPainter(
      text: TextSpan(text: 'M', style: _base),
      textDirection: TextDirection.ltr,
    )..layout();
    _charWidth = painter.width;
    painter.dispose();

    return SelectionArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 48),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: _blocks(widget.blocks),
        ),
      ),
    );
  }

  List<Widget> _blocks(List<Block> blocks, [TextStyle? paragraphStyle]) => [
    for (final block in blocks)
      Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: _block(block, paragraphStyle ?? _base),
      ),
  ];

  Widget _column(List<Widget> children) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: children,
  );

  Widget _indented(double columns, Widget child) => Padding(
    padding: EdgeInsets.only(left: columns * _charWidth),
    child: child,
  );

  Widget _block(Block block, TextStyle paragraphStyle) => switch (block) {
    DocumentMeta() => _meta(block),
    Heading() => _heading(block),
    Paragraph(:final content) => Text.rich(_spans(content, paragraphStyle)),
    ListBlock() => _list(block),
    QuoteBlock() => _quote(block),
    CodeBlock() => _code(block),
    TableBlock() => _table(block),
    Definition() => _rangeable(
      prefix: block.ranged
          ? _icons.definitionMultiPrefix
          : _icons.definitionSingle,
      suffix: block.ranged ? _icons.definitionMultiSuffix : null,
      group: '@neorg.definitions',
      title: block.term,
      content: block.content,
    ),
    Footnote() => _rangeable(
      prefix: block.ranged ? _icons.footnoteMultiPrefix : _icons.footnoteSingle,
      suffix: block.ranged ? _icons.footnoteMultiSuffix : null,
      group: '@neorg.footnotes',
      title: [TextInline(block.title)],
      content: block.content,
    ),
    RangedBlock() => _ranged(block),
    InfirmTag(name: 'toc') => _tableOfContents(),
    InfirmTag(name: 'image', :final params)
        when widget.resolveImage?.call(params) != null =>
      Image(
        image: widget.resolveImage!(params)!,
        alignment: Alignment.centerLeft,
        errorBuilder: (context, error, _) =>
            Text('.image $params — $error', style: _hl('@neorg.error')),
      ),
    InfirmTag(:final name, :final params) => Text.rich(
      TextSpan(
        children: [
          TextSpan(text: '.$name', style: _hl('@neorg.tags.carryover.begin')),
          TextSpan(
            text: ' $params',
            style: _hl('@neorg.tags.carryover.parameters'),
          ),
        ],
      ),
    ),
    DelimiterLine() => _delimiter(block),
  };

  Widget _meta(DocumentMeta meta) {
    const prefix = '@neorg.tags.ranged_verbatim.document_meta';
    return _column([
      for (final MapEntry(:key, :value) in meta.fields.entries)
        Text.rich(
          TextSpan(
            children: [
              TextSpan(text: key, style: _hl('$prefix.key')),
              const TextSpan(text: ': '),
              TextSpan(
                text: value,
                style: _hl(
                  _theme.defines('$prefix.$key')
                      ? '$prefix.$key'
                      : '$prefix.value',
                ),
              ),
            ],
          ),
        ),
    ]);
  }

  Widget _heading(Heading heading) {
    final level = heading.level;
    final titleStyle = _hl('@neorg.headings.$level.title');
    final collapsed = _collapsed.contains(heading.line);
    final hasChildren = heading.children.isNotEmpty;
    return Column(
      key: _headingKeys.putIfAbsent(heading.line, GlobalKey.new),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        GestureDetector(
          onTap: hasChildren
              ? () => setState(
                  () => collapsed
                      ? _collapsed.remove(heading.line)
                      : _collapsed.add(heading.line),
                )
              : null,
          child: Text.rich(
            TextSpan(
              children: [
                TextSpan(
                  text: '${iconForLevel(_icons.headingIcons, level)} ',
                  style: _hl('@neorg.headings.$level.prefix'),
                ),
                if (heading.status case final status?)
                  ..._todoSpans(status, heading.line),
                _spans(heading.title, titleStyle),
                if (collapsed) TextSpan(text: ' …', style: titleStyle),
              ],
            ),
          ),
        ),
        if (!collapsed && hasChildren)
          _indented(
            2,
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: _column(_blocks(heading.children)),
            ),
          ),
      ],
    );
  }

  List<InlineSpan> _todoSpans(TodoStatus status, int line) => [
    TextSpan(
      text: '(${_icons.todoIcons[status]})',
      style: _hl('@neorg.todo_items.${_todoGroups[status]}'),
      recognizer: _recognizer(
        widget.onTodoTap == null ? null : () => widget.onTodoTap!(line),
      ),
    ),
    const TextSpan(text: ' '),
  ];

  TapGestureRecognizer? _recognizer(VoidCallback? onTap) {
    if (onTap == null) return null;
    final recognizer = TapGestureRecognizer()..onTap = onTap;
    _recognizers.add(recognizer);
    return recognizer;
  }

  Widget _list(ListBlock list) {
    final counters = <int, int>{};
    return _column([
      for (final item in list.items)
        _indented(
          item.level - 1.0,
          Padding(
            padding: const EdgeInsets.only(bottom: 2),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${_listIcon(item, counters)} ',
                  style: _hl(
                    item.kind == NestableKind.ordered
                        ? '@neorg.lists.ordered.prefix'
                        : '@neorg.lists.unordered.prefix',
                  ),
                ),
                Expanded(
                  child: Text.rich(
                    TextSpan(
                      children: [
                        if (item.status case final status?)
                          ..._todoSpans(status, item.line),
                        _spans(item.content, _base),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
    ]);
  }

  String _listIcon(ListItem item, Map<int, int> counters) {
    counters.removeWhere((level, _) => level > item.level);
    if (item.kind == NestableKind.unordered) {
      counters.remove(item.level);
      return iconForLevel(_icons.listIcons, item.level);
    }
    final index = counters.update(
      item.level,
      (count) => count + 1,
      ifAbsent: () => 1,
    );
    return formatOrderedIcon(
      iconForLevel(_icons.orderedIcons, item.level),
      index,
    );
  }

  Widget _quote(QuoteBlock quote) => _column([
    for (final line in quote.lines)
      Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${[for (var level = 1; level <= line.level; level++) iconForLevel(_icons.quoteIcons, level)].join()} ',
            style: _hl('@neorg.quotes.${line.level}.prefix'),
          ),
          Expanded(
            child: Text.rich(
              _spans(line.content, _hl('@neorg.quotes.${line.level}.content')),
            ),
          ),
        ],
      ),
  ]);

  Widget _code(CodeBlock code) {
    final language = code.language;
    TextSpan? highlighted;
    if (language != null && _highlighter.getLanguage(language) != null) {
      final renderer = TextSpanRenderer(_base, _theme.codeTheme(_base));
      _highlighter
          .highlight(code: code.code, language: language)
          .render(renderer);
      highlighted = renderer.span;
    }
    const tag = '@neorg.tags.ranged_verbatim';
    return Container(
      color: _theme['$tag.code_block'].background,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: _column([
        if (!_icons.codeBlockConceal)
          Text.rich(
            TextSpan(
              children: [
                TextSpan(text: '@code', style: _hl('$tag.name.word')),
                if (language != null)
                  TextSpan(text: ' $language', style: _hl('$tag.parameters')),
              ],
            ),
          ),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Text.rich(
            highlighted ?? TextSpan(text: code.code, style: _base),
            softWrap: false,
          ),
        ),
        if (!_icons.codeBlockConceal) Text('@end', style: _hl('$tag.end')),
      ]),
    );
  }

  Widget _table(TableBlock table) {
    final columns = table.rows.fold(
      0,
      (widest, row) => row.length > widest ? row.length : widest,
    );
    final borderColor =
        _theme['@neorg.delimiters.horizontal_line'].foreground ??
        _theme.foreground;
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Table(
        defaultColumnWidth: const IntrinsicColumnWidth(),
        border: TableBorder.all(color: borderColor),
        children: [
          for (final (index, row) in table.rows.indexed)
            TableRow(
              children: [
                for (var column = 0; column < columns; column++)
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 2,
                    ),
                    child: Text.rich(
                      _spans(
                        column < row.length ? row[column] : const [],
                        index == 0 ? _hl('@neorg.markup.bold') : _base,
                      ),
                    ),
                  ),
              ],
            ),
        ],
      ),
    );
  }

  Widget _rangeable({
    required String prefix,
    required String? suffix,
    required String group,
    required List<Inline> title,
    required List<Block> content,
  }) => _column([
    Text.rich(
      TextSpan(
        children: [
          TextSpan(text: '$prefix ', style: _hl('$group.prefix')),
          _spans(title, _hl('$group.title')),
        ],
      ),
    ),
    _indented(2, _column(_blocks(content, _hl('$group.content')))),
    if (suffix != null) Text(suffix, style: _hl('$group.suffix')),
  ]);

  Widget _ranged(RangedBlock block) {
    final children = _blocks(block.children);
    if (block.name != 'details') return _column(children);
    return ExpansionTile(
      title: Text(block.params.isEmpty ? 'details' : block.params),
      textColor: _theme.foreground,
      collapsedTextColor: _theme.foreground,
      iconColor: _theme.foreground,
      collapsedIconColor: _theme.foreground,
      shape: const Border(),
      collapsedShape: const Border(),
      tilePadding: EdgeInsets.zero,
      childrenPadding: EdgeInsets.only(left: 2 * _charWidth),
      expandedCrossAxisAlignment: CrossAxisAlignment.stretch,
      children: children,
    );
  }

  Widget _tableOfContents() => _column([
    for (final heading in _headings(widget.blocks))
      _indented(
        heading.level - 1.0,
        Text.rich(
          TextSpan(
            children: [
              TextSpan(
                text: '${iconForLevel(_icons.headingIcons, heading.level)} ',
                style: _hl('@neorg.headings.${heading.level}.prefix'),
              ),
              _link(
                '${'*' * heading.level} ${plainText(heading.title)}',
                heading.title,
                _hl('@neorg.links.location.heading.${heading.level}'),
              ),
            ],
          ),
        ),
      ),
  ]);

  Widget _delimiter(DelimiterLine line) {
    final (icon, group) = switch (line.kind) {
      DelimiterKind.weak => (_icons.weakDelimiter, '@neorg.delimiters.weak'),
      DelimiterKind.strong => (
        _icons.strongDelimiter,
        '@neorg.delimiters.strong',
      ),
      DelimiterKind.horizontal => (
        _icons.horizontalLine,
        '@neorg.delimiters.horizontal_line',
      ),
    };
    if (line.kind != DelimiterKind.horizontal) {
      return Text(icon * line.length, style: _hl(group));
    }
    return LayoutBuilder(
      builder: (context, constraints) => Text(
        icon * (constraints.maxWidth / _charWidth).floor(),
        style: _hl(group),
        maxLines: 1,
        softWrap: false,
        overflow: TextOverflow.clip,
      ),
    );
  }

  TextSpan _spans(List<Inline> nodes, TextStyle style) => TextSpan(
    style: style,
    children: [for (final node in nodes) _inline(node, style)],
  );

  InlineSpan _inline(Inline node, TextStyle style) => switch (node) {
    TextInline(:final text) => TextSpan(text: text),
    StyledInline(style: InlineStyle.spoiler, :final children) => TextSpan(
      text: _icons.spoiler * plainText(children).length,
      style: _hl('@neorg.markup.spoiler', style),
    ),
    StyledInline(
      style: InlineStyle.superscript || InlineStyle.subscript,
      :final children,
    ) =>
      _shifted(node.style == InlineStyle.superscript, children, style),
    StyledInline(style: final kind, :final children) => _spans(
      children,
      _hl('@neorg.markup.${kind.name}', style),
    ),
    VerbatimInline(:final kind, :final text) => TextSpan(
      text: text,
      style: _hl(switch (kind) {
        VerbatimKind.code => '@neorg.markup.verbatim',
        VerbatimKind.math => '@neorg.markup.inline_math',
        VerbatimKind.variable => '@neorg.markup.variable',
        VerbatimKind.comment => '@neorg.markup.inline_comment',
      }, style),
    ),
    AnchorInline(:final description) => _spans(
      description,
      _hl('@neorg.anchors.declaration', style),
    ),
    LinkInline(:final target, :final description) => _link(
      target,
      description,
      style,
    ),
  };

  InlineSpan _shifted(bool up, List<Inline> children, TextStyle style) {
    final size = style.fontSize ?? 14;
    final group = up ? '@neorg.markup.superscript' : '@neorg.markup.subscript';
    return WidgetSpan(
      alignment: PlaceholderAlignment.middle,
      child: Transform.translate(
        offset: Offset(0, up ? -size * 0.35 : size * 0.3),
        child: Text.rich(
          _spans(children, _hl(group, style.copyWith(fontSize: size * 0.7))),
        ),
      ),
    );
  }

  InlineSpan _link(String target, List<Inline> description, TextStyle style) {
    final recognizer = _recognizer(() => _followLink(target));
    final linkStyle = description.isEmpty
        ? _hl(_linkGroup(target), style)
        : _hl('@neorg.links.description', style);
    return _withRecognizer(
      TextSpan(
        style: linkStyle,
        children: description.isEmpty
            ? [TextSpan(text: _linkLabel(target))]
            : [for (final node in description) _inline(node, linkStyle)],
      ),
      recognizer!,
    );
  }

  InlineSpan _withRecognizer(InlineSpan span, GestureRecognizer recognizer) =>
      switch (span) {
        TextSpan() => TextSpan(
          text: span.text,
          style: span.style,
          recognizer: recognizer,
          mouseCursor: SystemMouseCursors.click,
          children: [
            for (final child in span.children ?? const <InlineSpan>[])
              _withRecognizer(child, recognizer),
          ],
        ),
        _ => span,
      };

  Future<void> _followLink(String target) async {
    if (_headingKey(target) != null) return _jumpTo(target);
    if (widget.onLink case final onLink?) return onLink(target);
    if (Uri.tryParse(target) case final uri? when uri.hasScheme) {
      if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
        _notify('No se pudo abrir $target');
      }
      return;
    }
    _notify('Destino no soportado: $target');
  }

  void _jumpTo(String location) {
    final key = _headingKey(location);
    if (key == null) {
      _notify('No se encontró «$location»');
      return;
    }
    setState(_collapsed.clear);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (key.currentContext case final targetContext?) {
        Scrollable.ensureVisible(
          targetContext,
          duration: const Duration(milliseconds: 300),
        );
      }
    });
  }

  GlobalKey? _headingKey(String target) {
    final match = _linkLocation.firstMatch(target);
    if (match == null) return null;
    final marker = match[1]!;
    final title = _comparable(match[2]!);
    for (final heading in _headings(widget.blocks)) {
      final levelMatches = marker.startsWith('*')
          ? marker.length == heading.level
          : marker == '#';
      if (levelMatches && _comparable(plainText(heading.title)) == title) {
        return _headingKeys.putIfAbsent(heading.line, GlobalKey.new);
      }
    }
    return null;
  }

  String _comparable(String title) =>
      title.replaceAll(RegExp(r'[\s\\]'), '').toLowerCase();

  void _notify(String message) =>
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(message)));
}
