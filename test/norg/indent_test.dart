import 'package:flutter_test/flutter_test.dart';
import 'package:morg/norg/indent.dart';

const messy = '''* Heading one
text at zero
- item at zero
continued at zero
        too far right
** (x) Sub heading
sub text
  - item
  -- nested
     @code lua
  print(1)
@end
---
back in one''';

// Indentation produced by neorg's core.esupports.indent for the same text.
const formatted = '''* Heading one
  text at zero
  - item at zero
    continued at zero
    too far right
** (x) Sub heading
   sub text
   - item
   -- nested
   @code lua
   print(1)
   @end
   ---
  back in one''';

void main() {
  test('reindents like neorg', () {
    expect(reindent(messy), formatted);
  });

  test('formatting is idempotent', () {
    expect(reindent(formatted), formatted);
  });

  test('without dedent_excess, lines too far right stay', () {
    expect(
      reindent(messy, dedentExcess: false).split('\n')[4],
      '        too far right',
    );
  });

  test('only the changed element is reindented', () {
    const before = '* A\ntext left alone\n* B\n  old';
    const after = '* A\ntext left alone\n* B\nnew';
    expect(reindentChanges(before, after), '* A\ntext left alone\n* B\n  new');
  });
}
