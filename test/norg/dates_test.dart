import 'package:flutter_test/flutter_test.dart';
import 'package:morg/norg/dates.dart';

void main() {
  DateTime? parse(String text) => parseNorgDate(text, defaultYear: 2026);

  test('formats from the Norg specification', () {
    expect(parse('Sat, 29 Oct 1994 19:43'), DateTime(1994, 10, 29, 19, 43));
    expect(parse('We 12th Jan 2022'), DateTime(2022, 1, 12));
    expect(parse('5th Aug 2022 - 20th August 2022'), DateTime(2022, 8, 5));
  });

  test('a missing year defaults to the given one', () {
    expect(parse('Tue 5th Feb'), DateTime(2026, 2, 5));
  });

  test('ISO dates are accepted', () {
    expect(parse('2026-11-03'), DateTime(2026, 11, 3));
  });

  test('ambiguous months and impossible days are rejected', () {
    expect(parse('Ma 3'), isNull);
    expect(parse('31 Feb 2024'), isNull);
  });

  test('dates are written as in the specification', () {
    expect(norgDate(DateTime(2026, 10, 30)), 'Fri, 30 Oct 2026');
  });
}
