import 'package:sqflite/sqflite.dart';

import '../../domain/clock.dart';
import '../../domain/models/session_record.dart';
import '../../domain/models/study_session.dart';
import '../../domain/repositories/session_repository.dart';
import '../../domain/repositories/task_repository.dart';
import '../../domain/validation/validation.dart';
import '../database/app_database.dart';
import '../database/row_mappers.dart';

class SqliteSessionRepository implements SessionRepository {
  SqliteSessionRepository(this._db, {Clock clock = systemClock})
      : _clock = clock;

  final Database _db;
  final Clock _clock;

  static const _sessions = AppDatabase.sessionsTable;
  static const _tasks = AppDatabase.tasksTable;

  @override
  Future<List<SessionRecord>> getRecords(
      [SessionFilter filter = SessionFilter.none]) async {
    final where = <String>[];
    final args = <Object?>[];
    if (filter.taskId != null) {
      where.add('s.task_id = ?');
      args.add(filter.taskId);
    }
    if (filter.subject != null) {
      where.add('t.subject = ?');
      args.add(filter.subject);
    }
    if (filter.from != null) {
      where.add('s.started_at >= ?');
      args.add(filter.from!.millisecondsSinceEpoch);
    }
    if (filter.until != null) {
      where.add('s.started_at < ?');
      args.add(filter.until!.millisecondsSinceEpoch);
    }

    final rows = await _db.rawQuery('''
      SELECT s.*, t.title AS task_title, t.subject AS task_subject
      FROM $_sessions s
      JOIN $_tasks t ON t.id = s.task_id
      ${where.isEmpty ? '' : 'WHERE ${where.join(' AND ')}'}
      ORDER BY s.started_at DESC, s.id DESC
    ''', args);

    return [
      for (final row in rows)
        SessionRecord(
          session: sessionFromRow(row),
          taskTitle: row['task_title'] as String,
          subject: row['task_subject'] as String,
        ),
    ];
  }

  @override
  Future<StudySession?> getById(int id) async {
    final rows = await _db.query(_sessions, where: 'id = ?', whereArgs: [id]);
    return rows.isEmpty ? null : sessionFromRow(rows.single);
  }

  @override
  Future<StudySession> create(StudySession session) async {
    ensureValidSession(session, now: _clock());
    try {
      final id =
          await _db.insert(_sessions, sessionToRow(session)..remove('id'));
      return session.copyWith(id: id);
    } on DatabaseException catch (e) {
      if (e.toString().contains('FOREIGN KEY')) {
        throw RecordNotFoundException(session.taskId);
      }
      rethrow;
    }
  }

  @override
  Future<StudySession> update(StudySession session) async {
    final id = session.id;
    if (id == null) {
      throw ArgumentError('Cannot update a session without an id');
    }
    ensureValidSession(session, now: _clock());
    try {
      final changed = await _db.update(_sessions, sessionToRow(session),
          where: 'id = ?', whereArgs: [id]);
      if (changed == 0) throw RecordNotFoundException(id);
      return session;
    } on DatabaseException catch (e) {
      if (e.toString().contains('FOREIGN KEY')) {
        throw RecordNotFoundException(session.taskId);
      }
      rethrow;
    }
  }

  @override
  Future<void> delete(int id) async {
    final deleted =
        await _db.delete(_sessions, where: 'id = ?', whereArgs: [id]);
    if (deleted == 0) throw RecordNotFoundException(id);
  }

  @override
  Future<Map<int, int>> minutesByTaskSince(DateTime since) async {
    final rows = await _db.rawQuery('''
      SELECT task_id, SUM(duration_minutes) AS minutes
      FROM $_sessions
      WHERE started_at >= ?
      GROUP BY task_id
    ''', [since.millisecondsSinceEpoch]);
    return {
      for (final row in rows) row['task_id'] as int: row['minutes'] as int,
    };
  }
}
