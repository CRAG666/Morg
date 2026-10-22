import 'package:flutter_test/flutter_test.dart';
import 'package:morg/norg/ast.dart';
import 'package:morg/norg/edits.dart';
import 'package:morg/norg/parser.dart';

String cycle(String source, int line) =>
    cycleTodo(source, parseNorg(source), line);

void main() {
  test('cycling follows neorg: undone, done, pending', () {
    expect(cycle('- ( ) a', 0), '- (x) a');
    expect(cycle('- (x) a', 0), '- (-) a');
    expect(cycle('- (-) a', 0), '- ( ) a');
  });

  test('children follow their parent and the parent is recomputed', () {
    const source = '- ( ) parent\n-- ( ) one\n-- (x) two';
    expect(
      setTodo(source, parseNorg(source), 0, TodoStatus.onHold),
      '- (=) parent\n-- (=) one\n-- (=) two',
    );
    expect(cycle(source, 1), '- (x) parent\n-- (x) one\n-- (x) two');
  });

  test('setting a status keeps the other extension segments', () {
    const source = '- (# B| ) three';
    expect(
      setTodo(source, parseNorg(source), 0, TodoStatus.done),
      '- (# B|x) three',
    );
  });

  test('due dates are added and removed', () {
    final dated = setTaskDate('- ( ) a', 0, '<', DateTime(2026, 10, 30));
    expect(dated, '- ( |< Fri, 30 Oct 2026) a');
    expect(setTaskDate(dated, 0, '<', null), '- ( ) a');
  });

  test('saving refreshes the updated field of the metadata', () {
    const source = '@document.meta\nupdated: old\n@end\n';
    expect(
      touchUpdated(source, DateTime(2026, 1, 2, 3, 4, 5)),
      startsWith('@document.meta\nupdated: 2026-01-02T03:04:05'),
    );
  });
}
