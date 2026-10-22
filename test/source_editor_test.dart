import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:morg/source_editor.dart';

(String, int) enter(String line) {
  final cursor = line.length;
  final value = const ListContinuation().formatEditUpdate(
    TextEditingValue(
      text: line,
      selection: TextSelection.collapsed(offset: cursor),
    ),
    TextEditingValue(
      text: '$line\n',
      selection: TextSelection.collapsed(offset: cursor + 1),
    ),
  );
  return (value.text, value.selection.baseOffset);
}

void main() {
  test('lists, tasks and quotes continue on Enter', () {
    expect(enter('- (x) first'), ('- (x) first\n- ( ) ', 18));
    expect(enter('~~ second'), ('~~ second\n~~ ', 13));
    expect(enter('> quote'), ('> quote\n> ', 10));
  });

  test('an empty item ends the list', () {
    expect(enter('- '), ('', 0));
  });

  test('plain lines are left alone', () {
    expect(enter('plain'), ('plain\n', 6));
  });
}
