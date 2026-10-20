import 'dart:io';

import 'package:path/path.dart' as p;

final _envVariable = RegExp(r'\$([A-Za-z0-9_]+)');
final _lineSuffix = RegExp(r'^(.*):(\d+)$');
final _linkLocation = RegExp(r'^(\*{1,6}|#|\$|\^|\?|/|@|=)\s+(.+)$');

class Workspace {
  const Workspace(this.name, this.root);

  final String name;
  final Directory root;
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
          key: Workspace(key, Directory(expandPath(value, home: home))),
      };

  final String home;
  final Map<String, Workspace> all;

  Workspace? containing(String file) {
    Workspace? best;
    for (final workspace in all.values) {
      final root = workspace.root.path;
      final inside = p.equals(root, file) || p.isWithin(root, file);
      if (inside && (best == null || root.length > best.root.path.length)) {
        best = workspace;
      }
    }
    return best;
  }

  LinkTarget resolve(String target, {required File? from}) {
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

  LinkTarget _norgFile(String target, File? from) {
    final close = target.indexOf(':', 1);
    if (close < 0) return UnsupportedTarget(target);
    final location = target.substring(close + 1).trim();
    final path = _norgPath(target.substring(1, close), from);
    if (path == null) return UnsupportedTarget(target);
    return NorgFileTarget(
      File(path.endsWith('.norg') ? path : '$path.norg'),
      location.isEmpty ? null : location,
    );
  }

  String? _norgPath(String path, File? from) {
    if (path.startsWith(r'$')) {
      final slash = path.indexOf('/');
      if (slash < 0) return null;
      final name = path.substring(1, slash);
      final workspace = name.isEmpty
          ? (from == null ? null : containing(from.path))
          : all[name];
      return workspace == null
          ? null
          : p.join(workspace.root.path, path.substring(slash + 1));
    }
    if (path.startsWith('~') || p.isAbsolute(path)) {
      return expandPath(path, home: home);
    }
    return from == null ? null : p.normalize(p.join(from.parent.path, path));
  }

  LinkTarget _externalFile(String target, File? from) {
    final match = _lineSuffix.firstMatch(target);
    final raw = (match?[1] ?? target).trim();
    final path = raw.startsWith('/') || raw.startsWith('~')
        ? expandPath(raw, home: home)
        : from == null
        ? null
        : p.normalize(p.join(from.parent.path, raw));
    if (path == null) return UnsupportedTarget(target);
    return p.extension(path) == '.norg'
        ? NorgFileTarget(File(path), match?[2])
        : ExternalFileTarget(File(path));
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
  const NorgFileTarget(this.file, this.location);
  final File file;
  final String? location;
}

class ExternalFileTarget extends LinkTarget {
  const ExternalFileTarget(this.file);
  final File file;
}

class LocalTarget extends LinkTarget {
  const LocalTarget(this.location);
  final String location;
}

class UnsupportedTarget extends LinkTarget {
  const UnsupportedTarget(this.target);
  final String target;
}
