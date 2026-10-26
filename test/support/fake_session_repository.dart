import 'package:focus_quest/domain/models/session_record.dart';
import 'package:focus_quest/domain/models/study_session.dart';
import 'package:focus_quest/domain/repositories/session_repository.dart';
import 'package:focus_quest/domain/repositories/task_repository.dart';

/// In-memory [SessionRepository]; records carry their task title and subject.
class FakeSessionRepository implements SessionRepository {
  FakeSessionRepository({List<SessionRecord> records = const []}) {
    for (final record in records) {
      final id = record.session.id ?? ++_lastId;
      if (id > _lastId) _lastId = id;
      _records[id] = SessionRecord(
        session: record.session.copyWith(id: id),
        taskTitle: record.taskTitle,
        subject: record.subject,
      );
    }
  }

  final Map<int, SessionRecord> _records = {};
  int _lastId = 0;

  /// Task title and subject used for sessions created through [create].
  final Map<int, (String, String)> taskInfo = {};

  Object? failNextRead;
  Object? failNextWrite;

  void _maybeFail({bool write = false}) {
    final error = write ? failNextWrite : failNextRead;
    if (error == null) return;
    if (write) {
      failNextWrite = null;
    } else {
      failNextRead = null;
    }
    throw error;
  }

  @override
  Future<List<SessionRecord>> getRecords(
      [SessionFilter filter = SessionFilter.none]) async {
    _maybeFail();
    final from = filter.from;
    final until = filter.until;
    return _records.values.where((r) {
      final s = r.session;
      return (filter.taskId == null || s.taskId == filter.taskId) &&
          (filter.subject == null || r.subject == filter.subject) &&
          (from == null || !s.startedAt.isBefore(from)) &&
          (until == null || s.startedAt.isBefore(until));
    }).toList()
      ..sort((a, b) => b.session.startedAt.compareTo(a.session.startedAt));
  }

  @override
  Future<StudySession?> getById(int id) async {
    _maybeFail();
    return _records[id]?.session;
  }

  @override
  Future<StudySession> create(StudySession session) async {
    _maybeFail(write: true);
    final saved = session.copyWith(id: ++_lastId);
    final (title, subject) = taskInfo[session.taskId] ?? ('Task', 'Subject');
    _records[saved.id!] =
        SessionRecord(session: saved, taskTitle: title, subject: subject);
    return saved;
  }

  @override
  Future<StudySession> update(StudySession session) async {
    _maybeFail(write: true);
    final existing = _records[session.id];
    if (existing == null) throw RecordNotFoundException(session.id!);
    _records[session.id!] = SessionRecord(
        session: session,
        taskTitle: existing.taskTitle,
        subject: existing.subject);
    return session;
  }

  @override
  Future<void> delete(int id) async {
    _maybeFail(write: true);
    if (_records.remove(id) == null) throw RecordNotFoundException(id);
  }

  @override
  Future<Map<int, int>> minutesByTaskSince(DateTime since) async {
    _maybeFail();
    final totals = <int, int>{};
    for (final r in _records.values) {
      if (r.session.startedAt.isBefore(since)) continue;
      totals.update(r.session.taskId, (m) => m + r.session.durationMinutes,
          ifAbsent: () => r.session.durationMinutes);
    }
    return totals;
  }
}
