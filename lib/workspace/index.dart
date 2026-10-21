import 'dart:collection';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;

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

Future<List<String>> norgFiles(NoteStore store, [String directory = '']) async {
  final entries = await store.list(directory);
  return [
    for (final entry in entries)
      if (entry.name.startsWith('.') || entry.name.contains('.sync-conflict-'))
        ...const <String>[]
      else if (entry.isDirectory)
        ...await norgFiles(store, entry.path)
      else if (entry.name.endsWith('.norg'))
        entry.path,
  ]..sort();
}

Future<List<IndexedNote>> indexNotes(NoteStore store) async {
  final paths = await norgFiles(store);
  final sources = await Future.wait(paths.map(store.read));
  final parsed = await compute(_parseAll, sources);
  return [
    for (final (index, path) in paths.indexed)
      IndexedNote(NoteRef(store, path), sources[index], parsed[index]),
  ];
}

List<List<Block>> _parseAll(List<String> sources) => [
  for (final source in sources) parseNorg(source),
];

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
