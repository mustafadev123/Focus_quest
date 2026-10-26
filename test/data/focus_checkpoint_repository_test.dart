import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:focus_quest/data/database/app_database.dart';
import 'package:focus_quest/data/repositories/sqlite_focus_checkpoint_repository.dart';
import 'package:focus_quest/data/repositories/sqlite_session_repository.dart';
import 'package:focus_quest/data/repositories/sqlite_task_repository.dart';
import 'package:focus_quest/domain/focus/focus_session.dart';
import 'package:focus_quest/domain/models/study_session.dart';
import 'package:focus_quest/domain/models/study_task.dart';
import 'package:focus_quest/domain/repositories/focus_checkpoint_repository.dart';
import 'package:focus_quest/domain/repositories/task_repository.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../support/test_database.dart';

final _t0 = DateTime(2026, 10, 25, 18);
DateTime _at(int minutes) => _t0.add(Duration(minutes: minutes));

void main() {
  late Database db;
  late SqliteFocusCheckpointRepository checkpoints;
  late SqliteSessionRepository sessions;
  late SqliteTaskRepository tasks;
  late FocusSession ready;

  setUp(() async {
    db = await openTestDatabase();
    checkpoints = SqliteFocusCheckpointRepository(db, clock: () => _at(60));
    sessions = SqliteSessionRepository(db, clock: () => _at(60));
    tasks = SqliteTaskRepository(db, clock: () => DateTime(2026, 10, 20));
    final task = await tasks.create(
      title: 'Review recursion notes',
      subject: 'Data Structures',
      priority: TaskPriority.high,
      estimatedMinutes: 25,
    );
    ready = FocusSession.ready(
        taskId: task.id, target: const Duration(minutes: 25));
  });
  tearDown(() async => db.close());

  test('there is no checkpoint before a session starts', () async {
    expect(await checkpoints.load(), isNull);
  });

  test('running, paused and awaiting-save sessions round-trip', () async {
    final running = ready.start(_t0);
    final paused = running.pause(_at(5));
    final review = paused.resume(_at(10)).finish(_at(12));

    for (final session in [running, paused, review]) {
      await checkpoints.save(session);
      final loaded = (await checkpoints.load())!;
      expect(loaded.phase, session.phase);
      expect(loaded.taskId, session.taskId);
      expect(loaded.target, session.target);
      expect(loaded.startedAt, session.startedAt);
      expect(loaded.lastResumedAt, session.lastResumedAt);
      expect(loaded.finishedAt, session.finishedAt);
      expect(loaded.activeAt(_at(40)), session.activeAt(_at(40)));
    }
  });

  test('Ready and Saved sessions are not checkpointed', () async {
    expect(() => checkpoints.save(ready), throwsArgumentError);
  });

  test('saveRecord writes one record and removes the checkpoint', () async {
    final review = ready.start(_t0).finish(_at(20));
    await checkpoints.save(review);

    final record = await checkpoints.saveRecord(review);

    expect(record.id, isNotNull);
    expect(record.durationMinutes, 20);
    expect(record.status, SessionStatus.endedEarly);
    expect(await checkpoints.load(), isNull);
    expect((await sessions.getRecords()).single.session, record);
  });

  test('saving the same session twice creates only one record', () async {
    final review = ready.start(_t0).finish(_at(20));
    await checkpoints.save(review);

    await checkpoints.saveRecord(review);
    await expectLater(checkpoints.saveRecord(review),
        throwsA(isA<SessionAlreadySavedException>()));
    expect(await sessions.getRecords(), hasLength(1));
  });

  test('a failed save keeps the checkpoint so Save can be retried', () async {
    final review = ready.start(_t0).finish(_at(20));
    await checkpoints.save(review);
    // Make the insert fail inside the transaction.
    await db.execute('''
      CREATE TRIGGER fail_insert BEFORE INSERT ON study_sessions
      BEGIN SELECT RAISE(ABORT, 'disk full'); END
    ''');

    await expectLater(
        checkpoints.saveRecord(review), throwsA(isA<DatabaseException>()));
    expect(await checkpoints.load(), isNotNull);
    expect(await sessions.getRecords(), isEmpty);

    await db.execute('DROP TRIGGER fail_insert');
    await checkpoints.saveRecord(review);
    expect(await sessions.getRecords(), hasLength(1));
  });

  test('clear removes the checkpoint', () async {
    await checkpoints.save(ready.start(_t0));
    await checkpoints.clear();
    expect(await checkpoints.load(), isNull);
  });

  test('the checkpoint blocks deleting its task', () async {
    await checkpoints.save(ready.start(_t0));
    expect(() => tasks.delete(ready.taskId!),
        throwsA(isA<ActiveTaskDeletionException>()));
  });

  test('a version 1 database is upgraded without losing data', () async {
    final dir = await Directory.systemTemp.createTemp('focus_quest_upgrade');
    addTearDown(() => dir.delete(recursive: true));
    final path = p.join(dir.path, AppDatabase.fileName);

    // The version 1 schema as shipped before finished_at existed.
    sqfliteFfiInit();
    final v1 = await databaseFactoryFfi.openDatabase(path,
        options: OpenDatabaseOptions(
          version: 1,
          onCreate: (db, _) async {
            await db.execute('CREATE TABLE study_tasks (id INTEGER PRIMARY KEY '
                'AUTOINCREMENT, title TEXT NOT NULL, subject TEXT NOT NULL, '
                'priority INTEGER NOT NULL, estimated_minutes INTEGER NOT NULL, '
                'status TEXT NOT NULL, created_at INTEGER NOT NULL, '
                'updated_at INTEGER NOT NULL)');
            await db.execute('CREATE TABLE study_sessions (id INTEGER PRIMARY '
                'KEY AUTOINCREMENT, task_id INTEGER NOT NULL, started_at '
                'INTEGER NOT NULL, ended_at INTEGER, duration_minutes INTEGER '
                'NOT NULL, status TEXT NOT NULL)');
            await db.execute('CREATE TABLE active_session (id INTEGER PRIMARY '
                'KEY CHECK (id = 1), task_id INTEGER NOT NULL, state TEXT NOT '
                'NULL, started_at INTEGER NOT NULL, elapsed_active_ms INTEGER '
                'NOT NULL, target_minutes INTEGER NOT NULL, last_resumed_at '
                'INTEGER)');
          },
        ));
    await v1.insert('study_tasks', {
      'title': 'Lab 3 report',
      'subject': 'Physics',
      'priority': 2,
      'estimated_minutes': 50,
      'status': 'pending',
      'created_at': 0,
      'updated_at': 0,
    });
    await v1.close();

    final upgraded = await openTestDatabase(path: path);
    addTearDown(upgraded.close);

    expect(await upgraded.getVersion(), AppDatabase.version);
    final columns =
        await upgraded.rawQuery('PRAGMA table_info(active_session)');
    expect(columns.map((c) => c['name']), contains('finished_at'));
    final rows = await upgraded.query('study_tasks');
    expect(rows.single['title'], 'Lab 3 report');
  });
}
