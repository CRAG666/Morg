import 'package:flutter_test/flutter_test.dart';
import 'package:morg/norg/ast.dart';
import 'package:morg/norg/parser.dart';

void main() {
  test('headings nest by level and clamp to six', () {
    final blocks = parseNorg('* One\n** Two\n******** Deep\n* Three');
    final [one as Heading, three as Heading] = blocks;
    final two = one.children.single as Heading;
    expect([one.level, two.level, three.level], [1, 2, 1]);
    expect((two.children.single as Heading).level, 6);
  });

  test('a task status may be in any extension segment', () {
    final list = parseNorg('- (# B| ) three').single as ListBlock;
    final task = list.items.single.task!;
    expect(task.status, TodoStatus.undone);
    expect(task.details, ['# B']);
  });

  test('every status character is recognised', () {
    final statuses = [
      for (final char in [' ', 'x', '?', '!', '+', '-', '=', '_'])
        ((parseNorg('- ($char) item').single as ListBlock).items.single.status),
    ];
    expect(statuses, [
      TodoStatus.undone,
      TodoStatus.done,
      TodoStatus.needsInput,
      TodoStatus.urgent,
      TodoStatus.recurring,
      TodoStatus.pending,
      TodoStatus.onHold,
      TodoStatus.cancelled,
    ]);
  });

  test('list items keep their source lines', () {
    final list = parseNorg('- a\n-- b\n   continued\n- c').single as ListBlock;
    expect([for (final item in list.items) item.line], [0, 1, 3]);
    expect([for (final item in list.items) item.level], [1, 2, 1]);
  });

  test('links, anchors and inline markup', () {
    final paragraph =
        parseNorg('See {* Heading}[the heading], [site] and *bold*.').single
            as Paragraph;
    final nodes = paragraph.content;
    expect(nodes.whereType<LinkInline>().single.target, '* Heading');
    expect(nodes.whereType<AnchorInline>(), hasLength(1));
    expect(nodes.whereType<StyledInline>().single.style, InlineStyle.bold);
  });

  test('code blocks, unknown verbatim tags and carryover tags', () {
    final blocks = parseNorg(
      '@code dart\nvoid main() {}\n@end\n@data x\ny\n@end\n#name quoted\n> quote',
    );
    expect((blocks[0] as CodeBlock).language, 'dart');
    expect(blocks[1], isA<VerbatimTag>());
    expect(blocks[2].tags.single.name, 'name');
    expect(blocks[2].tags.single.params, 'quoted');
  });
}
