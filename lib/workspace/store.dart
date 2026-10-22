import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/painting.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path/path.dart' as p;

export 'saf_store_stub.dart' if (dart.library.io) 'saf_store.dart';

class NoteEntry {
  const NoteEntry(
    this.path, {
    required this.isDirectory,
    this.modified,
    this.size,
  });

  final String path;
  final bool isDirectory;
  final int? modified;
  final int? size;

  String get name => p.posix.basename(path);
}

abstract interface class NoteStore {
  String get id;

  String get location;

  Future<List<NoteEntry>> list(String directory);

  Future<bool> exists(String path);

  Future<Uint8List> readBytes(String path);

  Future<void> writeBytes(String path, Uint8List bytes);

  Future<void> delete(String path);

  Future<void> openExternally(String path);
}

extension NoteStoreText on NoteStore {
  Future<String> read(String path) async =>
      utf8.decode(await readBytes(path), allowMalformed: true);

  Future<void> write(String path, String contents) =>
      writeBytes(path, utf8.encode(contents));
}

class NoteRef {
  const NoteRef(this.store, this.path);

  final NoteStore store;
  final String path;

  String get name => p.posix.basenameWithoutExtension(path);

  String get directory =>
      p.posix.dirname(path) == '.' ? '' : p.posix.dirname(path);

  @override
  bool operator ==(Object other) =>
      other is NoteRef && other.store == store && other.path == path;

  @override
  int get hashCode => Object.hash(store, path);
}

class LocalStore implements NoteStore {
  LocalStore(this.root);

  final Directory root;

  @override
  String get id => 'local:${p.canonicalize(root.path)}';

  @override
  String get location => root.path;

  File _file(String path) => File(p.join(root.path, path));

  @override
  Future<List<NoteEntry>> list(String directory) async => [
    await for (final entity in Directory(p.join(root.path, directory)).list())
      if (await entity.stat() case final stat)
        NoteEntry(
          p.relative(entity.path, from: root.path),
          isDirectory: stat.type == FileSystemEntityType.directory,
          modified: stat.modified.millisecondsSinceEpoch,
          size: stat.size,
        ),
  ];

  @override
  Future<bool> exists(String path) => _file(path).exists();

  @override
  Future<Uint8List> readBytes(String path) => _file(path).readAsBytes();

  @override
  Future<void> writeBytes(String path, Uint8List bytes) async {
    final file = _file(path);
    await file.parent.create(recursive: true);
    await file.writeAsBytes(bytes);
  }

  @override
  Future<void> delete(String path) => _file(path).delete();

  @override
  Future<void> openExternally(String path) => openWithSystem(_file(path).path);

  @override
  bool operator ==(Object other) =>
      other is LocalStore && p.equals(other.root.path, root.path);

  @override
  int get hashCode => p.canonicalize(root.path).hashCode;
}

class MemoryStore implements NoteStore {
  MemoryStore(this.location, Map<String, String> files)
    : _files = {
        for (final MapEntry(:key, :value) in files.entries)
          key: utf8.encode(value),
      };

  @override
  String get id => 'memory:$location';

  @override
  final String location;
  final Map<String, Uint8List> _files;

  @override
  Future<List<NoteEntry>> list(String directory) async => [
    for (final path in _files.keys) NoteEntry(path, isDirectory: false),
  ];

  @override
  Future<bool> exists(String path) async => _files.containsKey(path);

  @override
  Future<Uint8List> readBytes(String path) async =>
      _files[path] ?? (throw FileSystemException('Not found', path));

  @override
  Future<void> writeBytes(String path, Uint8List bytes) async =>
      _files[path] = bytes;

  @override
  Future<void> delete(String path) async {
    if (_files.remove(path) == null) {
      throw FileSystemException('Not found', path);
    }
  }

  @override
  Future<void> openExternally(String path) =>
      throw FileSystemException('In-memory documents cannot be opened', path);
}

Future<void> openWithSystem(String path) async {
  final result = await OpenFilex.open(path);
  if (result.type != ResultType.done) {
    throw FileSystemException(result.message, path);
  }
}

class StoreImage extends ImageProvider<NoteRef> {
  const StoreImage(this.ref);

  final NoteRef ref;

  @override
  Future<NoteRef> obtainKey(ImageConfiguration configuration) async => ref;

  @override
  ImageStreamCompleter loadImage(NoteRef key, ImageDecoderCallback decode) =>
      MultiFrameImageStreamCompleter(codec: _codec(key, decode), scale: 1);

  Future<ui.Codec> _codec(NoteRef key, ImageDecoderCallback decode) async =>
      decode(
        await ui.ImmutableBuffer.fromUint8List(
          await key.store.readBytes(key.path),
        ),
      );
}
