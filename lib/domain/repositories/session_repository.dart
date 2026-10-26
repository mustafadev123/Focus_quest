import '../models/session_record.dart';
import '../models/study_session.dart';

/// History filters; null fields are not applied.
class SessionFilter {
  const SessionFilter({this.taskId, this.subject, this.from, this.until});

  final int? taskId;
  final String? subject;

  /// Inclusive lower bound on `startedAt`.
  final DateTime? from;

  /// Exclusive upper bound on `startedAt`.
  final DateTime? until;

  static const none = SessionFilter();
}

abstract interface class SessionRepository {
  /// Sessions matching [filter], newest first.
  Future<List<SessionRecord>> getRecords([SessionFilter filter]);

  Future<StudySession?> getById(int id);

  /// Validates and saves a new session.
  ///
  /// Throws `RecordNotFoundException` if its task does not exist.
  Future<StudySession> create(StudySession session);

  /// Validates and saves changes to an existing session.
  Future<StudySession> update(StudySession session);

  Future<void> delete(int id);

  /// Total minutes per task for sessions started at or after [since].
  /// Tasks without sessions in that window are absent.
  Future<Map<int, int>> minutesByTaskSince(DateTime since);
}
