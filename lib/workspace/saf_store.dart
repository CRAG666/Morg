import 'dart:io';

import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:saf_stream/saf_stream.dart';
import 'package:saf_util/saf_util.dart';

import 'store.dart';

const _norgMime = 'application/octet-stream';
const _providers = {'com.google.android.apps.docs.storage': 'Google Drive'};

class SafStore implements NoteFolder {
  SafStore(this.treeUri);

  static final _documents = <String, Map<String, String>>{};
  static final _labels = <String, Future<String>>{};

  final String treeUri;
  final _util = SafUtil();
  final _stream = SafStream();

  Map<String, String> get _known => _documents.putIfAbsent(treeUri, () => {});

  @override
  String get id => 'saf:$treeUri';

  @override
  String get location =>
      _providers[Uri.parse(treeUri).authority] ??
      Uri.decodeComponent(treeUri.split('/').last);

  @override
  bool get persistent => true;

  @override
  bool get remote => true;

  @override
  bool get missing => false;

  @override
  Future<bool> isReachable() =>
      _util.hasPersistedPermission(treeUri, checkWrite: true);

  @override
  Future<void> release() =>
      _util.releasePersistedPermission(treeUri, write: true);

  @override
  Future<String> label() => _labels.putIfAbsent(treeUri, () async {
    final folder = await _saf(treeUri, () => _util.stat(treeUri, true));
    final provider = _providers[Uri.parse(treeUri).authority];
    return [?provider, ?folder?.name].join(' · ').ifEmpty(location);
  });

  List<String> _segments(String path) =>
      p.posix.split(path).where((segment) => segment != '.').toList();

  Future<String> _uri(String path) async {
    final segments = _segments(path);
    if (segments.isEmpty) return treeUri;
    final key = p.posix.joinAll(segments);
    if (_known[key] case final uri?) return uri;
    final document = await _util.child(treeUri, segments);
    if (document == null) {
      throw FileSystemException('Not found in the cloud folder', path);
    }
    return _known[key] = document.uri;
  }

  @override
  Future<List<NoteEntry>> list(String directory) => _saf(directory, () async {
    final entries = <NoteEntry>[];
    for (final document in await _util.list(await _uri(directory))) {
      final path = p.posix.normalize(p.posix.join(directory, document.name));
      _known[path] = document.uri;
      entries.add(
        NoteEntry(
          path,
          isDirectory: document.isDir,
          modified: document.lastModified,
          size: document.length,
        ),
      );
    }
    return entries;
  });

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
  Future<void> delete(String path) => _saf(path, () async {
    await _util.delete(await _uri(path), false);
    _known.remove(p.posix.normalize(path));
  });

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
  String get id => 'saf-file:$fileUri';

  @override
  bool get persistent => true;

  @override
  String get location => fileName;

  void _check(String path) {
    if (path != fileName) {
      throw FileSystemException('Only $fileName was opened', path);
    }
  }

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

extension on String {
  String ifEmpty(String fallback) => isEmpty ? fallback : this;
}
