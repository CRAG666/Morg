import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_math_fork/flutter_math.dart';
import 'package:re_highlight/re_highlight.dart';
import 'package:super_sliver_list/super_sliver_list.dart';
import 'package:url_launcher/url_launcher.dart';

import 'config/concealer_config.dart';
import 'document_style.dart';
import 'element_menu.dart';
import 'heading_outline.dart';
import 'inline_renderer.dart';
import 'selection_group.dart';
import 'svg_image.dart';
import 'highlight/languages.dart';
import 'norg/ast.dart';
import 'norg/edits.dart';
import 'norg/parser.dart';
import 'norg/structure.dart';
import 'norg/targets.dart';
import 'raw_highlight.dart';
import 'source_editor.dart';
import 'todo_menu.dart';
import 'dialogs.dart';
import 'l10n/l10n.dart';

export 'todo_menu.dart' show SourceEdit;

typedef SourceTransform = void Function(SourceEdit edit, {String? notice});

sealed class _Row {
  const _Row(this.depth);
  final int depth;
  SourceRange get range;
}

class _HeadingRow extends _Row {
  const _HeadingRow(this.heading, super.depth);
  final Heading heading;

  @override
  SourceRange get range => heading.range;
}

class _ItemRow extends _Row {
  const _ItemRow(
    this.item,
    this.ordinal,
    super.depth, {
    required this.last,
    required this.progress,
  });
  final ListItem item;
  final int ordinal;
  final bool last;
  final (int, int)? progress;

  @override
  SourceRange get range => item.range;
}

class _BlockRow extends _Row {
  const _BlockRow(this.block, super.depth);
  final Block block;

  @override
  SourceRange get range => block.range;
}

List<int> _ordinals(List<ListItem> items) {
  final counters = <int, int>{};
  int ordinal(ListItem item) {
    counters.removeWhere((level, _) => level > item.level);
    if (item.kind == NestableKind.unordered) {
      counters.remove(item.level);
      return 0;
    }
    return counters.update(item.level, (count) => count + 1, ifAbsent: () => 1);
  }

  return [for (final item in items) ordinal(item)];
}

class NorgDocumentView extends StatefulWidget {
  const NorgDocumentView({
    super.key,
    required this.blocks,
    required this.source,
    this.onEdit,
    this.onLink,
    this.onTransform,
    this.completions,
    this.buildImage,
    this.initialLocation,
    this.initialLine,
  });

  final List<Block> blocks;
  final String source;
  final Future<void> Function(SourceRange range, String text)? onEdit;
  final ValueChanged<String>? onLink;
  final SourceTransform? onTransform;
  final LinkCompletions? completions;
  final Widget? Function(String path)? buildImage;
  final String? initialLocation;
  final int? initialLine;

  @override
  State<NorgDocumentView> createState() => NorgDocumentViewState();
}

class NorgDocumentViewState extends State<NorgDocumentView> {
  final _collapsed = <int>{};
  int? _narrowed;
  final _recognizers = <Object, TapGestureRecognizer>{};
  late List<String> _lines = widget.source.split('\n');
  late DocumentTargets _targets = DocumentTargets(widget.blocks);
  int? _revealed;
  var _reveals = 0;
  final _highlighted = <(CodeBlock, Brightness), TextSpan?>{};
  final _scrollController = ScrollController();
  final _listController = ListController();
  final _selectionFocus = FocusNode(debugLabel: 'document selection');
  List<_Row>? _rows;

  late DocumentStyle _style;
  late InlineRenderer _inlines;

  @override
  void initState() {
    super.initState();
    if (widget.initialLocation case final location?) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _jumpTo(location));
    }
    if (widget.initialLine case final line?) {
      WidgetsBinding.instance.addPostFrameCallback((_) => jumpToLine(line));
    }
  }

  @override
  void didUpdateWidget(NorgDocumentView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.blocks != widget.blocks) {
      _rows = null;
      final lines = widget.source.split('\n');
      _revealed = switch (_revealed) {
        final line? => _movedLine(_lines, lines, line),
        null => null,
      };
      _lines = lines;
      _targets = DocumentTargets(widget.blocks);
      _highlighted.clear();
    }
  }

  @override
  void dispose() {
    for (final recognizer in _recognizers.values) {
      recognizer.dispose();
    }
    _scrollController.dispose();
    _listController.dispose();
    _selectionFocus.dispose();
    super.dispose();
  }

  Heading? get _narrowedHeading => switch (_narrowed) {
    final line? => headingAt(widget.blocks, line),
    null => null,
  };

  List<_Row> get _visibleRows => _rows ??= switch (_narrowedHeading) {
    final heading? => _flatten(heading.children, 1, [_HeadingRow(heading, 0)]),
    null => _flatten(widget.blocks, 0, []),
  };

  void _narrow(int? line) => setState(() {
    _narrowed = line;
    _rows = null;
  });

  List<_Row> _flatten(List<Block> blocks, int depth, List<_Row> rows) {
    for (final block in blocks) {
      switch (block) {
        case Heading(:final children, :final line):
          rows.add(_HeadingRow(block, depth));
          if (!_collapsed.contains(line)) _flatten(children, depth + 1, rows);
        case ListBlock(:final items):
          final progress = progressOfItems(items);
          for (final (index, ordinal) in _ordinals(items).indexed) {
            rows.add(
              _ItemRow(
                items[index],
                ordinal,
                depth,
                last: index == items.length - 1,
                progress: progress[index],
              ),
            );
          }
        default:
          rows.add(_BlockRow(block, depth));
      }
    }
    return rows;
  }

  void _toggle(int line) => setState(() {
    if (!_collapsed.remove(line)) _collapsed.add(line);
    _rows = null;
  });

  TapGestureRecognizer _recognizer(Object key, VoidCallback onTap) =>
      _recognizers.putIfAbsent(
        key,
        () => TapGestureRecognizer()..onTap = onTap,
      );

  String _sourceOf(SourceRange range) =>
      _lines.sublist(range.start, range.end).join('\n');

  Future<void> _commit(SourceRange range, String original, String text) async {
    await Future<void>.microtask(() {});
    if (mounted && _revealed == range.start) setState(() => _revealed = null);
    if (text == original) return;
    if (range.end > _lines.length || _sourceOf(range) != original) {
      if (mounted) context.notify((l10n) => l10n.editNotApplied);
      return;
    }
    await widget.onEdit?.call(range, text);
  }

  TextSpan _rawSpans(String text) =>
      RawHighlighter(_style.theme, _style.base).highlight(text);

  @override
  Widget build(BuildContext context) {
    final style = _style = DocumentStyle.of(context);
    _inlines = InlineRenderer(
      style: style,
      targets: _targets,
      linkRecognizer: (target) =>
          _recognizer(('link', target), () => _followLink(target)),
    );

    final rows = _visibleRows;
    _selectionFocus.canRequestFocus = _revealed == null;
    final list = SuperListView.builder(
      controller: _scrollController,
      listController: _listController,
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 48),
      itemCount: rows.length,
      itemBuilder: (context, index) => SelectionGroup(
        enabled: _revealed == null,
        copied: _copiedLine(rows[index]),
        child: _row(rows[index]),
      ),
    );
    final narrowed = _narrowedHeading;
    if (narrowed == null) _narrowed = null;
    return PopScope(
      canPop: narrowed == null,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _narrow(null);
      },
      child: Column(
        children: [
          if (narrowed != null)
            Material(
              color: _style
                  .theme['@neorg.tags.ranged_verbatim.code_block']
                  .background,
              child: ListTile(
                dense: true,
                leading: const Icon(Icons.center_focus_strong),
                title: Text(
                  context.l10n.focusedOn(plainText(narrowed.title)),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                trailing: IconButton(
                  tooltip: context.l10n.unfocus,
                  icon: const Icon(Icons.close),
                  onPressed: () => _narrow(null),
                ),
              ),
            ),
          Expanded(
            child: SelectionArea(focusNode: _selectionFocus, child: list),
          ),
        ],
      ),
    );
  }

  String Function(String text) _copiedLine(_Row row) {
    final icon = row is _HeadingRow
        ? iconForLevel(_style.icons.headingIcons, row.heading.level)
        : null;
    return (text) => icon != null && text.startsWith(icon)
        ? '${text.substring(icon.length).trimLeft()}\n'
        : '$text\n';
  }

  Widget _row(_Row row) {
    final range = row.range;
    final revealed = _revealed == range.start && range.end > range.start;
    final indent = row.depth * 2.0 + (row is _ItemRow ? row.item.level - 1 : 0);
    final content = _rowContent(row, revealed: revealed, indent: indent);
    final (prefix, onLongPress) = switch (row) {
      _HeadingRow(:final heading) when !revealed => (
        iconForLevel(_style.icons.headingIcons, heading.level),
        () => _elementMenu(heading.line),
      ),
      _ItemRow(:final item, :final ordinal) when !revealed => (
        _itemIcon(item, ordinal),
        () => _elementMenu(item.line),
      ),
      _ => (null, null),
    };
    if (_revealed != null || prefix == null || onLongPress == null) {
      return content;
    }
    final zoneEnd = (indent + prefix.length + 1) * _style.charWidth;
    return RawGestureDetector(
      behavior: HitTestBehavior.translucent,
      gestures: {
        _PrefixLongPress:
            GestureRecognizerFactoryWithHandlers<_PrefixLongPress>(
              () => _PrefixLongPress(zoneEnd),
              (recognizer) => recognizer
                ..zoneEnd = zoneEnd
                ..onLongPressStart = (_) => onLongPress(),
            ),
      },
      child: content,
    );
  }

  Widget _rowContent(
    _Row row, {
    required bool revealed,
    required double indent,
  }) {
    final range = row.range;
    final tags = row is _BlockRow ? row.block.tags : const <CarryoverTag>[];
    return _indented(
      revealed ? 0 : indent,
      Padding(
        padding: EdgeInsets.only(bottom: row is _ItemRow && !row.last ? 2 : 8),
        child: _withTagLines(
          tags,
          revealed
              ? SourceEditor(
                  key: ValueKey(_reveals),
                  source: _sourceOf(range),
                  style: _style.base,
                  highlight: (text) => _rawSpans(text),
                  readOnly: widget.onEdit == null,
                  completions: widget.completions,
                  onDone: (text) => _commit(range, _sourceOf(range), text),
                )
              : _swipeable(
                  row,
                  GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () => setState(() {
                      _revealed = range.start;
                      _reveals++;
                    }),
                    child: switch (row) {
                      _HeadingRow(:final heading) => _headingTitle(heading),
                      _ItemRow(:final item, :final ordinal, :final progress) =>
                        _listItem(item, ordinal, progress),
                      _BlockRow(:final block) => _taggedBlock(block),
                    },
                  ),
                ),
        ),
      ),
    );
  }

  Widget _swipeable(_Row row, Widget child) {
    final (line, status) = switch (row) {
      _HeadingRow(:final heading) => (heading.line, heading.status),
      _ItemRow(:final item) => (item.line, item.status),
      _BlockRow() => (0, null),
    };
    final onTransform = widget.onTransform;
    if (status == null || onTransform == null || _revealed != null) {
      return child;
    }
    Widget background(Color color, IconData icon, Alignment alignment) =>
        Container(
          color: color,
          alignment: alignment,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Icon(icon, color: Colors.white),
        );
    return Dismissible(
      key: ValueKey(('swipe', line)),
      dismissThresholds: const {
        DismissDirection.startToEnd: 0.3,
        DismissDirection.endToStart: 0.3,
      },
      background: background(
        Colors.green.shade700,
        Icons.check,
        Alignment.centerLeft,
      ),
      secondaryBackground: background(
        Colors.red.shade700,
        Icons.delete,
        Alignment.centerRight,
      ),
      confirmDismiss: (direction) async {
        if (direction == DismissDirection.startToEnd) {
          onTransform((source) => cycleTodo(source, widget.blocks, line));
        } else {
          onTransform(
            (source) => deleteElement(source, widget.blocks, line) ?? source,
            notice: context.l10n.deleted,
          );
        }
        return false;
      },
      child: child,
    );
  }

  Widget _withTagLines(List<CarryoverTag> tags, Widget child) => tags.isEmpty
      ? child
      : _column([
          for (final CarryoverTag(:marker, :name, :params) in tags)
            Text.rich(_rawSpans('$marker$name $params'.trimRight())),
          child,
        ]);

  Widget _taggedBlock(Block block) {
    if (!block.tags.any((tag) => tag.name == 'comment')) {
      return _block(block, _style.base);
    }
    final comment = _style.group('@neorg.tags.comment.content');
    return block is Paragraph
        ? _block(block, comment)
        : Opacity(opacity: 0.6, child: _block(block, comment));
  }

  List<Widget> _blocks(List<Block> blocks, [TextStyle? paragraphStyle]) => [
    for (final block in blocks)
      Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: _block(block, paragraphStyle ?? _style.base),
      ),
  ];

  Widget _column(List<Widget> children) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: children,
  );

  Widget _indented(double columns, Widget child) => Padding(
    padding: EdgeInsets.only(left: columns * _style.charWidth),
    child: child,
  );

  Widget _block(Block block, TextStyle paragraphStyle) => switch (block) {
    DocumentMeta() => _meta(block),
    Heading() => _heading(block),
    Paragraph(:final content) => Text.rich(
      _inlines.spans(content, paragraphStyle),
    ),
    ListBlock() => _list(block),
    QuoteBlock() => _quote(block),
    CodeBlock() => _code(block),
    TableBlock() => _table(block),
    Definition() => _rangeable(
      prefix: block.ranged
          ? _style.icons.definitionMultiPrefix
          : _style.icons.definitionSingle,
      suffix: block.ranged ? _style.icons.definitionMultiSuffix : null,
      group: '@neorg.definitions',
      title: block.term,
      content: block.content,
      task: block.task,
      line: block.range.start,
    ),
    Footnote() => _rangeable(
      prefix: block.ranged
          ? _style.icons.footnoteMultiPrefix
          : _style.icons.footnoteSingle,
      suffix: block.ranged ? _style.icons.footnoteMultiSuffix : null,
      group: '@neorg.footnotes',
      title: [TextInline(block.title)],
      content: block.content,
      task: block.task,
      line: block.range.start,
    ),
    RangedBlock() => _ranged(block),
    InfirmTag(name: 'toc') => _tableOfContents(),
    InfirmTag(name: 'image', :final params)
        when widget.buildImage?.call(params) != null =>
      Align(alignment: Alignment.centerLeft, child: widget.buildImage!(params)),
    MathBlock(:final tex) => SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: _inlines.math(tex, MathStyle.display, _style.base),
    ),
    ImageBlock() => _embeddedImage(block),
    VerbatimTag() => _rawBlock(block),
    InfirmTag(:final name, :final params) => Text.rich(
      TextSpan(
        children: [
          TextSpan(
            text: '.$name',
            style: _style.group('@neorg.tags.carryover.begin'),
          ),
          TextSpan(
            text: ' $params',
            style: _style.group('@neorg.tags.carryover.parameters'),
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
              TextSpan(text: key, style: _style.group('$prefix.key')),
              const TextSpan(text: ': '),
              TextSpan(
                text: value,
                style: _style.group(
                  _style.theme.defines('$prefix.$key')
                      ? '$prefix.$key'
                      : '$prefix.value',
                ),
              ),
            ],
          ),
        ),
    ]);
  }

  Widget _heading(Heading heading) => _column([
    _headingTitle(heading),
    if (!_collapsed.contains(heading.line) && heading.children.isNotEmpty)
      _indented(
        2,
        Padding(
          padding: const EdgeInsets.only(top: 8),
          child: _column(_blocks(heading.children)),
        ),
      ),
  ]);

  Widget _headingTitle(Heading heading) {
    final level = heading.level;
    final titleStyle = _style.group('@neorg.headings.$level.title');
    final line = heading.line;
    final progress = heading.task == null ? null : progressOfHeading(heading);
    return Text.rich(
      TextSpan(
        children: [
          TextSpan(
            text: '${iconForLevel(_style.icons.headingIcons, level)} ',
            style: _style.group('@neorg.headings.$level.prefix'),
            recognizer: heading.children.isEmpty
                ? null
                : _recognizer(('fold', line), () => _toggle(line)),
          ),
          if (heading.task case final task?) ..._taskSpans(task, line),
          _inlines.spans(heading.title, titleStyle),
          if (progress != null) TextSpan(text: ' ${progressLabel(progress)}'),
          if (_collapsed.contains(line))
            TextSpan(
              text: ' …',
              style: titleStyle,
              recognizer: _recognizer(('fold', line), () => _toggle(line)),
            ),
        ],
      ),
    );
  }

  Future<void> _elementMenu(int line) async {
    final choice = await pickElementChoice(
      context,
      source: widget.source,
      blocks: widget.blocks,
      line: line,
      focused: _narrowed == line,
      editable: widget.onTransform != null,
    );
    switch (choice) {
      case ToggleFocus():
        _narrow(_narrowed == line ? null : line);
      case EditElement(:final edit, :final notice):
        widget.onTransform?.call(edit, notice: notice);
      case null:
    }
  }

  TextStyle _todoStyle(TodoStatus? status) => _style.group(
    '@neorg.todo_items.${todoGroups[status ?? TodoStatus.undone]}',
  );

  List<InlineSpan> _taskSpans(TaskExtension task, int? line) {
    final status = task.status;
    final recurrence = task.recurrence == null ? '' : ' ${task.recurrence}';
    final segments = [
      if (status != null) '${_style.icons.todoIcons[status]!}$recurrence',
      ...task.details,
    ];
    final text = '(${segments.join('|')})';
    final style = _todoStyle(status);
    final onTransform = widget.onTransform;
    return [
      if (status != null && line != null && onTransform != null)
        WidgetSpan(
          alignment: PlaceholderAlignment.baseline,
          baseline: TextBaseline.alphabetic,
          child: GestureDetector(
            onTap: () =>
                onTransform((source) => cycleTodo(source, widget.blocks, line)),
            onLongPressStart: (details) async {
              final edit = await pickTaskEdit(
                context,
                position: details.globalPosition,
                blocks: widget.blocks,
                line: line,
                status: status,
                due: taskDate(task.details, '<', today: DateTime.now()),
              );
              if (edit != null) onTransform(edit);
            },
            child: SelectionGroup(
              copied: (_) =>
                  '(${['${statusChars[status]}$recurrence', ...task.details].join('|')})',
              child: Text(text, style: style),
            ),
          ),
        )
      else
        TextSpan(text: text, style: style),
      const TextSpan(text: ' '),
    ];
  }

  Widget _list(ListBlock list) {
    final progress = progressOfItems(list.items);
    return _column([
      for (final (index, ordinal) in _ordinals(list.items).indexed)
        _indented(
          list.items[index].level - 1.0,
          Padding(
            padding: const EdgeInsets.only(bottom: 2),
            child: _listItem(list.items[index], ordinal, progress[index]),
          ),
        ),
    ]);
  }

  String _itemIcon(ListItem item, int ordinal) =>
      item.kind == NestableKind.ordered
      ? formatOrderedIcon(
          iconForLevel(_style.icons.orderedIcons, item.level),
          ordinal,
        )
      : iconForLevel(_style.icons.listIcons, item.level);

  Widget _listItem(ListItem item, int ordinal, (int, int)? progress) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (item.kind == NestableKind.ordered)
          Text(
            '${_itemIcon(item, ordinal)} ',
            style: _style.group('@neorg.lists.ordered.prefix'),
          )
        else
          SelectionContainer.disabled(
            child: Text(
              '${_itemIcon(item, ordinal)} ',
              style: _style.group('@neorg.lists.unordered.prefix'),
            ),
          ),
        Expanded(
          child: Text.rich(
            TextSpan(
              children: [
                if (item.task case final task?) ..._taskSpans(task, item.line),
                _inlines.spans(item.content, _style.base),
                if (item.task != null && progress != null)
                  TextSpan(text: ' ${progressLabel(progress)}'),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _quote(QuoteBlock quote) => _column([
    for (final line in quote.lines)
      Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${[for (var level = 1; level <= line.level; level++) iconForLevel(_style.icons.quoteIcons, level)].join()} ',
            style: _style.group('@neorg.quotes.${line.level}.prefix'),
          ),
          Expanded(
            child: Text.rich(
              TextSpan(
                children: [
                  if (line.task case final task?) ..._taskSpans(task, null),
                  _inlines.spans(
                    line.content,
                    _style.group('@neorg.quotes.${line.level}.content'),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
  ]);

  Widget _code(CodeBlock code) {
    final language = code.language;
    final highlighted = _highlighted.putIfAbsent((
      code,
      Theme.of(context).brightness,
    ), () => _highlight(code));
    const tag = '@neorg.tags.ranged_verbatim';
    return Container(
      color: _style.theme['$tag.code_block'].background,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: _column([
        if (!_style.icons.codeBlockConceal)
          Text.rich(
            TextSpan(
              children: [
                TextSpan(text: '@code', style: _style.group('$tag.name.word')),
                if (language != null)
                  TextSpan(
                    text: ' $language',
                    style: _style.group('$tag.parameters'),
                  ),
              ],
            ),
          ),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Text.rich(
            highlighted ?? TextSpan(text: code.code, style: _style.base),
            softWrap: false,
          ),
        ),
        if (!_style.icons.codeBlockConceal)
          Text('@end', style: _style.group('$tag.end')),
      ]),
    );
  }

  Widget _embeddedImage(ImageBlock image) {
    final Uint8List bytes;
    try {
      bytes = base64Decode(image.data);
    } on FormatException {
      return _rawBlock(image);
    }
    return Align(
      alignment: Alignment.centerLeft,
      child: image.format == 'svg'
          ? svgFromBytes(bytes)
          : Image.memory(
              bytes,
              errorBuilder: (context, error, _) =>
                  Text('$error', style: _style.group('@neorg.error')),
            ),
    );
  }

  Widget _rawBlock(Block block) => Text.rich(
    _rawSpans(dedent(_lines.sublist(block.range.start, block.range.end))),
  );

  TextSpan? _highlight(CodeBlock code) {
    final language = code.language;
    if (language == 'norg') {
      return RawHighlighter(
        _style.theme,
        _style.base,
        conceal: true,
      ).highlight(code.code);
    }
    if (language == null || codeHighlighter.getLanguage(language) == null) {
      return null;
    }
    final renderer = TextSpanRenderer(
      _style.base,
      _style.theme.codeTheme(_style.base),
    );
    codeHighlighter
        .highlight(code: code.code, language: language)
        .render(renderer);
    return renderer.span;
  }

  Widget _table(TableBlock table) {
    final columns = table.rows.fold(
      0,
      (widest, row) => row.length > widest ? row.length : widest,
    );
    final borderColor =
        _style.theme['@neorg.delimiters.horizontal_line'].foreground ??
        _style.theme.foreground;
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
                      _inlines.spans(
                        column < row.length ? row[column] : const [],
                        index == 0
                            ? _style.group('@neorg.markup.bold')
                            : _style.base,
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
    required TaskExtension? task,
    required int line,
  }) => _column([
    Text.rich(
      TextSpan(
        children: [
          TextSpan(text: '$prefix ', style: _style.group('$group.prefix')),
          if (task != null) ..._taskSpans(task, line),
          _inlines.spans(title, _style.group('$group.title')),
        ],
      ),
    ),
    _indented(2, _column(_blocks(content, _style.group('$group.content')))),
    if (suffix != null) Text(suffix, style: _style.group('$group.suffix')),
  ]);

  Widget _ranged(RangedBlock block) {
    final children = _blocks(block.children);
    if (block.name != 'details') return _column(children);
    return ExpansionTile(
      title: Text(block.params.isEmpty ? 'details' : block.params),
      textColor: _style.theme.foreground,
      collapsedTextColor: _style.theme.foreground,
      iconColor: _style.theme.foreground,
      collapsedIconColor: _style.theme.foreground,
      shape: const Border(),
      collapsedShape: const Border(),
      tilePadding: EdgeInsets.zero,
      childrenPadding: EdgeInsets.only(left: 2 * _style.charWidth),
      expandedCrossAxisAlignment: CrossAxisAlignment.stretch,
      children: children,
    );
  }

  Widget _tableOfContents() =>
      HeadingOutline(blocks: widget.blocks, onSelect: jumpToLine);

  Widget _delimiter(DelimiterLine line) {
    final (icon, group) = switch (line.kind) {
      DelimiterKind.weak => (
        _style.icons.weakDelimiter,
        '@neorg.delimiters.weak',
      ),
      DelimiterKind.strong => (
        _style.icons.strongDelimiter,
        '@neorg.delimiters.strong',
      ),
      DelimiterKind.horizontal => (
        _style.icons.horizontalLine,
        '@neorg.delimiters.horizontal_line',
      ),
    };
    if (line.kind != DelimiterKind.horizontal) {
      return Text(icon * line.length, style: _style.group(group));
    }
    return LayoutBuilder(
      builder: (context, constraints) => Text(
        icon * (constraints.maxWidth / _style.charWidth).floor(),
        style: _style.group(group),
        maxLines: 1,
        softWrap: false,
        overflow: TextOverflow.clip,
      ),
    );
  }

  Future<void> _followLink(String target) async {
    if (_targets.lineOf(target) != null) return _jumpTo(target);
    if (widget.onLink case final onLink?) return onLink(target);
    if (Uri.tryParse(target) case final uri? when uri.hasScheme) {
      if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
        if (mounted) context.notify((l10n) => l10n.couldNotOpen(target));
      }
      return;
    }
    context.notify((l10n) => l10n.unsupportedLink(target));
  }

  void _jumpTo(String location) {
    final line = _targets.lineOf(location);
    if (line == null) {
      context.notify((l10n) => l10n.notFound(location));
      return;
    }
    jumpToLine(line);
  }

  void jumpToLine(int line) {
    final narrowed = _narrowedHeading;
    setState(() {
      _collapsed.clear();
      if (narrowed != null &&
          (line < narrowed.line || line >= subtreeEnd(narrowed))) {
        _narrowed = null;
      }
      _rows = null;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final rows = _visibleRows;
      final index = rows.indexWhere((row) => row.range.end > line);
      _listController.animateToItem(
        index: index < 0 ? rows.length - 1 : index,
        scrollController: _scrollController,
        alignment: 0,
        duration: (_) => const Duration(milliseconds: 300),
        curve: (_) => Curves.easeInOut,
      );
    });
  }
}

class _PrefixLongPress extends LongPressGestureRecognizer {
  _PrefixLongPress(this.zoneEnd);

  double zoneEnd;

  @override
  bool isPointerAllowed(PointerDownEvent event) =>
      event.localPosition.dx <= zoneEnd && super.isPointerAllowed(event);
}

int? _movedLine(List<String> before, List<String> after, int line) {
  final shortest = min(before.length, after.length);
  var prefix = 0;
  while (prefix < shortest && before[prefix] == after[prefix]) {
    prefix++;
  }
  if (line < prefix) return line;
  var suffix = 0;
  while (suffix < shortest - prefix &&
      before[before.length - 1 - suffix] == after[after.length - 1 - suffix]) {
    suffix++;
  }
  return line >= before.length - suffix
      ? line + after.length - before.length
      : null;
}
