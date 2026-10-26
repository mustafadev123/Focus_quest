import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

/// Opens the local SQLite database described in proposal Section 8.
///
/// Timestamps are stored as milliseconds since the epoch. CHECK constraints
/// mirror the domain validation so invalid rows are refused even if a caller
/// skips it.
abstract final class AppDatabase {
  static const fileName = 'focus_quest.db';
  static const version = 1;

  static const tasksTable = 'study_tasks';
  static const sessionsTable = 'study_sessions';
  static const activeSessionTable = 'active_session';

  static Future<String> defaultPath() async =>
      p.join(await getDatabasesPath(), fileName);

  static Future<Database> open({
    DatabaseFactory? factory,
    String? path,
  }) async {
    return (factory ?? databaseFactory).openDatabase(
      path ?? await defaultPath(),
      options: OpenDatabaseOptions(
        version: version,
        onConfigure: _onConfigure,
        onCreate: _onCreate,
      ),
    );
  }

  static Future<void> _onConfigure(Database db) async {
    await db.execute('PRAGMA foreign_keys = ON');
  }

  static Future<void> _onCreate(Database db, int version) async {
    final batch = db.batch();

    // AUTOINCREMENT guarantees ids are never reused after a delete.
    batch.execute('''
      CREATE TABLE $tasksTable (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        title TEXT NOT NULL CHECK (length(trim(title)) BETWEEN 1 AND 60),
        subject TEXT NOT NULL CHECK (length(trim(subject)) BETWEEN 1 AND 40),
        priority INTEGER NOT NULL CHECK (priority IN (1, 2, 3)),
        estimated_minutes INTEGER NOT NULL
          CHECK (estimated_minutes BETWEEN 5 AND 120),
        status TEXT NOT NULL CHECK (status IN ('pending', 'completed')),
        created_at INTEGER NOT NULL,
        updated_at INTEGER NOT NULL CHECK (updated_at >= created_at)
      )
    ''');

    batch.execute('''
      CREATE TABLE $sessionsTable (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        task_id INTEGER NOT NULL
          REFERENCES $tasksTable (id) ON DELETE CASCADE,
        started_at INTEGER NOT NULL,
        ended_at INTEGER CHECK (ended_at IS NULL OR ended_at >= started_at),
        duration_minutes INTEGER NOT NULL
          CHECK (duration_minutes BETWEEN 1 AND 120),
        status TEXT NOT NULL
          CHECK (status IN ('completed', 'ended_early', 'manual'))
      )
    ''');
    // Task and date filters in History.
    batch.execute('CREATE INDEX idx_sessions_task_started '
        'ON $sessionsTable (task_id, started_at)');
    batch.execute('CREATE INDEX idx_sessions_started '
        'ON $sessionsTable (started_at)');

    // At most one in-progress focus session, so it survives a restart.
    batch.execute('''
      CREATE TABLE $activeSessionTable (
        id INTEGER PRIMARY KEY CHECK (id = 1),
        task_id INTEGER NOT NULL
          REFERENCES $tasksTable (id) ON DELETE CASCADE,
        state TEXT NOT NULL
          CHECK (state IN ('running', 'paused', 'awaiting_save')),
        started_at INTEGER NOT NULL,
        elapsed_active_ms INTEGER NOT NULL CHECK (elapsed_active_ms >= 0),
        target_minutes INTEGER NOT NULL
          CHECK (target_minutes BETWEEN 5 AND 120),
        last_resumed_at INTEGER
      )
    ''');

    await batch.commit(noResult: true);
  }
}
