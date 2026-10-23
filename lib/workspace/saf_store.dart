import 'dart:io';

import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:pool/pool.dart';
import 'package:saf_stream/saf_stream.dart';
import 'package:saf_util/saf_util.dart';

import 'store.dart';

const _norgMime = 'application/octet-stream';
const _providers = {'com.google.android.apps.docs.storage': 'Google Drive'};

class SafStore implements NoteFolder {
  SafStore(this.treeUri);

  static final _documents = <String, Map<String, String>>{};
  static final _labels = <String, Future<String>>{};
  static final _creating = Pool(1);

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

  String _key(List<String> segments) => p.posix.joinAll(segments);

  Future<List<NoteEntry>> _listing(String directory, String uri) async {
    final newest = <String, NoteEntry>{};
    for (final document in await _util.list(uri)) {
      final path = p.posix.normalize(p.posix.join(directory, document.name));
      if ((newest[path]?.modified ?? -1) > document.lastModified) continue;
      _known[path] = document.uri;
      newest[path] = NoteEntry(
        path,
        isDirectory: document.isDir,
        modified: document.lastModified,
        size: document.length,
      );
    }
    return newest.values.toList();
  }

  Future<String?> _find(List<String> segments) async {
    if (segments.isEmpty) return treeUri;
    if (_known[_key(segments)] case final uri?) return uri;
    final parents = segments.sublist(0, segments.length - 1);
    final parent = await _find(parents);
    if (parent == null) return null;
    await _listing(_key(parents), parent);
    return _known[_key(segments)];
  }

  Future<String> _uri(String path) async =>
      await _find(_segments(path)) ??
      (throw FileSystemException('Not found in the cloud folder', path));

  Future<void> _createFile(List<String> segments, Uint8List bytes) async {
    final parents = segments.sublist(0, segments.length - 1);
    var directory = treeUri;
    var depth = 0;
    while (depth < parents.length) {
      final known = _known[_key(parents.sublist(0, depth + 1))];
      if (known == null) break;
      directory = known;
      depth++;
    }
    if (depth < parents.length) {
      directory = (await _util.mkdirp(directory, parents.sublist(depth))).uri;
      _known[_key(parents)] = directory;
    }
    final file = await _stream.writeFileBytes(
      directory,
      segments.last,
      _norgMime,
      bytes,
    );
    _known[_key(segments)] = file.uri.toString();
  }

  @override
  Future<List<NoteEntry>> list(String directory) =>
      _saf(directory, () async => _listing(directory, await _uri(directory)));

  @override
  Future<bool> exists(String path) =>
      _saf(path, () async => await _find(_segments(path)) != null);

  @override
  Future<Uint8List> readBytes(String path) =>
      _saf(path, () async => _stream.readFileBytes(await _uri(path)));

  @override
  Future<void> writeBytes(String path, Uint8List bytes) => _saf(path, () async {
    final segments = _segments(path);
    if (_known[_key(segments)] case final uri?) {
      await _stream.writeFileUriBytes(uri, bytes);
      return;
    }
    await _creating.withResource(() async {
      if (await _find(segments) case final uri?) {
        await _stream.writeFileUriBytes(uri, bytes);
      } else {
        await _createFile(segments, bytes);
      }
    });
  });

  @override
  Future<bool> create(String path, Uint8List bytes) => _saf(
    path,
    () => _creating.withResource(() async {
      final segments = _segments(path);
      if (await _find(segments) != null) return false;
      await _createFile(segments, bytes);
      return true;
    }),
  );

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
  Future<bool> create(String path, Uint8List bytes) async {
    _check(path);
    return false;
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
  } on FileSystemException {
    rethrow;
  } on PlatformException catch (error) {
    throw FileSystemException(error.message ?? error.code, path);
  } on Exception catch (error) {
    throw FileSystemException('$error', path);
  }
}

extension on String {
  String ifEmpty(String fallback) => isEmpty ? fallback : this;
}
