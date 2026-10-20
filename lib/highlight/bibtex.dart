import 'package:re_highlight/re_highlight.dart';

final _braced = Mode(
  begin: r'\{',
  end: r'\}',
  contains: [Mode(begin: r'\{', end: r'\}')],
);

final langBibtex = Mode(
  name: 'BibTeX',
  aliases: ['bib'],
  contains: [
    Mode(scope: 'comment', begin: '%', end: r'$'),
    Mode(scope: 'keyword', begin: r'@[A-Za-z]+'),
    Mode(scope: 'title', begin: r'(?<=@[A-Za-z]+\{)[^,\s]+'),
    Mode(scope: 'attr', begin: r'[A-Za-z_-]+(?=\s*=)'),
    Mode(
      scope: 'string',
      begin: r'(?<==\s*)\{',
      end: r'\}',
      contains: [_braced],
    ),
    Mode(scope: 'string', begin: '"', end: '"'),
    Mode(scope: 'number', begin: r'\b\d+\b'),
  ],
);
