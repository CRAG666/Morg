import 'package:flutter_test/flutter_test.dart';
import 'package:morg/norg/markdown.dart';
import 'package:morg/norg/parser.dart';

String markdown(String source) => toMarkdown(source, parseNorg(source));

void main() {
  test('metadata becomes front matter', () {
    expect(
      markdown('@document.meta\ntitle: Demo\n@end\n'),
      startsWith('---\ntitle: Demo\n---'),
    );
  });

  test('headings, tasks and ordered lists', () {
    expect(
      markdown('* Plan\n  - (x) done\n  - ( ) todo\n  ~ first'),
      '# Plan\n\n- [x] done\n- [ ] todo\n1. first\n',
    );
  });

  test('links point to headings, files and URLs', () {
    final text = markdown(
      '{* My Heading}[here], {:other:}[file] and {https://x.org}[web]',
    );
    expect(text, contains('[here](#my-heading)'));
    expect(text, contains('[file](other.md)'));
    expect(text, contains('[web](https://x.org)'));
  });

  test('code keeps its language', () {
    expect(
      markdown('@code dart\nmain() {}\n@end'),
      '```dart\nmain() {}\n```\n',
    );
  });
}
