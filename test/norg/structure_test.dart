import 'package:flutter_test/flutter_test.dart';
import 'package:morg/norg/ast.dart';
import 'package:morg/norg/parser.dart';
import 'package:morg/norg/structure.dart';

const source = '''* (-) Project
  - (x) one
  - ( ) two
  -- ( ) two.a
** (x) Sub A
   text a
** ( ) Sub B
   text b
* Other''';

void main() {
  final blocks = parseNorg(source);

  test('demoting an item moves its children too', () {
    expect(changeLevel(source, blocks, 2, 1)!.split('\n').sublist(2, 4), [
      '  -- ( ) two',
      '  --- ( ) two.a',
    ]);
  });

  test('a first-level heading cannot be promoted', () {
    expect(changeLevel(source, blocks, 0, -1), isNull);
  });

  test('moving a heading swaps whole subtrees', () {
    final moved = move(source, blocks, 6, -1)!.split('\n');
    expect(moved.sublist(4, 8), [
      '** ( ) Sub B',
      '   text b',
      '** (x) Sub A',
      '   text a',
    ]);
  });

  test('the list type changes for the whole level', () {
    final toggled = toggleListKind(source, blocks, 2)!.split('\n');
    expect(toggled.sublist(1, 4), [
      '  ~ (x) one',
      '  ~ ( ) two',
      '  -- ( ) two.a',
    ]);
  });

  test('deleting a heading removes its subtree', () {
    expect(deleteElement(source, blocks, 4), isNot(contains('text a')));
  });

  test('progress counts direct children with counted states', () {
    final list = blocks
        .whereType<Heading>()
        .first
        .children
        .whereType<ListBlock>()
        .single;
    expect(progressOfItems(list.items), [null, (0, 1), null]);
    expect(progressOfHeading(blocks.first as Heading), (1, 2));
    expect(progressLabel((1, 2)), '[1/2] (50%)');
  });

  test('tasks carry their dates and priority', () {
    final tasks = tasksOf(parseNorg('- (!|# A|< 2026-11-03) call')).single;
    expect(tasks.priority, 'A');
    expect(tasks.date('<', defaultYear: 2026), DateTime(2026, 11, 3));
  });
}
