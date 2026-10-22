import 'dart:io';

import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:saf_stream/saf_stream.dart';
import 'package:saf_util/saf_util.dart';

import 'store.dart';

const _norgMime = 'application/octet-stream';

class SafStore implements NoteStore {
  SafStore(this.treeUri);

  final String treeUri;
  final _util = SafUtil();
  final _stream = SafStream();

  @override
  String get location => Uri.decodeComponent(treeUri.split('/').last);

  List<String> _segments(String path) =>
      p.posix.split(path).where((segment) => segment != '.').toList();

  Future<String> _uri(String path) async {
    final segments = _segments(path);
    if (segments.isEmpty) return treeUri;
    final document = await _util.child(treeUri, segments);
    if (document == null) {
      throw FileSystemException('Not found in the cloud folder', path);
    }
    return document.uri;
  }

  @override
  Future<List<NoteEntry>> list(String directory) => _saf(
    directory,
    () async => [
      for (final document in await _util.list(await _uri(directory)))
        NoteEntry(
          p.posix.join(directory, document.name),
          isDirectory: document.isDir,
        ),
    ],
  );

  @override
  Future<bool> exists(String path) => _saf(path, () async {
    final segments = _segments(path);
    return segments.isEmpty || await _util.child(treeUri, segments) != null;
  });

  @override
  Future<Uint8List> readBytes(String path) =>
      _saf(path, () async => _stream.readFileBytes(await _uri(path)));

  @override
  Future<void> writeBytes(String path, Uint8List bytes) => _saf(path, () async {
    final segments = _segments(path);
    final existing = await _util.child(treeUri, segments);
    if (existing != null) {
      await _stream.writeFileUriBytes(existing.uri, bytes);
      return;
    }
    final parents = segments.sublist(0, segments.length - 1);
    final directory = parents.isEmpty
        ? treeUri
        : (await _util.mkdirp(treeUri, parents)).uri;
    await _stream.writeFileBytes(directory, segments.last, _norgMime, bytes);
  });

  @override
  Future<void> delete(String path) =>
      _saf(path, () async => _util.delete(await _uri(path), false));

  @override
  Future<void> openExternally(String path) => _saf(path, () async {
    final copy = p.join(
      (await getTemporaryDirectory()).path,
      p.posix.basename(path),
    );
    await _stream.copyToLocalFile(await _uri(path), copy);
    await openWithSystem(copy);
  });

  @override
  bool operator ==(Object other) =>
      other is SafStore && other.treeUri == treeUri;

  @override
  int get hashCode => treeUri.hashCode;
}

class SafFileStore implements NoteStore {
  SafFileStore(this.fileUri, this.fileName);

  final String fileUri;
  final String fileName;
  final _stream = SafStream();
  final _util = SafUtil();

  @override
  String get location => fileName;

  void _check(String path) {
    if (path != fileName) {
      throw FileSystemException('Only $fileName was opened', path);
    }
  }

  @override
  Future<List<NoteEntry>> list(String directory) =>
      throw UnsupportedError('A single opened file has no folder');

  @override
  Future<bool> exists(String path) async => path == fileName;

  @override
  Future<Uint8List> readBytes(String path) async {
    _check(path);
    return _saf(path, () => _stream.readFileBytes(fileUri));
  }

  @override
  Future<void> writeBytes(String path, Uint8List bytes) async {
    _check(path);
    await _saf(path, () => _stream.writeFileUriBytes(fileUri, bytes));
  }

  @override
  Future<void> delete(String path) async {
    _check(path);
    await _saf(path, () => _util.delete(fileUri, false));
  }

  @override
  Future<void> openExternally(String path) =>
      throw FileSystemException('A single opened file has no folder', path);
}

Future<T> _saf<T>(String path, Future<T> Function() action) async {
  try {
    return await action();
  } on PlatformException catch (error) {
    throw FileSystemException(error.message ?? error.code, path);
  }
}
