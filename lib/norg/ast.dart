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

class TaskExtension {
  const TaskExtension(this.status, this.details);
  final TodoStatus? status;
  final List<String> details;
}

class CarryoverTag {
  const CarryoverTag(this.name, this.params);
  final String name;
  final String params;
}

class SourceRange {
  const SourceRange(this.start, this.end);
  static const empty = SourceRange(0, 0);
  final int start;
  final int end;
}

sealed class Inline {
  const Inline({this.start = 0, this.end = 0});
  final int start;
  final int end;
}

class TextInline extends Inline {
  const TextInline(this.text, {super.start, super.end});
  final String text;
}

class StyledInline extends Inline {
  const StyledInline(this.style, this.children, {super.start, super.end});
  final InlineStyle style;
  final List<Inline> children;
}

class VerbatimInline extends Inline {
  const VerbatimInline(this.kind, this.text, {super.start, super.end});
  final VerbatimKind kind;
  final String text;
}

class TargetInline extends Inline {
  const TargetInline(this.text, {super.start, super.end});
  final String text;
}

class AnchorInline extends Inline {
  const AnchorInline(this.description, {super.start, super.end});
  final List<Inline> description;
}

class LinkInline extends Inline {
  const LinkInline(this.target, this.description, {super.start, super.end});
  final String target;
  final List<Inline> description;
}

sealed class Block {
  Block();
  SourceRange range = SourceRange.empty;
  List<CarryoverTag> tags = const [];
}

class DocumentMeta extends Block {
  DocumentMeta(this.fields);
  final Map<String, String> fields;
}

class Heading extends Block {
  Heading(this.level, this.title, this.task, {required this.line});
  final int level;
  final int line;
  final List<Inline> title;
  final TaskExtension? task;
  TodoStatus? get status => task?.status;
  final List<Block> children = [];
}

class Paragraph extends Block {
  Paragraph(this.content);
  final List<Inline> content;
}

class ListItem {
  const ListItem(
    this.kind,
    this.level,
    this.task,
    this.content, {
    required this.line,
    required this.range,
  });
  final NestableKind kind;
  final int line;
  final SourceRange range;
  final int level;
  final TaskExtension? task;
  TodoStatus? get status => task?.status;
  final List<Inline> content;
}

class ListBlock extends Block {
  ListBlock(this.items);
  final List<ListItem> items;
}

class QuoteLine {
  const QuoteLine(this.level, this.content, {this.task});
  final int level;
  final List<Inline> content;
  final TaskExtension? task;
}

class QuoteBlock extends Block {
  QuoteBlock(this.lines);
  final List<QuoteLine> lines;
}

class CodeBlock extends Block {
  CodeBlock(this.language, this.code);
  final String? language;
  final String code;
}

class TableBlock extends Block {
  TableBlock(this.rows);
  final List<List<List<Inline>>> rows;
}

class Definition extends Block {
  Definition(this.term, this.content, {required this.ranged, this.task});
  final List<Inline> term;
  final List<Block> content;
  final bool ranged;
  final TaskExtension? task;
}

class Footnote extends Block {
  Footnote(this.title, this.content, {required this.ranged, this.task});
  final String title;
  final List<Block> content;
  final bool ranged;
  final TaskExtension? task;
}

class MathBlock extends Block {
  MathBlock(this.tex);
  final String tex;
}

class ImageBlock extends Block {
  ImageBlock(this.format, this.data);
  final String format;
  final String data;
}

class InfirmTag extends Block {
  InfirmTag(this.name, this.params);
  final String name;
  final String params;
}

class RangedBlock extends Block {
  RangedBlock(this.name, this.params, this.children);
  final String name;
  final String params;
  final List<Block> children;
}

class DelimiterLine extends Block {
  DelimiterLine(this.kind, this.length);
  final DelimiterKind kind;
  final int length;
}
