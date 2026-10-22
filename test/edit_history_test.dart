import 'package:flutter_test/flutter_test.dart';
import 'package:morg/edit_history.dart';

void main() {
  test('undo and redo walk the recorded versions', () {
    final history = EditHistory()..record('v1');
    expect(history.undo('v2'), 'v1');
    expect(history.redo('v1'), 'v2');
    expect(history.canRedo, isFalse);
  });

  test('a new edit clears the redo stack', () {
    final history = EditHistory()..record('v1');
    history.undo('v2');
    history.record('v1');
    expect(history.canRedo, isFalse);
  });

  test('only the most recent versions are kept', () {
    final history = EditHistory(limit: 2);
    for (final version in ['v1', 'v2', 'v3']) {
      history.record(version);
    }
    expect(
      [history.undo('v4'), history.undo('v3'), history.undo('v2')],
      ['v3', 'v2', null],
    );
  });
}
