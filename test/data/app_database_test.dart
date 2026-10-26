import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:focus_quest/data/database/app_database.dart';
import 'package:focus_quest/data/database/row_mappers.dart';
import 'package:focus_quest/domain/models/study_session.dart';
import 'package:focus_quest/domain/models/study_task.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../support/test_database.dart';

final _t0 = DateTime(2026, 10, 20, 9);

StudyTask _task({String title = 'Lab 3 report'}) => StudyTask(
      title: title,
      subject: 'Physics',
      priority: TaskPriority.medium,
      estimatedMinutes: 50,
      status: TaskStatus.pending,
      createdAt: _t0,
      updatedAt: _t0,
    );

StudySession _session(int taskId) => StudySession(
      taskId: taskId,
      startedAt: _t0,
      endedAt: _t0.add(const Duration(minutes: 30)),
      durationMinutes: 30,
      status: SessionStatus.completed,
    );

void main() {
  late Database db;

  setUp(() async => db = await openTestDatabase());
  tearDown(() async => db.close());

  Future<int> count(String table) async =>
      (await db.rawQuery('SELECT COUNT(*) AS n FROM $table')).single['n']!
          as int;

  test('foreign keys are enforced', () async {
    final rows = await db.rawQuery('PRAGMA foreign_keys');
    expect(rows.single.values.single, 1);

    expect(
      () => db.insert(AppDatabase.sessionsTable, sessionToRow(_session(999))),
      throwsA(isA<DatabaseException>()),
    );
  });

  test('deleting a task cascades to its sessions and checkpoint only',
      () async {
    final keep = await db.insert(AppDatabase.tasksTable, taskToRow(_task()));
    final remove = await db.insert(
        AppDatabase.tasksTable, taskToRow(_task(title: 'Calculus practice')));
    await db.insert(AppDatabase.sessionsTable, sessionToRow(_session(keep)));
    await db.insert(AppDatabase.sessionsTable, sessionToRow(_session(remove)));
    await db.insert(AppDatabase.sessionsTable, sessionToRow(_session(remove)));
    await db.insert(AppDatabase.activeSessionTable, {
      'id': 1,
      'task_id': remove,
      'state': 'paused',
      'started_at': _t0.millisecondsSinceEpoch,
      'elapsed_active_ms': 60000,
      'target_minutes': 25,
    });

    await db.delete(AppDatabase.tasksTable,
        where: 'id = ?', whereArgs: [remove]);

    expect(await count(AppDatabase.sessionsTable), 1);
    expect(await count(AppDatabase.activeSessionTable), 0);
    final remaining = await db.query(AppDatabase.sessionsTable);
    expect(remaining.single['task_id'], keep);
  });

  test('task ids are never reused after a delete', () async {
    final first = await db.insert(AppDatabase.tasksTable, taskToRow(_task()));
    await db.delete(AppDatabase.tasksTable,
        where: 'id = ?', whereArgs: [first]);
    final second = await db.insert(AppDatabase.tasksTable, taskToRow(_task()));
    expect(second, greaterThan(first));
  });

  group('CHECK constraints refuse invalid rows', () {
    Future<void> expectRejected(String table, Map<String, Object?> row) =>
        expectLater(() => db.insert(table, row),
            throwsA(isA<DatabaseException>()));

    test('tasks', () async {
      final valid = taskToRow(_task());
      for (final bad in <Map<String, Object?>>[
        {'title': '   '},
        {'title': 'a' * 61},
        {'subject': 's' * 41},
        {'priority': 4},
        {'estimated_minutes': 4},
        {'estimated_minutes': 121},
        {'status': 'in_progress'},
        {'updated_at': _t0.millisecondsSinceEpoch - 1},
      ]) {
        await expectRejected(AppDatabase.tasksTable, {...valid, ...bad});
      }
    });

    test('sessions', () async {
      final taskId =
          await db.insert(AppDatabase.tasksTable, taskToRow(_task()));
      final valid = sessionToRow(_session(taskId));
      for (final bad in <Map<String, Object?>>[
        {'duration_minutes': 0},
        {'duration_minutes': 121},
        {'status': 'running'},
        {'ended_at': _t0.millisecondsSinceEpoch - 1},
      ]) {
        await expectRejected(AppDatabase.sessionsTable, {...valid, ...bad});
      }
    });

    test('only one active-session checkpoint can exist', () async {
      final taskId =
          await db.insert(AppDatabase.tasksTable, taskToRow(_task()));
      await expectRejected(AppDatabase.activeSessionTable, {
        'id': 2,
        'task_id': taskId,
        'state': 'running',
        'started_at': 0,
        'elapsed_active_ms': 0,
        'target_minutes': 25,
      });
    });
  });

  test('History indexes exist', () async {
    final rows = await db.rawQuery(
        "SELECT name FROM sqlite_master WHERE type = 'index' AND name LIKE 'idx_%'");
    expect(rows.map((r) => r['name']),
        containsAll(['idx_sessions_task_started', 'idx_sessions_started']));
  });

  test('rows map back to identical models', () async {
    final taskId = await db.insert(AppDatabase.tasksTable, taskToRow(_task()));
    final sessionId =
        await db.insert(AppDatabase.sessionsTable, sessionToRow(_session(taskId)));

    final task = taskFromRow((await db.query(AppDatabase.tasksTable)).single);
    final session =
        sessionFromRow((await db.query(AppDatabase.sessionsTable)).single);

    expect(task, _task().copyWith(id: taskId));
    expect(session, _session(taskId).copyWith(id: sessionId));
  });

  test('an unknown stored status is reported instead of guessed', () {
    final row = {...taskToRow(_task()), 'id': 1, 'status': 'archived'};
    expect(() => taskFromRow(row), throwsFormatException);
  });

  test('data persists after the database is closed and reopened', () async {
    final dir = await Directory.systemTemp.createTemp('focus_quest_db');
    addTearDown(() => dir.delete(recursive: true));
    final path = p.join(dir.path, AppDatabase.fileName);

    final first = await openTestDatabase(path: path);
    await first.insert(AppDatabase.tasksTable, taskToRow(_task()));
    await first.close();

    final reopened = await openTestDatabase(path: path);
    addTearDown(reopened.close);
    final rows = await reopened.query(AppDatabase.tasksTable);
    expect(taskFromRow(rows.single).title, 'Lab 3 report');
  });
}
