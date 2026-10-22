import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:morg/workspace/store.dart';

import '../helpers.dart';

String describe(NoteEntry entry) =>
    entry.isDirectory ? '${entry.path}/' : entry.path;

void main() {
  test('a memory folder lists one level at a time', () async {
    final store = MemoryStore('demo', {
      'a.norg': '',
      'sub/b.norg': '',
      'sub/deep/c.norg': '',
    });
    expect((await store.list('')).map(describe), ['a.norg', 'sub/']);
    expect((await store.list('sub')).map(describe), [
      'sub/b.norg',
      'sub/deep/',
    ]);
  });

  test('a local folder reads, writes, lists and deletes', () async {
    final root = await temporaryFolder();
    addTearDown(() => root.delete(recursive: true));
    final store = LocalStore(root);
    await store.write('notes/a.norg', 'hello');
    expect(await store.read('notes/a.norg'), 'hello');
    final [entry] = await store.list('notes');
    expect(
      (entry.path, entry.isDirectory, entry.size),
      ('notes/a.norg', false, 5),
    );
    expect(entry.modified, isNotNull);
    await store.delete('notes/a.norg');
    expect(await store.exists('notes/a.norg'), isFalse);
  });

  test('a local folder knows when it is missing', () async {
    final store = LocalStore(
      Directory('${Directory.systemTemp.path}/morg-none'),
    );
    expect(store.missing, isTrue);
    expect(await store.isReachable(), isFalse);
  });

  test('only memory stores are not persistent', () {
    expect(MemoryStore('x', {}).persistent, isFalse);
    expect(LocalStore(Directory.systemTemp).persistent, isTrue);
  });
}
