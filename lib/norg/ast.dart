enum TodoStatus {
  undone,
  done,
  needsInput,
  urgent,
  recurring,
  pending,
  onHold,
  cancelled,
}

enum InlineStyle {
  bold,
  italic,
  underline,
  strikethrough,
  spoiler,
  superscript,
  subscript,
}

enum VerbatimKind { code, math, variable, comment }

enum DelimiterKind { weak, strong, horizontal }

enum NestableKind { unordered, ordered }

sealed class Inline {
  const Inline();
}

class TextInline extends Inline {
  const TextInline(this.text);
  final String text;
}

class StyledInline extends Inline {
  const StyledInline(this.style, this.children);
  final InlineStyle style;
  final List<Inline> children;
}

class VerbatimInline extends Inline {
  const VerbatimInline(this.kind, this.text);
  final VerbatimKind kind;
  final String text;
}

class AnchorInline extends Inline {
  const AnchorInline(this.description);
  final List<Inline> description;
}

class LinkInline extends Inline {
  const LinkInline(this.target, this.description);
  final String target;
  final List<Inline> description;
}

sealed class Block {
  const Block();
}

class DocumentMeta extends Block {
  const DocumentMeta(this.fields);
  final Map<String, String> fields;
}

class Heading extends Block {
  Heading(this.level, this.title, this.status, {required this.line});
  final int level;
  final int line;
  final List<Inline> title;
  final TodoStatus? status;
  final List<Block> children = [];
}

class Paragraph extends Block {
  const Paragraph(this.content);
  final List<Inline> content;
}

class ListItem {
  const ListItem(
    this.kind,
    this.level,
    this.status,
    this.content, {
    required this.line,
  });
  final NestableKind kind;
  final int line;
  final int level;
  final TodoStatus? status;
  final List<Inline> content;
}

class ListBlock extends Block {
  const ListBlock(this.items);
  final List<ListItem> items;
}

class QuoteLine {
  const QuoteLine(this.level, this.content);
  final int level;
  final List<Inline> content;
}

class QuoteBlock extends Block {
  const QuoteBlock(this.lines);
  final List<QuoteLine> lines;
}

class CodeBlock extends Block {
  const CodeBlock(this.language, this.code);
  final String? language;
  final String code;
}

class TableBlock extends Block {
  const TableBlock(this.rows);
  final List<List<List<Inline>>> rows;
}

class Definition extends Block {
  const Definition(this.term, this.content, {required this.ranged});
  final List<Inline> term;
  final List<Block> content;
  final bool ranged;
}

class Footnote extends Block {
  const Footnote(this.title, this.content, {required this.ranged});
  final String title;
  final List<Block> content;
  final bool ranged;
}

class InfirmTag extends Block {
  const InfirmTag(this.name, this.params);
  final String name;
  final String params;
}

class RangedBlock extends Block {
  const RangedBlock(this.name, this.params, this.children);
  final String name;
  final String params;
  final List<Block> children;
}

class DelimiterLine extends Block {
  const DelimiterLine(this.kind, this.length);
  final DelimiterKind kind;
  final int length;
}
