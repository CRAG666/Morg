import 'dart:convert';

import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:morg/workspace/store.dart';

const _root = 'content://drive/tree/root';

class _Document {
  _Document(this.uri, this.parent, this.name, this.isDir, this.modified);

  final String uri;
  final String parent;
  final String name;
  final bool isDir;
  final int modified;
  Uint8List bytes = Uint8List(0);

  Map<String, Object?> toMap() => {
    'uri': uri,
    'name': name,
    'isDir': isDir,
    'length': bytes.length,
    'lastModified': modified,
  };
}

class _FakeDrive {
  _FakeDrive() {
    final messenger =
        TestWidgetsFlutterBinding.ensureInitialized().defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(const MethodChannel('saf_util'), _util);
    messenger.setMockMethodCallHandler(
      const MethodChannel('saf_stream'),
      _stream,
    );
  }

  final documents = <_Document>[];
  final staleLookups = <String>{};
  final failingWrites = <String>{};

  String add(
    String name, {
    String parent = _root,
    int modified = 0,
    bool isDir = false,
  }) {
    final document = _Document(
      'content://drive/document/${documents.length}',
      parent,
      name,
      isDir,
      modified,
    );
    documents.add(document);
    return document.uri;
  }

  List<_Document> named(String name) =>
      documents.where((document) => document.name == name).toList();

  String text(String uri) =>
      utf8.decode(documents.firstWhere((d) => d.uri == uri).bytes);

  _Document? _lookup(String parent, String name) => documents
      .where(
        (document) =>
            document.parent == parent &&
            document.name == name &&
            !staleLookups.contains(document.uri),
      )
      .firstOrNull;

  _Document _create(String parent, String name, {bool isDir = false}) {
    final document = _Document(
      'content://drive/document/${documents.length}',
      parent,
      name,
      isDir,
      documents.length,
    );
    documents.add(document);
    return document;
  }

  Future<Object?> _util(MethodCall call) async {
    final arguments = call.arguments as Map<Object?, Object?>;
    final uri = arguments['uri']! as String;
    final names = (arguments['names'] as List<Object?>?)?.cast<String>();
    switch (call.method) {
      case 'list':
        return [
          for (final document in documents)
            if (document.parent == uri && !staleLookups.contains(document.uri))
              document.toMap(),
        ];
      case 'child':
        var parent = uri;
        _Document? found;
        for (final name in names!) {
          found = _lookup(parent, name);
          if (found == null) return null;
          parent = found.uri;
        }
        return found?.toMap();
      case 'mkdirp':
        var parent = uri;
        late _Document directory;
        for (final name in names!) {
          directory =
              _lookup(parent, name) ?? _create(parent, name, isDir: true);
          parent = directory.uri;
        }
        return directory.toMap();
    }
    throw MissingPluginException(call.method);
  }

  Future<Object?> _stream(MethodCall call) async {
    final arguments = call.arguments as Map<Object?, Object?>;
    final data = arguments['data']! as Uint8List;
    final _Document target;
    if (arguments['fileUri'] case final String uri) {
      if (failingWrites.remove(uri)) {
        throw PlatformException(code: 'PluginError', message: 'offline');
      }
      target = documents.firstWhere((document) => document.uri == uri);
    } else {
      final parent = arguments['treeUri']! as String;
      final name = arguments['fileName']! as String;
      target =
          (arguments['overwrite'] == true ? _lookup(parent, name) : null) ??
          _create(parent, name);
    }
    target.bytes = data;
    return {'uri': target.uri, 'fileName': target.name};
  }
}

void main() {
  test(
    'saving a listed note updates it when the lookup by name misses',
    () async {
      final drive = _FakeDrive();
      final index = drive.add('index.norg');
      final store = SafStore(_root);
      await store.list('');
      drive.staleLookups.add(index);
      await store.write('index.norg', 'edited');
      expect(drive.named('index.norg'), hasLength(1));
      expect(drive.text(index), 'edited');
    },
  );

  test(
    'of two notes with the same name, the newest is listed and saved',
    () async {
      final drive = _FakeDrive();
      const folder = '$_root/duplicates';
      final older = drive.add('index.norg', parent: folder, modified: 1);
      final newer = drive.add('index.norg', parent: folder, modified: 2);
      final store = SafStore(folder);
      final [entry] = await store.list('');
      expect(entry.modified, 2);
      await store.write('index.norg', 'edited');
      expect(drive.text(newer), 'edited');
      expect(drive.text(older), isEmpty);
    },
  );

  test('a new note in a new folder is created once', () async {
    final drive = _FakeDrive();
    final store = SafStore('$_root/new');
    await store.write('journal/today.norg', 'first');
    await store.write('journal/today.norg', 'second');
    final [note] = drive.named('today.norg');
    expect(drive.text(note.uri), 'second');
    expect(drive.named('journal'), hasLength(1));
  });

  test('creating a note never replaces one the lookup misses', () async {
    const folder = '$_root/existing';
    final drive = _FakeDrive();
    final today = drive.add('today.norg', parent: folder);
    await drive._stream(
      MethodCall('writeFileBytes', {
        'fileUri': today,
        'data': utf8.encode('my notes'),
      }),
    );
    final store = SafStore(folder);
    await store.list('');
    drive.staleLookups.add(today);
    expect(await store.create('today.norg', utf8.encode('template')), isFalse);
    expect(drive.named('today.norg'), hasLength(1));
    expect(drive.text(today), 'my notes');
  });

  test('two creations of the same note at once make one file', () async {
    final drive = _FakeDrive();
    final store = SafStore('$_root/concurrent');
    final created = await Future.wait([
      store.create('journal/today.norg', utf8.encode('a')),
      store.create('journal/today.norg', utf8.encode('b')),
    ]);
    expect(created, unorderedEquals([true, false]));
    expect(drive.named('today.norg'), hasLength(1));
    expect(drive.named('journal'), hasLength(1));
  });

  test('a failed save does not make the next one create a file', () async {
    const folder = '$_root/offline';
    final drive = _FakeDrive();
    final note = drive.add('note.norg', parent: folder);
    final store = SafStore(folder);
    await store.list('');
    drive
      ..staleLookups.add(note)
      ..failingWrites.add(note);
    await expectLater(
      store.write('note.norg', 'first try'),
      throwsA(isA<FileSystemException>()),
    );
    await store.write('note.norg', 'second try');
    expect(drive.named('note.norg'), hasLength(1));
    expect(drive.text(note), 'second try');
  });

  test('a new note goes into a known folder when its lookup misses', () async {
    const folder = '$_root/known-folder';
    final drive = _FakeDrive();
    final journal = drive.add('journal', parent: folder, isDir: true);
    final store = SafStore(folder);
    await store.list('');
    drive.staleLookups.add(journal);
    expect(await store.create('journal/new.norg', utf8.encode('x')), isTrue);
    expect(drive.named('journal'), hasLength(1));
    expect(drive.named('new.norg').single.parent, journal);
  });
}
