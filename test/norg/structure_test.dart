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

  final today = DateTime(2026, 10, 22);

  test('tasks carry their dates and priority', () {
    final task = tasksOf(parseNorg('- (!|# A|< 2026-11-03) call')).single;
    expect(task.priority, 'A');
    expect(task.date('<', today: today), DateTime(2026, 11, 3));
  });

  test('a recurrence keeps its date and repeats', () {
    final task = tasksOf(parseNorg('- (+ 5th Jan) birthday')).single;
    expect(task.status, TodoStatus.recurring);
    expect(task.recurrence, '5th Jan');
    expect(task.date('+', today: today), DateTime(2027, 1, 5));
  });

  test('dated items without a status are listed, plain ones are not', () {
    final entries = tasksOf(
      parseNorg('- (< Tue 5th Feb) due\n- (# A) only priority\n- plain'),
    );
    expect(entries.map((entry) => (entry.title, entry.status)), [
      ('due', null),
    ]);
  });

  test('inline timestamps become dated entries', () {
    final entry = tasksOf(parseNorg("Frank's birthday is on {@ 5th May}."))
        .single;
    expect(entry.title, "Frank's birthday is on 5th May.");
    expect(entry.date('@', today: today), DateTime(2026, 5, 5));
  });
}
