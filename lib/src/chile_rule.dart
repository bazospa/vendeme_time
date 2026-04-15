// Pure-Dart encoding of Chile's IANA DST rule (in effect since 2019):
//   - Apr Su>=2 at 03:00 UTC → standard time  (UTC-4)
//   - Sep Su>=2 at 04:00 UTC → summer time    (UTC-3)
//
// No Flutter imports here so the rule can be consumed from `dart run` scripts.

DateTime _firstSundayOnOrAfter2(int year, int month) {
  for (int day = 2; day <= 8; day++) {
    final DateTime d = DateTime.utc(year, month, day);
    if (d.weekday == DateTime.sunday) return d;
  }
  throw StateError('unreachable');
}

Map<String, dynamic> buildChileTimeZone({int fromYear = 2024, int toYear = 2040}) {
  final List<Map<String, dynamic>> periods = <Map<String, dynamic>>[];
  for (int year = fromYear; year <= toYear; year++) {
    final DateTime winterStart =
        _firstSundayOnOrAfter2(year, 4).add(const Duration(hours: 3));
    final DateTime summerStart =
        _firstSundayOnOrAfter2(year, 9).add(const Duration(hours: 4));

    periods.add(<String, dynamic>{
      'start': winterStart.toIso8601String(),
      'end': summerStart.toIso8601String(),
      'offsetMinutes': -240,
    });
    if (year < toYear) {
      final DateTime nextWinterStart =
          _firstSundayOnOrAfter2(year + 1, 4).add(const Duration(hours: 3));
      periods.add(<String, dynamic>{
        'start': summerStart.toIso8601String(),
        'end': nextWinterStart.toIso8601String(),
        'offsetMinutes': -180,
      });
    } else {
      periods.add(<String, dynamic>{
        'start': summerStart.toIso8601String(),
        'offsetMinutes': -180,
      });
    }
  }
  return <String, dynamic>{
    'id': 'America/Santiago',
    'fallbackMinutes': -180,
    'periods': periods,
  };
}
