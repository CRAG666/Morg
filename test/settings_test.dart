import 'package:flutter_test/flutter_test.dart';
import 'package:morg/settings.dart';
import 'package:morg/theme/norg_theme.dart';

void main() {
  test('defaults apply when keys are missing', () {
    final config = MorgConfig.parse('{"load": {}}');
    expect(config.journalStrategy, JournalStrategy.nested);
    expect(config.indexFile, 'index.norg');
    expect(config.formatOnEdit, isTrue);
  });

  test('wrong types are reported with the key', () {
    expect(
      () => MorgConfig.parse(
        '{"load":{"core.journal":{"config":{"strategy":5}}}}',
      ),
      throwsA(
        isA<FormatException>().having(
          (error) => error.message,
          'message',
          contains('"strategy"'),
        ),
      ),
    );
  });

  test('malformed themes are rejected', () {
    expect(
      () => NorgThemeFamily.fromJson({'name': 'x'}),
      throwsFormatException,
    );
    expect(
      () => NorgThemeFamily.fromJson({
        'name': 'x',
        'variants': {
          'dark': {'Normal': 3},
          'light': <String, Object?>{},
        },
      }),
      throwsFormatException,
    );
  });
}
