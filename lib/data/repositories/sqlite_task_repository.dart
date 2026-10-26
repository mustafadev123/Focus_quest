import 'package:sqflite/sqflite.dart';

import '../../domain/clock.dart';
import '../../domain/models/study_task.dart';
import '../../domain/repositories/task_repository.dart';
import '../../domain/validation/validation.dart';
import '../database/app_database.dart';
import '../database/row_mappers.dart';

class SqliteTaskRepository implements TaskRepository {
  SqliteTaskRepository(this._db, {Clock clock = systemClock}) : _clock = clock;

  final Database _db;
  final Clock _clock;

  static const _tasks = AppDatabase.tasksTable;

  @override
  Future<List<StudyTask>> getAll() async {
    final rows = await _db.query(_tasks, orderBy: 'created_at, id');
    return rows.map(taskFromRow).toList();
  }

  @override
  Future<StudyTask?> getById(int id) async {
    final rows = await _db.query(_tasks, where: 'id = ?', whereArgs: [id]);
    return rows.isEmpty ? null : taskFromRow(rows.single);
  }

  @override
  Future<List<String>> getSubjects() async {
    final rows = await _db.rawQuery(
        'SELECT DISTINCT subject FROM $_tasks ORDER BY subject COLLATE NOCASE');
    return [for (final row in rows) row['subject'] as String];
  }

  @override
  Future<StudyTask> create({
    required String title,
    required String subject,
    required TaskPriority priority,
    required int estimatedMinutes,
    TaskStatus status = TaskStatus.pending,
  }) async {
    final now = _clock();
    final task = StudyTask(
      title: title.trim(),
      subject: subject.trim(),
      priority: priority,
      estimatedMinutes: estimatedMinutes,
      status: status,
      createdAt: now,
      updatedAt: now,
    );
    ensureValidTask(task);
    final id = await _db.insert(_tasks, taskToRow(task));
    return task.copyWith(id: id);
  }

  @override
  Future<StudyTask> update(StudyTask task) async {
    final id = task.id;
    if (id == null) throw ArgumentError('Cannot update a task without an id');

    // Keep updatedAt >= createdAt even if the device clock moved backwards.
    final now = _clock();
    final updated = task.copyWith(
      title: task.title.trim(),
      subject: task.subject.trim(),
      updatedAt: now.isBefore(task.createdAt) ? task.createdAt : now,
    );
    ensureValidTask(updated);

    final changed = await _db.update(_tasks, taskToRow(updated),
        where: 'id = ?', whereArgs: [id]);
    if (changed == 0) throw RecordNotFoundException(id);
    return updated;
  }

  @override
  Future<int> countSessions(int taskId) => _countSessions(_db, taskId);

  @override
  Future<int> delete(int taskId) {
    return _db.transaction((txn) async {
      final active = await txn.query(AppDatabase.activeSessionTable,
          where: 'task_id = ?', whereArgs: [taskId]);
      if (active.isNotEmpty) throw ActiveTaskDeletionException(taskId);

      final sessions = await _countSessions(txn, taskId);
      final deleted =
          await txn.delete(_tasks, where: 'id = ?', whereArgs: [taskId]);
      if (deleted == 0) throw RecordNotFoundException(taskId);
      return sessions;
    });
  }

  static Future<int> _countSessions(DatabaseExecutor db, int taskId) async {
    final rows = await db.rawQuery(
      'SELECT COUNT(*) AS n FROM ${AppDatabase.sessionsTable} WHERE task_id = ?',
      [taskId],
    );
    return rows.single['n'] as int;
  }
}
