import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/painting.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path/path.dart' as p;

export 'saf_store_stub.dart' if (dart.library.io) 'saf_store.dart';

class NoteEntry {
  const NoteEntry(this.path, {required this.isDirectory});

  final String path;
  final bool isDirectory;

  String get name => p.posix.basename(path);
}

abstract interface class NoteStore {
  String get location;

  Future<List<NoteEntry>> list(String directory);

  Future<bool> exists(String path);

  Future<Uint8List> readBytes(String path);

  Future<void> writeBytes(String path, Uint8List bytes);

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
  String get location => root.path;

  File _file(String path) => File(p.join(root.path, path));

  @override
  Future<List<NoteEntry>> list(String directory) async => [
    await for (final entity in Directory(p.join(root.path, directory)).list())
      NoteEntry(
        p.relative(entity.path, from: root.path),
        isDirectory: entity is Directory,
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
  Future<void> openExternally(String path) => openWithSystem(_file(path).path);

  @override
  bool operator ==(Object other) =>
      other is LocalStore && p.equals(other.root.path, root.path);

  @override
  int get hashCode => p.canonicalize(root.path).hashCode;
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
