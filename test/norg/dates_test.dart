import 'package:flutter_test/flutter_test.dart';
import 'package:morg/norg/dates.dart';

final today = DateTime(2026, 10, 22);

DateTime? parse(String text) => parseNorgDate(text, today: today);

void main() {
  test('formats from the Norg specification', () {
    expect(parse('We 12th Jan 2022'), DateTime(2022, 1, 12));
    expect(
      parse('Sat, 29 Oct 1994 19:43.31'),
      DateTime(1994, 10, 29, 19, 43, 31),
    );
    expect(
      parse('Sat, 29 Oct 1994 19:43.31 GMT'),
      DateTime.utc(1994, 10, 29, 19, 43, 31).toLocal(),
    );
  });

  test('weekdays and months may be abbreviated when unambiguous', () {
    expect(parse('Tuesday 5th Feb'), DateTime(2026, 2, 5));
    expect(parse('M 5th Feb'), DateTime(2026, 2, 5));
    expect(parse('Frid, 6 Feb'), DateTime(2026, 2, 6));
    expect(parse('T 5th Feb'), isNull);
    expect(parse('5 Ma 2026'), isNull);
  });

  test('any field can be left out', () {
    expect(parse('Jan 2022'), DateTime(2022, 1));
    expect(parse('October'), DateTime(2026, 10));
    expect(parse('18:00'), DateTime(2026, 10, 22, 18));
    expect(parse('Tue'), DateTime(2026, 10, 27));
    expect(parse('5th'), DateTime(2026, 10, 5));
  });

  test('years may be negative and need at least four digits', () {
    expect(parse('5th Aug -0200'), DateTime(-200, 8, 5));
    expect(parse('5th Aug 200'), isNull);
  });

  test('ranges complete the shorter side from the other', () {
    final both = parseNorgTimestamp(
      '5th Aug 2022 - 20th August 2022',
      today: today,
    )!;
    expect(
      (both.start, both.end),
      (DateTime(2022, 8, 5), DateTime(2022, 8, 20)),
    );
    final short = parseNorgTimestamp('5th - 20th August 2022', today: today)!;
    expect(
      (short.start, short.end),
      (DateTime(2022, 8, 5), DateTime(2022, 8, 20)),
    );
    expect(parse('5th Aug 2022-20th August 2022'), DateTime(2022, 8, 5));
  });

  test('Spanish names are understood too', () {
    expect(parse('5 febrero 2026'), DateTime(2026, 2, 5));
    expect(parse('miércoles 4 marzo'), DateTime(2026, 3, 4));
  });

  test('ISO dates are accepted', () {
    expect(parse('2026-11-03'), DateTime(2026, 11, 3));
  });

  test('impossible days are rejected', () {
    expect(parse('31 Feb 2024'), isNull);
  });

  test('recurrences move to their next occurrence', () {
    DateTime next(String text) =>
        parseNorgTimestamp(text, today: today)!.next(today);
    expect(next('5th Jan'), DateTime(2027, 1, 5));
    expect(next('5th Dec'), DateTime(2026, 12, 5));
    expect(next('5th'), DateTime(2026, 11, 5));
    expect(next('Mon'), DateTime(2026, 10, 26));
    expect(next('5th Jan 2020'), DateTime(2020, 1, 5));
  });

  test('dates are written as in the specification', () {
    expect(norgDate(DateTime(2026, 10, 30)), 'Fri, 30 Oct 2026');
  });
}
