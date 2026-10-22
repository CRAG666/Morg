import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:morg/workspace/index.dart';
import 'package:morg/workspace/store.dart';

import '../helpers.dart';

class CountingStore extends LocalStore {
  CountingStore(super.root);

  var reads = 0;

  @override
  Future<Uint8List> readBytes(String path) {
    reads++;
    return super.readBytes(path);
  }
}

void main() {
  late Directory root;
  late CountingStore store;
  late WorkspaceIndex index;

  setUp(() async {
    final support = await temporaryFolder();
    mockSupportDirectory(support.path);
    root = await temporaryFolder();
    addTearDown(() async {
      await root.delete(recursive: true);
      await support.delete(recursive: true);
    });
    for (var i = 0; i < 12; i++) {
      File('${root.path}/folder${i % 3}/note$i.norg')
        ..parent.createSync(recursive: true)
        ..writeAsStringSync('* (-) Task $i\n');
    }
    File('${root.path}/.hidden/skip.norg')
      ..parent.createSync()
      ..writeAsStringSync('* hidden');
    store = CountingStore(root);
    index = WorkspaceIndex.of(store);
  });

  String title(String path) =>
      index.notes.value!.firstWhere((note) => note.ref.path == path).title;

  test('the first scan reads every note, skipping hidden folders', () async {
    await index.refresh();
    expect(index.notes.value, hasLength(12));
    expect(store.reads, 12);
  });

  test('later scans read only what changed', () async {
    await index.refresh();
    store.reads = 0;
    await index.refresh();
    expect(store.reads, 0);
    await Future<void>.delayed(const Duration(milliseconds: 20));
    File('${root.path}/folder1/note4.norg').writeAsStringSync('* Edited\n');
    await index.refresh();
    expect(store.reads, 1);
    expect(title('folder1/note4.norg'), 'Edited');
  });

  test('deleted notes disappear', () async {
    await index.refresh();
    File('${root.path}/folder2/note5.norg').deleteSync();
    await index.refresh();
    expect(index.notes.value, hasLength(11));
  });

  test('an edit made during a scan is kept', () async {
    await index.refresh();
    File('${root.path}/folder0/note3.norg').writeAsStringSync('* Old\n');
    final scan = index.refresh();
    index.updated('folder0/note3.norg', '* In Morg\n');
    await scan;
    expect(title('folder0/note3.norg'), 'In Morg');
  });
}
