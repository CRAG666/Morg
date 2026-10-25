import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:morg/document_screen.dart';
import 'package:morg/workspace/store.dart';

import '../helpers.dart';

class _SlowStore extends MemoryStore {
  _SlowStore(super.location, super.files);

  @override
  Future<void> writeBytes(String path, Uint8List bytes) async {
    await Future<void>.delayed(const Duration(seconds: 2));
    await super.writeBytes(path, bytes);
  }
}

const _note = '''* First
  First paragraph.
* Second
  Second paragraph.
* Third
  Third paragraph.
''';

Future<void> edit(WidgetTester tester, String paragraph, String text) async {
  await tester.tap(find.textContaining(paragraph, findRichText: true).first);
  await tester.pump(const Duration(milliseconds: 300));
  tester.testTextInput.updateEditingValue(
    TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    ),
  );
  await tester.pump(const Duration(milliseconds: 300));
}

void main() {
  testWidgets('editing another element while a slow save runs keeps both', (
    tester,
  ) async {
    final store = _SlowStore('slow', {'note.norg': _note});
    await pumpApp(tester, DocumentScreen(note: NoteRef(store, 'note.norg')));
    await edit(tester, 'First paragraph', '  First paragraph.\n  Added line.');
    await edit(tester, 'Third paragraph', '  Third paragraph, edited.');
    await tester.tapAt(const Offset(200, 800));
    await settle(tester);
    await tester.pump(const Duration(seconds: 5));
    await settle(tester);
    expect(tester.takeException(), isNull);
    expect(
      await store.read('note.norg'),
      contains(
        '* First\n'
        '  First paragraph.\n'
        '  Added line.\n'
        '* Second\n'
        '  Second paragraph.\n'
        '* Third\n'
        '  Third paragraph, edited.\n',
      ),
    );
  });
}
