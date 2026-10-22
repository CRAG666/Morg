import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart' show Locale, ThemeMode;
import 'package:flutter/widgets.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'config/concealer_config.dart';
import 'l10n/app_localizations.dart';
import 'theme/norg_theme.dart';

const defaultConfigAsset = 'assets/config/morg.json';
const _bundledThemes = ['eyes'];

class MorgConfig {
  const MorgConfig({
    required this.source,
    required this.themeName,
    required this.themeMode,
    required this.locale,
    required this.concealer,
    required this.workspaces,
    required this.defaultWorkspace,
    required this.indexFile,
    required this.author,
    required this.journalFolder,
    required this.journalStrategy,
    required this.journalTemplate,
    required this.useJournalTemplate,
    required this.formatOnEdit,
    required this.dedentExcess,
  });

  factory MorgConfig.parse(String source) {
    final Object? json;
    try {
      json = jsonDecode(source);
    } on FormatException catch (error) {
      throw FormatException('Invalid JSON: ${error.message}', source);
    }
    if (json is! Map<String, Object?>) {
      throw const FormatException('The configuration must be a JSON object');
    }
    final modules = _object(json['load'], 'load');
    Map<String, Object?> module(String name) =>
        _object(_object(modules[name], name)['config'], '$name.config');
    final dirman = module('core.dirman');
    final workspaces = _object(dirman['workspaces'], 'workspaces');
    final journal = module('core.journal');
    final indent = module('core.esupports.indent');
    String? text(Map<String, Object?> map, String key) =>
        _optional<String>(map, key);
    bool flag(Map<String, Object?> map, String key) =>
        _optional<bool>(map, key) ?? true;
    final strategy = text(journal, 'strategy') ?? 'nested';
    final author = text(module('core.esupports.metagen'), 'author') ?? '';
    return MorgConfig(
      source: source,
      themeName: text(json, 'theme') ?? 'eyes',
      themeMode: switch (json['theme_mode']) {
        null || 'system' => ThemeMode.system,
        'light' => ThemeMode.light,
        'dark' => ThemeMode.dark,
        final other => throw FormatException('Unknown theme_mode: $other'),
      },
      locale: switch (json['language']) {
        null || 'system' => null,
        final String code when supportedLanguages.contains(code) => Locale(
          code,
        ),
        final other => throw FormatException('Unsupported language: $other'),
      },
      concealer: ConcealerConfig.fromNeorg(module('core.concealer')),
      workspaces: {
        for (final MapEntry(:key, :value) in workspaces.entries)
          key: value is String
              ? value
              : throw FormatException(
                  'The path of workspace "$key" must be a string',
                ),
      },
      defaultWorkspace: text(dirman, 'default_workspace'),
      indexFile: text(dirman, 'index') ?? 'index.norg',
      author: author.isNotEmpty
          ? author
          : kIsWeb
          ? 'morg'
          : Platform.environment['USER'] ?? 'morg',
      journalFolder: text(journal, 'journal_folder') ?? 'journal',
      journalStrategy: switch (strategy) {
        'nested' => JournalStrategy.nested,
        'flat' => JournalStrategy.flat,
        _ => throw FormatException('Unsupported journal strategy: $strategy'),
      },
      journalTemplate: text(journal, 'template_name') ?? 'template.norg',
      useJournalTemplate: flag(journal, 'use_template'),
      formatOnEdit: flag(indent, 'format_on_escape'),
      dedentExcess: flag(indent, 'dedent_excess'),
    );
  }

  final String source;
  final String themeName;
  final ThemeMode themeMode;
  final Locale? locale;
  final ConcealerConfig concealer;
  final Map<String, String> workspaces;
  final String? defaultWorkspace;
  final String indexFile;
  final String author;
  final String journalFolder;
  final JournalStrategy journalStrategy;
  final String journalTemplate;
  final bool useJournalTemplate;
  final bool formatOnEdit;
  final bool dedentExcess;
}

enum JournalStrategy { nested, flat }

class MorgSettings {
  const MorgSettings({required this.config, required this.theme});

  final MorgConfig config;
  final NorgThemeFamily theme;

  ConcealerConfig get concealer => config.concealer;
}

class SettingsStore {
  SettingsStore({required this.directory, required this.bundle});

  final Directory? directory;
  final AssetBundle bundle;

  static Future<SettingsStore> open(AssetBundle bundle) async => SettingsStore(
    directory: kIsWeb ? null : await getApplicationSupportDirectory(),
    bundle: bundle,
  );

  File? get _configFile =>
      directory == null ? null : File(p.join(directory!.path, 'morg.json'));

  Directory? get _themesDirectory =>
      directory == null ? null : Directory(p.join(directory!.path, 'themes'));

  Future<String> defaultConfig() => bundle.loadString(defaultConfigAsset);

  Future<MorgSettings> load() async {
    final file = _configFile;
    final source = file != null && await file.exists()
        ? await file.readAsString()
        : await defaultConfig();
    return _settings(MorgConfig.parse(source));
  }

  Future<MorgSettings> save(String source) async {
    final settings = await _settings(MorgConfig.parse(source));
    if (_configFile case final file?) {
      await file.parent.create(recursive: true);
      await file.writeAsString(source);
    }
    return settings;
  }

  Future<List<String>> themeNames() async {
    final imported = _themesDirectory;
    return {
      ..._bundledThemes,
      if (imported != null && await imported.exists())
        for (final entity in imported.listSync())
          if (entity.path.endsWith('.json'))
            p.basenameWithoutExtension(entity.path),
    }.toList()..sort();
  }

  Future<String> importTheme(String source) async {
    final theme = NorgThemeFamily.fromJson(jsonDecode(source));
    final themes = _themesDirectory;
    if (themes == null) {
      throw UnsupportedError('No storage on this platform');
    }
    await themes.create(recursive: true);
    await File(p.join(themes.path, '${theme.name}.json')).writeAsString(source);
    return theme.name;
  }

  Future<MorgSettings> _settings(MorgConfig config) async => MorgSettings(
    config: config,
    theme: NorgThemeFamily.fromJson(
      jsonDecode(await _themeSource(config.themeName)),
    ),
  );

  Future<String> _themeSource(String name) async {
    final themes = _themesDirectory;
    final imported = themes == null
        ? null
        : File(p.join(themes.path, '$name.json'));
    if (imported != null && await imported.exists()) {
      return imported.readAsString();
    }
    if (_bundledThemes.contains(name)) {
      return bundle.loadString('assets/themes/$name.json');
    }
    throw FormatException('Theme "$name" does not exist');
  }
}

class SettingsController extends ValueNotifier<MorgSettings> {
  SettingsController(this.store, super.value);

  final SettingsStore store;

  Future<void> save(String source) async => value = await store.save(source);

  Future<void> reset() async => save(await store.defaultConfig());

  Object? valueAt(List<String> path) {
    Object? node = jsonDecode(value.config.source);
    for (final key in path) {
      if (node is! Map) return null;
      node = node[key];
    }
    return node;
  }

  Future<void> edit(void Function(Map<String, Object?> json) change) async {
    final json = jsonDecode(value.config.source) as Map<String, Object?>;
    change(json);
    await save(const JsonEncoder.withIndent('  ').convert(json));
  }

  Future<void> setValue(List<String> path, Object? newValue) => edit((json) {
    final node = _at(json, path.sublist(0, path.length - 1));
    if (newValue == null) {
      node.remove(path.last);
    } else {
      node[path.last] = newValue;
    }
  });

  Future<void> setWorkspace(String name, String? location) =>
      setValue([..._dirman, 'workspaces', name], location);

  Future<void> renameWorkspace(String from, String to) => edit((json) {
    final dirman = _at(json, _dirman);
    final workspaces = dirman['workspaces'] as Map<String, Object?>;
    workspaces[to] = workspaces.remove(from);
    if (dirman['default_workspace'] == from) dirman['default_workspace'] = to;
  });

  Future<String> importTheme(String source) => store.importTheme(source);
}

class MorgSettingsScope extends InheritedNotifier<SettingsController> {
  const MorgSettingsScope({
    super.key,
    required SettingsController controller,
    required super.child,
  }) : super(notifier: controller);

  static SettingsController controllerOf(BuildContext context) => context
      .dependOnInheritedWidgetOfExactType<MorgSettingsScope>()!
      .notifier!;

  static MorgSettings of(BuildContext context) => controllerOf(context).value;
}

final supportedLanguages = {
  for (final locale in AppLocalizations.supportedLocales) locale.languageCode,
};

const _dirman = ['load', 'core.dirman', 'config'];

Map<String, Object?> _at(Map<String, Object?> json, List<String> path) {
  var node = json;
  for (final key in path) {
    node = (node[key] ??= <String, Object?>{}) as Map<String, Object?>;
  }
  return node;
}

Map<String, Object?> _object(Object? value, String name) => switch (value) {
  null => const {},
  Map<String, Object?>() => value,
  _ => throw FormatException('"$name" must be an object'),
};

T? _optional<T>(Map<String, Object?> map, String key) => switch (map[key]) {
  null => null,
  final T value => value,
  final other => throw FormatException(
    '"$key" must be a ${T == bool ? 'boolean' : 'string'}, not $other',
  ),
};
