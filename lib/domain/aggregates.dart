import 'models/session_record.dart';
import 'models/study_task.dart';

/// Monday 00:00 local time of the week containing [time].
DateTime startOfWeek(DateTime time) {
  final day = DateTime(time.year, time.month, time.day);
  return day.subtract(Duration(days: day.weekday - DateTime.monday));
}

int totalMinutes(Iterable<SessionRecord> records) =>
    records.fold(0, (sum, r) => sum + r.session.durationMinutes);

int completedCount(Iterable<StudyTask> tasks) =>
    tasks.where((t) => t.isCompleted).length;
