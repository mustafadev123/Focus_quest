
import '../data/app_database.dart';
import '../models/study_session.dart';

class SessionRepository {
  Future<int> addSession(StudySession session) async {
    _validate(session);

    final db = await AppDatabase.instance.database;
    final values = session.toMap()..remove('id');

    return db.insert('study_sessions', values);
  }

  Future<List<StudySession>> getAllSessions() async {
    final db = await AppDatabase.instance.database;
    final rows = await db.query(
      'study_sessions',
      orderBy: 'start_time DESC',
    );

    return rows.map(StudySession.fromMap).toList();
  }

  Future<int> updateSession(StudySession session) async {
    if (session.id == null) {
      throw ArgumentError('Session ID is required for updating.');
    }

    _validate(session);

    final db = await AppDatabase.instance.database;
    final values = session.toMap()..remove('id');

    return db.update(
      'study_sessions',
      values,
      where: 'id = ?',
      whereArgs: [session.id],
    );
  }

  Future<int> deleteSession(int id) async {
    final db = await AppDatabase.instance.database;

    return db.delete(
      'study_sessions',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  void _validate(StudySession session) {
    if (session.taskId <= 0) {
      throw ArgumentError('A valid task ID is required.');
    }

    if (!session.endTime.isAfter(session.startTime)) {
      throw ArgumentError('End time must be after start time.');
    }

    if (session.durationMinutes <= 0) {
      throw ArgumentError('Duration must be greater than zero.');
    }

    if (session.status != 'completed') {
      throw ArgumentError('Only completed sessions can be saved.');
    }
  }
}
