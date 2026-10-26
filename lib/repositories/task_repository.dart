import '../data/app_database.dart';
import '../models/study_task.dart';

class TaskRepository {
  Future<int> addTask(StudyTask task) async {
    _validate(task);

    final db = await AppDatabase.instance.database;
    final values = task.toMap()..remove('id');

    return db.insert('study_tasks', values);
  }

  Future<List<StudyTask>> getAllTasks() async {
    final db = await AppDatabase.instance.database;

    final rows = await db.query(
      'study_tasks',
      orderBy: 'created_at DESC',
    );

    return rows.map(StudyTask.fromMap).toList();
  }

  Future<StudyTask?> getTaskById(int id) async {
    final db = await AppDatabase.instance.database;

    final rows = await db.query(
      'study_tasks',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );

    if (rows.isEmpty) return null;
    return StudyTask.fromMap(rows.first);
  }

  Future<int> updateTask(StudyTask task) async {
    if (task.id == null) {
      throw ArgumentError('Task ID is required for updating.');
    }

    _validate(task);

    final db = await AppDatabase.instance.database;
    final values = task.toMap()..remove('id');

    return db.update(
      'study_tasks',
      values,
      where: 'id = ?',
      whereArgs: [task.id],
    );
  }

  Future<int> deleteTask(int id) async {
    final db = await AppDatabase.instance.database;

    return db.delete(
      'study_tasks',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<int> setTaskCompleted(int id, bool completed) async {
    final db = await AppDatabase.instance.database;

    return db.update(
      'study_tasks',
      {'is_completed': completed ? 1 : 0},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<int> getTotalStudyMinutes(int taskId) async {
    final db = await AppDatabase.instance.database;

    final result = await db.rawQuery(
      '''
      SELECT COALESCE(SUM(duration_minutes), 0) AS total
      FROM study_sessions
      WHERE task_id = ? AND status = 'completed'
      ''',
      [taskId],
    );

    return (result.first['total'] as num).toInt();
  }

  void _validate(StudyTask task) {
    if (task.title.trim().isEmpty) {
      throw ArgumentError('Task title cannot be empty.');
    }

    if (task.priority < 1 || task.priority > 3) {
      throw ArgumentError('Priority must be between 1 and 3.');
    }

    if (task.estimatedMinutes < 5 || task.estimatedMinutes > 120) {
      throw ArgumentError('Estimated time must be 5–120 minutes.');
    }
  }
}