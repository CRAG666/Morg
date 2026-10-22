const _englishMonths = [
  'january',
  'february',
  'march',
  'april',
  'may',
  'june',
  'july',
  'august',
  'september',
  'october',
  'november',
  'december',
];
const _spanishMonths = [
  'enero',
  'febrero',
  'marzo',
  'abril',
  'mayo',
  'junio',
  'julio',
  'agosto',
  'septiembre',
  'octubre',
  'noviembre',
  'diciembre',
];
const _englishWeekdays = [
  'monday',
  'tuesday',
  'wednesday',
  'thursday',
  'friday',
  'saturday',
  'sunday',
];
const _spanishWeekdays = [
  'lunes',
  'martes',
  'miercoles',
  'jueves',
  'viernes',
  'sabado',
  'domingo',
];
const _accents = {'á': 'a', 'é': 'e', 'í': 'i', 'ó': 'o', 'ú': 'u'};

final _iso = RegExp(
  r'^(-?\d{4,})-(\d{1,2})-(\d{1,2})(?:[ T](\d{1,2}):(\d{2}))?$',
);
final _separators = RegExp(r'[\s,]+');
final _range = RegExp(r'\s+-\s+|(?<=\S)-(?=\d)');
final _dayToken = RegExp(r'^(\d{1,3})(?:st|nd|rd|th)?$', caseSensitive: false);
final _yearToken = RegExp(r'^-?\d{4,}$');
final _timeToken = RegExp(r'^(\d{1,2}):(\d{2})(?:\.(\d{1,2}))?$');
final _zoneToken = RegExp(r'^[a-z]{2,5}$', caseSensitive: false);

typedef _Fields = ({
  int? weekday,
  int? day,
  int? month,
  int? year,
  (int, int, int)? time,
  bool utc,
});

class NorgTimestamp {
  const NorgTimestamp(this.start, this.end, this._fields);

  final DateTime start;
  final DateTime? end;
  final _Fields _fields;

  DateTime next(DateTime today) {
    final midnight = DateTime(today.year, today.month, today.day);
    final (:day, :month, :year, weekday: _, time: _, utc: _) = _fields;
    if (!start.isBefore(midnight) || year != null || day == null) return start;
    var next = start;
    for (var step = 1; next.isBefore(midnight); step++) {
      next = DateTime(
        start.year + (month != null ? step : 0),
        start.month + (month == null ? step : 0),
        start.day,
        start.hour,
        start.minute,
        start.second,
      );
    }
    return next;
  }
}

NorgTimestamp? parseNorgTimestamp(String text, {required DateTime today}) {
  final trimmed = text.trim();
  if (_iso.firstMatch(trimmed) case final match?) {
    final fields = (
      weekday: null,
      day: int.parse(match[3]!),
      month: int.parse(match[2]!),
      year: int.parse(match[1]!),
      time: match[4] == null
          ? null
          : (int.parse(match[4]!), int.parse(match[5]!), 0),
      utc: false,
    );
    return switch (_resolve(fields, today)) {
      final start? => NorgTimestamp(start, null, fields),
      null => null,
    };
  }
  final sides = trimmed.split(_range);
  if (sides.length > 2) return null;
  final last = _fields(sides.last);
  if (last == null) return null;
  final first = sides.length == 1 ? last : _fields(sides.first);
  if (first == null) return null;
  final completed = (
    weekday: first.weekday,
    day: first.day,
    month: first.month ?? last.month,
    year: first.year ?? last.year,
    time: first.time,
    utc: first.utc || last.utc,
  );
  final start = _resolve(completed, today);
  if (start == null) return null;
  return NorgTimestamp(
    start,
    sides.length == 1 ? null : _resolve(last, today),
    completed,
  );
}

DateTime? parseNorgDate(String text, {required DateTime today}) =>
    parseNorgTimestamp(text, today: today)?.start;

_Fields? _fields(String text) {
  int? weekday;
  int? day;
  int? month;
  int? year;
  (int, int, int)? time;
  var utc = false;
  var position = 0;
  for (final token in text.split(_separators).where((t) => t.isNotEmpty)) {
    final word = _plain(token.toLowerCase());
    final name = _name(word, position);
    final dayMatch = position < 2 ? _dayToken.firstMatch(token) : null;
    final timeMatch = position < 5 ? _timeToken.firstMatch(token) : null;
    if (name.weekday case final found?) {
      (weekday, position) = (found, 1);
    } else if (dayMatch != null) {
      (day, position) = (int.parse(dayMatch[1]!), 2);
    } else if (name.month case final found?) {
      (month, position) = (found, 3);
    } else if (position < 4 && _yearToken.hasMatch(token)) {
      (year, position) = (int.parse(token), 4);
    } else if (timeMatch != null) {
      time = (
        int.parse(timeMatch[1]!),
        int.parse(timeMatch[2]!),
        int.parse(timeMatch[3] ?? '0'),
      );
      position = 5;
    } else if (position >= 3 && position < 6 && _zoneToken.hasMatch(token)) {
      utc = word == 'gmt' || word == 'utc';
      position = 6;
    } else {
      return null;
    }
  }
  if (position == 0) return null;
  return (
    weekday: weekday,
    day: day,
    month: month,
    year: year,
    time: time,
    utc: utc,
  );
}

DateTime? _resolve(_Fields fields, DateTime today) {
  final (:weekday, :day, :month, :year, :time, :utc) = fields;
  final (hour, minute, second) = time ?? (0, 0, 0);
  if (weekday != null && day == null && month == null && year == null) {
    final midnight = DateTime(today.year, today.month, today.day);
    return midnight.add(
      Duration(
        days: (weekday - today.weekday) % 7,
        hours: hour,
        minutes: minute,
        seconds: second,
      ),
    );
  }
  final resolvedMonth =
      month ?? (day != null || time != null ? today.month : 1);
  final resolvedDay = day ?? (month == null && time != null ? today.day : 1);
  final resolvedYear = year ?? today.year;
  final date = utc
      ? DateTime.utc(
          resolvedYear,
          resolvedMonth,
          resolvedDay,
          hour,
          minute,
          second,
        ).toLocal()
      : DateTime(
          resolvedYear,
          resolvedMonth,
          resolvedDay,
          hour,
          minute,
          second,
        );
  final check = utc ? date.toUtc() : date;
  return check.month == resolvedMonth && check.day == resolvedDay ? date : null;
}

({int? weekday, int? month}) _name(String word, int position) {
  List<int> matches(List<String> names) => [
    for (final (index, name) in names.indexed)
      if (name.startsWith(word)) index + 1,
  ];
  for (final (weekdays, months) in [
    (_englishWeekdays, _englishMonths),
    (_spanishWeekdays, _spanishMonths),
  ]) {
    final days = position < 1 ? matches(weekdays) : const <int>[];
    final monthMatches = position < 3 ? matches(months) : const <int>[];
    if (days.length == 1) return (weekday: days.single, month: null);
    if (monthMatches.length == 1) {
      return (weekday: null, month: monthMatches.single);
    }
    if (days.isNotEmpty || monthMatches.isNotEmpty) break;
  }
  return (weekday: null, month: null);
}

String _plain(String word) =>
    word.split('').map((char) => _accents[char] ?? char).join();

String norgDate(DateTime date, {bool withTime = false}) {
  final weekday = _englishWeekdays[date.weekday - 1];
  final month = _englishMonths[date.month - 1];
  String two(int value) => value.toString().padLeft(2, '0');
  return '${weekday[0].toUpperCase()}${weekday.substring(1, 3)}, ${date.day} '
      '${month[0].toUpperCase()}${month.substring(1, 3)} ${date.year}'
      '${withTime ? ' ${two(date.hour)}:${two(date.minute)}' : ''}';
}
