import 'models/session_record.dart';

/// Minutes studied on one local calendar day.
class DayTotal {
  const DayTotal(this.day, this.minutes);

  /// Local midnight at the start of the day.
  final DateTime day;
  final int minutes;

  @override
  bool operator ==(Object other) =>
      other is DayTotal && other.day == day && other.minutes == minutes;

  @override
  int get hashCode => Object.hash(day, minutes);

  @override
  String toString() => 'DayTotal(${day.month}/${day.day}: $minutes min)';
}

/// Number of days in the History chart, today included.
const chartDays = 7;

/// Local midnight [chartDays] − 1 days before today: the first day shown.
DateTime chartStart(DateTime now) =>
    DateTime(now.year, now.month, now.day - (chartDays - 1));

/// Minutes per local calendar day for the [chartDays] days ending today,
/// oldest first. Every day is present, including days with no study.
///
/// A session's whole duration counts on the day its start time falls on;
/// sessions crossing midnight are not split. Sessions outside the window
/// are ignored.
List<DayTotal> dailyMinutes(List<SessionRecord> records, DateTime now) {
  // Built from calendar fields, not by adding 24-hour durations, so a
  // daylight-saving change cannot skip or repeat a day.
  final days = [
    for (var i = chartDays - 1; i >= 0; i--)
      DateTime(now.year, now.month, now.day - i),
  ];
  final minutes = {for (final d in days) d: 0};
  for (final r in records) {
    final s = r.session.startedAt;
    final day = DateTime(s.year, s.month, s.day);
    if (minutes.containsKey(day)) {
      minutes[day] = minutes[day]! + r.session.durationMinutes;
    }
  }
  return [for (final d in days) DayTotal(d, minutes[d]!)];
}
