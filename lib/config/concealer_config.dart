import '../norg/ast.dart';

const _todoKeys = {
  'done': TodoStatus.done,
  'pending': TodoStatus.pending,
  'undone': TodoStatus.undone,
  'uncertain': TodoStatus.needsInput,
  'on_hold': TodoStatus.onHold,
  'cancelled': TodoStatus.cancelled,
  'recurring': TodoStatus.recurring,
  'urgent': TodoStatus.urgent,
};

class ConcealerConfig {
  const ConcealerConfig({
    this.headingIcons = const ['◉', '◎', '○', '✺', '▶', '⤷'],
    this.listIcons = const ['•'],
    this.orderedIcons = const ['1.', 'A.', 'a.', '(1)', 'I.', 'i.'],
    this.quoteIcons = const ['│'],
    this.todoIcons = const {
      TodoStatus.done: '\u{f012c}',
      TodoStatus.pending: '\u{f0954}',
      TodoStatus.undone: ' ',
      TodoStatus.needsInput: '\u{f420}',
      TodoStatus.onHold: '\u{f04c}',
      TodoStatus.cancelled: '\u{f1f8}',
      TodoStatus.recurring: '↺',
      TodoStatus.urgent: '⚠',
    },
    this.definitionSingle = '≡',
    this.definitionMultiPrefix = '⋙ ',
    this.definitionMultiSuffix = '⋘ ',
    this.footnoteSingle = '⁎',
    this.footnoteMultiPrefix = '⁑ ',
    this.footnoteMultiSuffix = '⁑ ',
    this.weakDelimiter = '⟨',
    this.strongDelimiter = '⟪',
    this.horizontalLine = '─',
    this.spoiler = '•',
    this.codeBlockConceal = false,
  });

  factory ConcealerConfig.fromNeorg(Map<String, Object?> config) {
    const defaults = ConcealerConfig();
    final icons = _map(config['icons']);
    String icon(List<String> path, String fallback) =>
        _at(icons, [...path, 'icon']) as String? ?? fallback;
    List<String> levels(String key, List<String> fallback) =>
        (_at(icons, [key, 'icons']) as List?)?.cast<String>() ?? fallback;

    return ConcealerConfig(
      headingIcons: levels('heading', defaults.headingIcons),
      listIcons: levels('list', defaults.listIcons),
      orderedIcons: levels('ordered', defaults.orderedIcons),
      quoteIcons: levels('quote', defaults.quoteIcons),
      todoIcons: {
        for (final MapEntry(key: key, value: status) in _todoKeys.entries)
          status: icon(['todo', key], defaults.todoIcons[status]!),
      },
      definitionSingle: icon([
        'definition',
        'single',
      ], defaults.definitionSingle),
      definitionMultiPrefix: icon([
        'definition',
        'multi_prefix',
      ], defaults.definitionMultiPrefix),
      definitionMultiSuffix: icon([
        'definition',
        'multi_suffix',
      ], defaults.definitionMultiSuffix),
      footnoteSingle: icon(['footnote', 'single'], defaults.footnoteSingle),
      footnoteMultiPrefix: icon([
        'footnote',
        'multi_prefix',
      ], defaults.footnoteMultiPrefix),
      footnoteMultiSuffix: icon([
        'footnote',
        'multi_suffix',
      ], defaults.footnoteMultiSuffix),
      weakDelimiter: icon(['delimiter', 'weak'], defaults.weakDelimiter),
      strongDelimiter: icon(['delimiter', 'strong'], defaults.strongDelimiter),
      horizontalLine: icon([
        'delimiter',
        'horizontal_line',
      ], defaults.horizontalLine),
      spoiler: icon(['markup', 'spoiler'], defaults.spoiler),
      codeBlockConceal:
          _at(icons, ['code_block', 'conceal']) as bool? ??
          defaults.codeBlockConceal,
    );
  }

  final List<String> headingIcons;
  final List<String> listIcons;
  final List<String> orderedIcons;
  final List<String> quoteIcons;
  final Map<TodoStatus, String> todoIcons;
  final String definitionSingle;
  final String definitionMultiPrefix;
  final String definitionMultiSuffix;
  final String footnoteSingle;
  final String footnoteMultiPrefix;
  final String footnoteMultiSuffix;
  final String weakDelimiter;
  final String strongDelimiter;
  final String horizontalLine;
  final String spoiler;
  final bool codeBlockConceal;
}

String iconForLevel(List<String> icons, int level) =>
    icons[(level < icons.length ? level : icons.length) - 1];

final _orderedPlaceholder = RegExp(r'(?<![\w])([01aAiI])(?![\w])');

String formatOrderedIcon(String pattern, int index) {
  final match = _orderedPlaceholder.firstMatch(pattern);
  if (match == null) return pattern;
  final number = switch (match[1]!) {
    '0' => '${index - 1}',
    '1' => '$index',
    'a' => _letters(index),
    'A' => _letters(index).toUpperCase(),
    'i' => _roman(index),
    _ => _roman(index).toUpperCase(),
  };
  return pattern.replaceRange(match.start, match.end, number);
}

String _letters(int index) {
  final letters = StringBuffer();
  for (var rest = index; rest > 0; rest = (rest - 1) ~/ 26) {
    letters.write(String.fromCharCode(97 + (rest - 1) % 26));
  }
  return letters.toString().split('').reversed.join();
}

const _romanNumerals = [
  (1000, 'm'),
  (900, 'cm'),
  (500, 'd'),
  (400, 'cd'),
  (100, 'c'),
  (90, 'xc'),
  (50, 'l'),
  (40, 'xl'),
  (10, 'x'),
  (9, 'ix'),
  (5, 'v'),
  (4, 'iv'),
  (1, 'i'),
];

String _roman(int index) {
  final numeral = StringBuffer();
  var rest = index;
  for (final (value, symbol) in _romanNumerals) {
    for (; rest >= value; rest -= value) {
      numeral.write(symbol);
    }
  }
  return numeral.toString();
}

Map<String, Object?> _map(Object? value) =>
    value is Map ? value.cast<String, Object?>() : const {};

Object? _at(Map<String, Object?> json, List<String> path) {
  Object? node = json;
  for (final key in path) {
    if (node is! Map) return null;
    node = node[key];
  }
  return node;
}
