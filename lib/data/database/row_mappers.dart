import '../../domain/models/study_session.dart';
import '../../domain/models/study_task.dart';

/// Converts between SQLite rows and domain models.
///
/// Reading throws [FormatException] for values the schema should never
/// contain, so corrupted data surfaces as an error instead of a wrong record.

Map<String, Object?> taskToRow(StudyTask task) => {
      if (task.id != null) 'id': task.id,
      'title': task.title.trim(),
      'subject': task.subject.trim(),
      'priority': task.priority.value,
      'estimated_minutes': task.estimatedMinutes,
      'status': task.status.storageValue,
      'created_at': task.createdAt.millisecondsSinceEpoch,
      'updated_at': task.updatedAt.millisecondsSinceEpoch,
    };

StudyTask taskFromRow(Map<String, Object?> row) {
  final priority = TaskPriority.fromValue(row['priority'] as int);
  final status = TaskStatus.fromStorage(row['status'] as String);
  if (priority == null || status == null) {
    throw FormatException('Invalid task row', row);
  }
  return StudyTask(
    id: row['id'] as int,
    title: row['title'] as String,
    subject: row['subject'] as String,
    priority: priority,
    estimatedMinutes: row['estimated_minutes'] as int,
    status: status,
    createdAt: _date(row['created_at'])!,
    updatedAt: _date(row['updated_at'])!,
  );
}

Map<String, Object?> sessionToRow(StudySession session) => {
      if (session.id != null) 'id': session.id,
      'task_id': session.taskId,
      'started_at': session.startedAt.millisecondsSinceEpoch,
      'ended_at': session.endedAt?.millisecondsSinceEpoch,
      'duration_minutes': session.durationMinutes,
      'status': session.status.storageValue,
    };

StudySession sessionFromRow(Map<String, Object?> row) {
  final status = SessionStatus.fromStorage(row['status'] as String);
  if (status == null) throw FormatException('Invalid session row', row);
  return StudySession(
    id: row['id'] as int,
    taskId: row['task_id'] as int,
    startedAt: _date(row['started_at'])!,
    endedAt: _date(row['ended_at']),
    durationMinutes: row['duration_minutes'] as int,
    status: status,
  );
}

DateTime? _date(Object? millis) =>
    millis == null ? null : DateTime.fromMillisecondsSinceEpoch(millis as int);
