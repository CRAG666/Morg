import 'dart:ui' show Brightness;

import 'package:flutter/painting.dart';

const _codeScopes = {
  'keyword': '@keyword',
  'built_in': '@function.builtin',
  'type': '@type',
  'literal': '@boolean',
  'number': '@number',
  'string': '@string',
  'char.escape': '@string.escape',
  'regexp': '@string.regexp',
  'symbol': '@string.special.symbol',
  'link': '@string.special.url',
  'comment': '@comment',
  'doctag': '@comment.documentation',
  'title': '@function',
  'title.function': '@function',
  'title.function.invoke': '@function.call',
  'title.class': '@type',
  'title.class.inherited': '@type',
  'function': '@function',
  'class': '@type',
  'params': '@variable.parameter',
  'variable': '@variable',
  'variable.language': '@variable.builtin',
  'variable.constant': '@constant',
  'template-variable': '@variable',
  'subst': '@variable',
  'attr': '@property',
  'property': '@property',
  'attribute': '@attribute',
  'meta': '@keyword.directive',
  'operator': '@operator',
  'punctuation': '@punctuation.delimiter',
  'bullet': '@punctuation',
  'section': '@markup.heading',
  'tag': '@tag',
  'name': '@tag',
  'selector-tag': '@tag',
};

class NorgHighlight {
  const NorgHighlight({
    this.foreground,
    this.background,
    this.bold = false,
    this.italic = false,
    this.underline = false,
    this.strikethrough = false,
  });

  factory NorgHighlight.fromJson(Map<String, Object?> json) => NorgHighlight(
    foreground: _color(json['fg']),
    background: _color(json['bg']),
    bold: json['bold'] == true,
    italic: json['italic'] == true,
    underline: json['underline'] == true,
    strikethrough: json['strikethrough'] == true,
  );

  final Color? foreground;
  final Color? background;
  final bool bold;
  final bool italic;
  final bool underline;
  final bool strikethrough;

  TextStyle apply(TextStyle base) => base.copyWith(
    color: foreground,
    backgroundColor: background,
    fontWeight: bold ? FontWeight.bold : null,
    fontStyle: italic ? FontStyle.italic : null,
    decoration: underline || strikethrough
        ? TextDecoration.combine([
            ?base.decoration,
            if (underline) TextDecoration.underline,
            if (strikethrough) TextDecoration.lineThrough,
          ])
        : null,
  );
}

class NorgTheme {
  NorgTheme(this.groups);

  factory NorgTheme.fromJson(Map<String, Object?> json) => NorgTheme({
    for (final MapEntry(:key, :value) in json.entries)
      key: NorgHighlight.fromJson((value as Map).cast()),
  });

  final Map<String, NorgHighlight> groups;
  final _resolved = <String, NorgHighlight>{};

  Color get foreground => this['Normal'].foreground!;

  Color get background => this['Normal'].background!;

  bool defines(String group) =>
      groups.containsKey('$group.norg') || groups.containsKey(group);

  NorgHighlight operator [](String group) =>
      _resolved[group] ??= _resolve(group);

  NorgHighlight _resolve(String group) {
    for (var name = group; name.isNotEmpty;) {
      if (groups['$name.norg'] ?? groups[name] case final highlight?) {
        return highlight;
      }
      final dot = name.lastIndexOf('.');
      name = dot > 0 ? name.substring(0, dot) : '';
    }
    return const NorgHighlight();
  }

  Map<String, TextStyle> codeTheme(TextStyle base) => {
    for (final MapEntry(key: scope, value: group) in _codeScopes.entries)
      scope: this[group].apply(base),
  };
}

class NorgThemeFamily {
  const NorgThemeFamily({
    required this.name,
    required this.dark,
    required this.light,
  });

  factory NorgThemeFamily.fromJson(Map<String, Object?> json) {
    final variants = (json['variants'] as Map).cast<String, Object?>();
    NorgTheme variant(String name) =>
        NorgTheme.fromJson((variants[name] as Map).cast());
    return NorgThemeFamily(
      name: json['name'] as String,
      dark: variant('dark'),
      light: variant('light'),
    );
  }

  final String name;
  final NorgTheme dark;
  final NorgTheme light;

  NorgTheme of(Brightness brightness) =>
      brightness == Brightness.dark ? dark : light;
}

Color? _color(Object? hex) => hex is String
    ? Color(0xFF000000 | int.parse(hex.substring(1), radix: 16))
    : null;
