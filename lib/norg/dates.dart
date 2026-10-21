const _months = [
  'January',
  'February',
  'March',
  'April',
  'May',
  'June',
  'July',
  'August',
  'September',
  'October',
  'November',
  'December',
];
const _weekdays = [
  'Monday',
  'Tuesday',
  'Wednesday',
  'Thursday',
  'Friday',
  'Saturday',
  'Sunday',
];

final _iso = RegExp(
  r'^(-?\d{4,})-(\d{1,2})-(\d{1,2})(?:[ T](\d{1,2}):(\d{2}))?',
);
final _spec = RegExp(
  r'^(?:[a-z]+,?\s+)?(\d{1,3})(?:st|nd|rd|th)?\s+([a-z]+)(?:\s+(-?\d{4,}))?(?:\s+(\d{1,2}):(\d{2}))?',
  caseSensitive: false,
);

DateTime? parseNorgDate(String text, {required int defaultYear}) {
  final trimmed = text.trim();
  if (_iso.firstMatch(trimmed) case final match?) {
    return _date(
      int.parse(match[1]!),
      int.parse(match[2]!),
      int.parse(match[3]!),
      match[4],
      match[5],
    );
  }
  final match = _spec.firstMatch(trimmed);
  if (match == null) return null;
  final word = match[2]!.toLowerCase();
  final months = [
    for (final (index, name) in _months.indexed)
      if (name.toLowerCase().startsWith(word)) index + 1,
  ];
  if (months.length != 1) return null;
  return _date(
    match[3] == null ? defaultYear : int.parse(match[3]!),
    months.single,
    int.parse(match[1]!),
    match[4],
    match[5],
  );
}

DateTime? _date(int year, int month, int day, String? hour, String? minute) {
  final date = DateTime(
    year,
    month,
    day,
    hour == null ? 0 : int.parse(hour),
    minute == null ? 0 : int.parse(minute),
  );
  return date.month == month && date.day == day ? date : null;
}

String norgDate(DateTime date) =>
    '${_weekdays[date.weekday - 1].substring(0, 3)}, ${date.day} '
    '${_months[date.month - 1].substring(0, 3)} ${date.year}';
