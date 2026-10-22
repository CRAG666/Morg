import 'dart:collection';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:pool/pool.dart';

import '../norg/ast.dart';
import '../norg/parser.dart';
import '../norg/structure.dart';
import '../norg/targets.dart';
import 'store.dart';

class IndexedNote {
  IndexedNote(this.ref, this.source, this.blocks);

  final NoteRef ref;
  final String source;
  final List<Block> blocks;

  late final List<String> lines = source.split('\n');

  late final List<TaskEntry> tasks = tasksOf(blocks).toList();

  late final Map<String, String> meta =
      blocks.whereType<DocumentMeta>().firstOrNull?.fields ?? const {};

  late final String title = switch (meta['title']) {
    final title? when title.isNotEmpty => title,
    _ => switch (headingsOf(blocks).firstOrNull) {
      final heading? => plainText(heading.title),
      null => ref.name,
    },
  };

  List<String> get categories {
    final value = meta['categories']?.trim() ?? '';
    if (value.isEmpty) return const [];
    final inline = value.startsWith('[') && value.endsWith(']');
    return (inline
            ? value.substring(1, value.length - 1).split(RegExp(r'[\s,]+'))
            : value.split(', '))
        .where((category) => category.isNotEmpty)
        .toList();
  }
}

const _concurrency = 8;
const _publishEvery = 24;
const _cacheVersion = 1;

typedef _Stamp = (int? modified, int? size);
typedef _Cached = (String path, int? modified, int? size, String source);

bool _ignored(NoteEntry entry) =>
    entry.name.startsWith('.') || entry.name.contains('.sync-conflict-');

Future<List<NoteEntry>> _norgEntries(
  NoteStore store,
  Pool pool, [
  String directory = '',
]) async {
  final entries = await pool.withResource(() => store.list(directory));
  final nested = await Future.wait([
    for (final entry in entries)
      if (entry.isDirectory && !_ignored(entry))
        _norgEntries(store, pool, entry.path),
  ]);
  return [
    for (final entry in entries)
      if (!entry.isDirectory &&
          !_ignored(entry) &&
          entry.name.endsWith('.norg'))
        entry,
    for (final list in nested) ...list,
  ];
}

class WorkspaceIndex {
  WorkspaceIndex._(this.store);

  factory WorkspaceIndex.of(NoteStore store) =>
      _indexes.putIfAbsent(store.id, () => WorkspaceIndex._(store));

  static WorkspaceIndex? peek(NoteStore store) => _indexes[store.id];

  static final _indexes = <String, WorkspaceIndex>{};

  final NoteStore store;
  final notes = ValueNotifier<List<IndexedNote>?>(null);
  final refreshing = ValueNotifier(false);
  final _byPath = SplayTreeMap<String, IndexedNote>();
  final _stamps = <String, _Stamp>{};
  Future<void>? _loaded;
  Future<void>? _scanning;
  final _touched = <String>{};

  Future<void> load() => _loaded ??= _loadCache();

  Future<void> refresh() async {
    await load();
    return _scanning ??= _scan().whenComplete(() => _scanning = null);
  }

  void updated(String path, String source) {
    if (notes.value == null) return;
    _byPath[path] = IndexedNote(
      NoteRef(store, path),
      source,
      parseNorg(source),
    );
    _stamps.remove(path);
    _touched.add(path);
    _publish();
  }

  void removed(String path) {
    _touched.add(path);
    if (_byPath.remove(path) == null) return;
    _stamps.remove(path);
    _publish();
  }

  void _publish() => notes.value = List.unmodifiable(_byPath.values);

  void _add(_Cached note, List<Block> blocks) {
    final (path, modified, size, source) = note;
    _byPath[path] = IndexedNote(NoteRef(store, path), source, blocks);
    _stamps[path] = (modified, size);
  }

  Future<void> _scan() async {
    refreshing.value = true;
    final pool = Pool(_concurrency);
    try {
      final entries = await _norgEntries(store, pool);
      final present = {for (final entry in entries) entry.path};
      final gone = [
        for (final path in _byPath.keys)
          if (!present.contains(path) && !_touched.contains(path)) path,
      ];
      for (final path in gone) {
        _byPath.remove(path);
        _stamps.remove(path);
      }
      final changed = [
        for (final entry in entries)
          if (entry.modified == null ||
              _stamps[entry.path] != (entry.modified, entry.size))
            entry,
      ];
      for (var start = 0; start < changed.length; start += _publishEvery) {
        final group = changed.sublist(
          start,
          min(start + _publishEvery, changed.length),
        );
        final sources = await Future.wait([
          for (final entry in group)
            pool.withResource(() => store.read(entry.path)),
        ]);
        final parsed = await compute(_parseAll, sources);
        for (final (index, entry) in group.indexed) {
          if (_touched.contains(entry.path)) continue;
          _add((
            entry.path,
            entry.modified,
            entry.size,
            sources[index],
          ), parsed[index]);
        }
        _publish();
      }
      _publish();
      if (changed.isNotEmpty || gone.isNotEmpty) await _saveCache();
    } finally {
      _touched.clear();
      refreshing.value = false;
      await pool.close();
    }
  }

  Future<File?> _cacheFile() async {
    if (kIsWeb || store is MemoryStore) return null;
    final directory = await getApplicationSupportDirectory();
    final name = sha1.convert(utf8.encode(store.id));
    return File(p.join(directory.path, 'index', '$name.json'));
  }

  Future<void> _loadCache() async {
    final file = await _cacheFile();
    if (file == null || !await file.exists()) return;
    final cached = await compute(_decodeCache, await file.readAsString());
    if (cached == null) {
      await file.delete();
      return;
    }
    for (final (note, blocks) in cached) {
      _add(note, blocks);
    }
    _publish();
  }

  Future<void> _saveCache() async {
    final file = await _cacheFile();
    if (file == null) return;
    await compute(_writeCache, (
      file.path,
      [
        for (final note in _byPath.values)
          if (_stamps[note.ref.path] case (final modified, final size))
            (note.ref.path, modified, size, note.source),
      ],
    ));
  }
}

List<List<Block>> _parseAll(List<String> sources) => [
  for (final source in sources) parseNorg(source),
];

List<(_Cached, List<Block>)>? _decodeCache(String json) {
  final Object? decoded;
  try {
    decoded = jsonDecode(json);
  } on FormatException {
    return null;
  }
  if (decoded case {
    'version': _cacheVersion,
    'notes': final List<Object?> notes,
  }) {
    final cached = <(_Cached, List<Block>)>[];
    for (final note in notes) {
      if (note case [
        final String path,
        final int? modified,
        final int? size,
        final String source,
      ]) {
        cached.add(((path, modified, size, source), parseNorg(source)));
      } else {
        return null;
      }
    }
    return cached;
  }
  return null;
}

void _writeCache((String, List<_Cached>) cache) {
  final (path, notes) = cache;
  final file = File('$path.tmp')..parent.createSync(recursive: true);
  file.writeAsStringSync(
    jsonEncode({
      'version': _cacheVersion,
      'notes': [
        for (final (path, modified, size, source) in notes)
          [path, modified, size, source],
      ],
    }),
  );
  file.renameSync(path);
}

class _Category {
  final notes = <IndexedNote>[];
  final children = SplayTreeMap<String, _Category>();
}

String _capitalized(String text) =>
    text.isEmpty ? text : text[0].toUpperCase() + text.substring(1);

String workspaceSummary(
  List<IndexedNote> notes, {
  required String uncategorized,
}) {
  final root = _Category();
  for (final note in notes) {
    final categories = note.categories;
    for (final category in categories.isEmpty ? [uncategorized] : categories) {
      var node = root;
      for (final part in category.split('.')) {
        node = node.children.putIfAbsent(_capitalized(part), _Category.new);
      }
      node.notes.add(note);
    }
  }
  final lines = <String>[];
  void write(_Category category, int depth) {
    for (final MapEntry(key: name, value: child) in category.children.entries) {
      lines.add('${'*' * (depth + 1)} $name');
      for (final note in child.notes) {
        final path = p.posix.withoutExtension(note.ref.path);
        final description = note.meta['description'] ?? '';
        lines.add(
          '${' ' * (depth + 1)} - {:\$/$path:}[${_capitalized(note.title)}]'
          '${description.isEmpty ? '' : ' - $description'}',
        );
      }
      write(child, depth + 1);
    }
  }

  write(root, 0);
  return lines.join('\n');
}
