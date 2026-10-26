import 'package:intl/intl.dart';

import '../aggregates.dart';
import '../models/session_record.dart';

/// Everything the report needs, in one value so it can be sent to a
/// background isolate.
class StudyReportInput {
  const StudyReportInput({
    required this.generatedAt,
    required this.periodLabel,
    required this.taskLabel,
    required this.subjectLabel,
    required this.records,
  });

  final DateTime generatedAt;
  final String periodLabel;
  final String taskLabel;
  final String subjectLabel;

  /// Newest first, as History lists them.
  final List<SessionRecord> records;
}

/// Plain-text study summary for the sessions History is showing.
String buildStudyReport(StudyReportInput input) {
  final records = input.records;
  final dateTime = DateFormat('MMM d, y h:mm a');
  final out = StringBuffer()
    ..writeln('FocusQuest study summary')
    ..writeln('Generated ${dateTime.format(input.generatedAt)}')
    ..writeln('Period: ${input.periodLabel}')
    ..writeln('Filters: ${input.taskLabel}, ${input.subjectLabel}')
    ..writeln();

  if (records.isEmpty) {
    out.writeln('No sessions in this period.');
    return out.toString();
  }

  final total = totalMinutes(records);
  out
    ..writeln('Total: ${_time(total)} across ${_count(records.length)}')
    ..writeln();

  void section(String title, String Function(SessionRecord) keyOf) {
    final minutes = <String, int>{};
    final sessions = <String, int>{};
    for (final r in records) {
      final key = keyOf(r);
      minutes.update(key, (m) => m + r.session.durationMinutes,
          ifAbsent: () => r.session.durationMinutes);
      sessions.update(key, (n) => n + 1, ifAbsent: () => 1);
    }
    // Most studied first, then alphabetically.
    final keys = minutes.keys.toList()
      ..sort((a, b) {
        final byTime = minutes[b]!.compareTo(minutes[a]!);
        return byTime != 0 ? byTime : a.compareTo(b);
      });
    out.writeln(title);
    for (final key in keys) {
      out.writeln('  $key: ${_time(minutes[key]!)} '
          '(${_count(sessions[key]!)})');
    }
    out.writeln();
  }

  section('By subject', (r) => r.subject);
  section('By task', (r) => '${r.taskTitle} (${r.subject})');

  final when = DateFormat('MMM d, h:mm a');
  out.writeln('Sessions');
  for (final r in records) {
    final s = r.session;
    out.writeln('  ${when.format(s.startedAt)}  ${r.taskTitle}  '
        '${s.durationMinutes} min  ${s.status.label}');
  }
  return out.toString();
}

String _time(int minutes) {
  final h = minutes ~/ 60;
  final m = minutes % 60;
  if (h == 0) return '${m}m';
  return m == 0 ? '${h}h' : '${h}h ${m}m';
}

String _count(int n) => '$n ${n == 1 ? 'session' : 'sessions'}';
