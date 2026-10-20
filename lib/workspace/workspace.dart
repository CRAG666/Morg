import 'dart:io';

import 'package:path/path.dart' as p;

import 'store.dart';

final _envVariable = RegExp(r'\$([A-Za-z0-9_]+)');
final _lineSuffix = RegExp(r'^(.*):(\d+)$');
final _linkLocation = RegExp(r'^(\*{1,6}|#|\$|\^|\?|/|@|=)\s+(.+)$');

bool isContentUri(String path) => path.startsWith('content://');

String? localPathForTree(String treeUri) {
  final uri = Uri.parse(treeUri);
  final segments = uri.pathSegments;
  if (uri.authority != 'com.android.externalstorage.documents' ||
      segments.length < 2 ||
      segments.first != 'tree') {
    return null;
  }
  final [volume, ...path] = segments[1].split(':');
  final root = volume == 'primary' ? '/storage/emulated/0' : '/storage/$volume';
  return p.join(root, path.join(':'));
}

class Workspace {
  const Workspace(this.name, this.store);

  final String name;
  final NoteStore store;
}

String userHome() => Platform.isAndroid
    ? '/storage/emulated/0'
    : Platform.environment['HOME'] ?? Directory.current.path;

String expandPath(String path, {required String home}) {
  final withHome = path == '~' || path.startsWith('~/')
      ? home + path.substring(1)
      : path;
  return p.normalize(
    withHome.replaceAllMapped(
      _envVariable,
      (match) => Platform.environment[match[1]] ?? match[0]!,
    ),
  );
}

class Workspaces {
  Workspaces(Map<String, String> config, {required this.home})
    : all = {
        for (final MapEntry(:key, :value) in config.entries)
          key: Workspace(
            key,
            isContentUri(value)
                ? SafStore(value)
                : LocalStore(Directory(expandPath(value, home: home))),
          ),
      };

  final String home;
  final Map<String, Workspace> all;

  NoteRef local(String absolutePath) {
    NoteRef? best;
    for (final Workspace(:store) in all.values) {
      if (store is! LocalStore) continue;
      final root = store.root.path;
      final inside =
          p.equals(root, absolutePath) || p.isWithin(root, absolutePath);
      final isLonger =
          best == null ||
          root.length > (best.store as LocalStore).root.path.length;
      if (inside && isLonger) {
        best = NoteRef(store, p.relative(absolutePath, from: root));
      }
    }
    return best ??
        NoteRef(
          LocalStore(Directory(p.separator)),
          p.relative(absolutePath, from: p.separator),
        );
  }

  LinkTarget resolve(String target, {required NoteRef? from}) {
    if (target.startsWith(':')) return _norgFile(target, from);
    if (target.startsWith('/ ')) {
      return _externalFile(target.substring(2), from);
    }
    if (Uri.tryParse(target) case final uri? when uri.hasScheme) {
      return UrlTarget(uri);
    }
    if (_linkLocation.hasMatch(target)) return LocalTarget(target);
    return UnsupportedTarget(target);
  }

  NoteRef? resolvePath(String path, {required NoteRef? from}) {
    if (path.startsWith(r'$')) {
      final slash = path.indexOf('/');
      if (slash < 0) return null;
      final name = path.substring(1, slash);
      final store = name.isEmpty ? from?.store : all[name]?.store;
      final rest = p.posix.normalize(path.substring(slash + 1));
      return store == null ? null : NoteRef(store, rest);
    }
    if (path.startsWith('~') || p.isAbsolute(path)) {
      return local(expandPath(path, home: home));
    }
    if (from == null) return null;
    final joined = p.posix.normalize(p.posix.join(from.directory, path));
    if (!joined.startsWith('..')) return NoteRef(from.store, joined);
    return switch (from.store) {
      LocalStore(:final root) => local(p.normalize(p.join(root.path, joined))),
      _ => null,
    };
  }

  LinkTarget _norgFile(String target, NoteRef? from) {
    final close = target.indexOf(':', 1);
    if (close < 0) return UnsupportedTarget(target);
    final location = target.substring(close + 1).trim();
    final ref = resolvePath(target.substring(1, close), from: from);
    if (ref == null) return UnsupportedTarget(target);
    return NorgFileTarget(
      ref.path.endsWith('.norg') ? ref : NoteRef(ref.store, '${ref.path}.norg'),
      location.isEmpty ? null : location,
    );
  }

  LinkTarget _externalFile(String target, NoteRef? from) {
    final match = _lineSuffix.firstMatch(target);
    final ref = resolvePath((match?[1] ?? target).trim(), from: from);
    if (ref == null) return UnsupportedTarget(target);
    return p.extension(ref.path) == '.norg'
        ? NorgFileTarget(ref, match?[2])
        : ExternalFileTarget(ref);
  }
}

sealed class LinkTarget {
  const LinkTarget();
}

class UrlTarget extends LinkTarget {
  const UrlTarget(this.uri);
  final Uri uri;
}

class NorgFileTarget extends LinkTarget {
  const NorgFileTarget(this.ref, this.location);
  final NoteRef ref;
  final String? location;
}

class ExternalFileTarget extends LinkTarget {
  const ExternalFileTarget(this.ref);
  final NoteRef ref;
}

class LocalTarget extends LinkTarget {
  const LocalTarget(this.location);
  final String location;
}

class UnsupportedTarget extends LinkTarget {
  const UnsupportedTarget(this.target);
  final String target;
}
