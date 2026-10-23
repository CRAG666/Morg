import 'dart:typed_data';

import 'store.dart';

abstract class _WebUnsupportedStore implements NoteStore {
  @override
  bool get persistent => true;

  Never _unsupported() =>
      throw UnsupportedError('Cloud folders are only available on Android');

  @override
  Future<bool> exists(String path) => _unsupported();

  @override
  Future<Uint8List> readBytes(String path) => _unsupported();

  @override
  Future<void> writeBytes(String path, Uint8List bytes) => _unsupported();

  @override
  Future<bool> create(String path, Uint8List bytes) => _unsupported();

  @override
  Future<void> delete(String path) => _unsupported();

  @override
  Future<void> openExternally(String path) => _unsupported();
}

class SafStore extends _WebUnsupportedStore implements NoteFolder {
  SafStore(this.treeUri);

  final String treeUri;

  @override
  String get id => 'saf:$treeUri';

  @override
  String get location => treeUri;

  @override
  bool get remote => true;

  @override
  bool get missing => false;

  @override
  Future<String> label() => _unsupported();

  @override
  Future<bool> isReachable() => _unsupported();

  @override
  Future<void> release() => _unsupported();

  @override
  Future<List<NoteEntry>> list(String directory) => _unsupported();
}

class SafFileStore extends _WebUnsupportedStore {
  SafFileStore(this.fileUri, this.fileName);

  final String fileUri;
  final String fileName;

  @override
  String get id => 'saf-file:$fileUri';

  @override
  String get location => fileName;
}
