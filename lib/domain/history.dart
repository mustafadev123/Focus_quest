import 'aggregates.dart';
import 'models/session_record.dart';

/// History date filter. "This week" starts on Monday, as on the Dashboard.
enum HistoryRange {
  today('Today'),
  thisWeek('This week'),
  thisMonth('This month'),
  allTime('All time');

  const HistoryRange(this.label);

  final String label;

  /// Inclusive start of the range at [now]; null means unbounded.
  DateTime? startAt(DateTime now) => switch (this) {
        HistoryRange.today => DateTime(now.year, now.month, now.day),
        HistoryRange.thisWeek => startOfWeek(now),
        HistoryRange.thisMonth => DateTime(now.year, now.month),
        HistoryRange.allTime => null,
      };
}

/// Totals shown above the History list.
class HistorySummary {
  const HistorySummary({required this.totalMinutes, required this.sessions});

  static const empty = HistorySummary(totalMinutes: 0, sessions: 0);

  final int totalMinutes;
  final int sessions;

  @override
  bool operator ==(Object other) =>
      other is HistorySummary &&
      other.totalMinutes == totalMinutes &&
      other.sessions == sessions;

  @override
  int get hashCode => Object.hash(totalMinutes, sessions);

  @override
  String toString() => 'HistorySummary($totalMinutes min, $sessions sessions)';
}

/// Pure so it can run in a background isolate.
HistorySummary summarizeHistory(List<SessionRecord> records) => HistorySummary(
      totalMinutes: totalMinutes(records),
      sessions: records.length,
    );
