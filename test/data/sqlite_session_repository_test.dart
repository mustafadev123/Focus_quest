import 'package:flutter_test/flutter_test.dart';
import 'package:focus_quest/data/repositories/sqlite_session_repository.dart';
import 'package:focus_quest/data/repositories/sqlite_task_repository.dart';
import 'package:focus_quest/domain/models/study_session.dart';
import 'package:focus_quest/domain/models/study_task.dart';
import 'package:focus_quest/domain/repositories/session_repository.dart';
import 'package:focus_quest/domain/repositories/task_repository.dart';
import 'package:focus_quest/domain/validation/validation.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../support/test_database.dart';

void main() {
  late Database db;
  final now = DateTime(2026, 10, 25, 18);
  late SqliteTaskRepository tasks;
  late SqliteSessionRepository sessions;
  late StudyTask lab;
  late StudyTask calc;

  setUp(() async {
    db = await openTestDatabase();
    tasks = SqliteTaskRepository(db, clock: () => now);
    sessions = SqliteSessionRepository(db, clock: () => now);
    lab = await tasks.create(
      title: 'Lab 3 report',
      subject: 'Physics',
      priority: TaskPriority.high,
      estimatedMinutes: 60,
    );
    calc = await tasks.create(
      title: 'Calculus practice',
      subject: 'Calculus',
      priority: TaskPriority.medium,
      estimatedMinutes: 30,
    );
  });
  tearDown(() async => db.close());

  StudySession session(StudyTask task, DateTime startedAt, int minutes) =>
      StudySession(
        taskId: task.id!,
        startedAt: startedAt,
        endedAt: startedAt.add(Duration(minutes: minutes)),
        durationMinutes: minutes,
        status: SessionStatus.completed,
      );

  test('create links the session to its task and History lists it', () async {
    final saved = await sessions.create(session(lab, DateTime(2026, 10, 18, 9), 50));

    final records = await sessions.getRecords();
    expect(records.single.session, saved);
    expect(records.single.taskTitle, 'Lab 3 report');
    expect(records.single.subject, 'Physics');
  });

  test('create refuses invalid durations and future start times', () async {
    await expectLater(
        sessions.create(session(lab, DateTime(2026, 10, 18), 0)),
        throwsA(isA<ValidationException>()));
    await expectLater(
        sessions.create(session(lab, now.add(const Duration(hours: 1)), 30)),
        throwsA(isA<ValidationException>()));
    expect(await sessions.getRecords(), isEmpty);
  });

  test('create for a missing task reports the task is not found', () async {
    final orphan = session(lab, DateTime(2026, 10, 18), 30).copyWith(taskId: 999);
    await expectLater(
        sessions.create(orphan), throwsA(isA<RecordNotFoundException>()));
  });

  test('update corrects task, start time and duration', () async {
    final saved =
        await sessions.create(session(lab, DateTime(2026, 10, 18, 9), 50));
    final corrected = saved.corrected(
      taskId: calc.id,
      startedAt: DateTime(2026, 10, 18, 10),
      durationMinutes: 30,
    );

    await sessions.update(corrected);

    final stored = await sessions.getById(saved.id!);
    expect(stored, corrected);
    expect(stored!.endedAt, DateTime(2026, 10, 18, 10, 30));
    expect(stored.status, SessionStatus.manual);
    expect((await sessions.getRecords()).single.taskTitle, 'Calculus practice');
  });

  test('a stale end time is still refused if a caller bypasses corrected()',
      () async {
    final saved =
        await sessions.create(session(lab, DateTime(2026, 10, 18, 9), 50));
    await expectLater(
        sessions.update(saved.copyWith(startedAt: DateTime(2026, 10, 18, 11))),
        throwsA(isA<ValidationException>()));
  });

  test('update rejects a duration above 120 and keeps the old record',
      () async {
    final saved =
        await sessions.create(session(lab, DateTime(2026, 10, 18, 9), 50));
    await expectLater(sessions.update(saved.copyWith(durationMinutes: 121)),
        throwsA(isA<ValidationException>()));
    expect(await sessions.getById(saved.id!), saved);
  });

  test('delete removes one record and a second delete reports it missing',
      () async {
    final a = await sessions.create(session(lab, DateTime(2026, 10, 18), 20));
    await sessions.create(session(lab, DateTime(2026, 10, 19), 20));

    await sessions.delete(a.id!);
    expect(await sessions.getRecords(), hasLength(1));
    await expectLater(
        sessions.delete(a.id!), throwsA(isA<RecordNotFoundException>()));
  });

  group('History filters', () {
    setUp(() async {
      await sessions.create(session(lab, DateTime(2026, 10, 17, 9), 25));
      await sessions.create(session(calc, DateTime(2026, 10, 18, 9), 30));
      await sessions.create(session(lab, DateTime(2026, 10, 18, 14), 50));
    });

    test('no filter lists everything newest first', () async {
      final records = await sessions.getRecords();
      expect(records.map((r) => r.session.durationMinutes), [50, 30, 25]);
    });

    test('by task', () async {
      final records =
          await sessions.getRecords(SessionFilter(taskId: calc.id));
      expect(records.map((r) => r.taskTitle), ['Calculus practice']);
    });

    test('by subject', () async {
      final records =
          await sessions.getRecords(const SessionFilter(subject: 'Physics'));
      expect(records, hasLength(2));
    });

    test('by date range, start inclusive and end exclusive', () async {
      final records = await sessions.getRecords(SessionFilter(
        from: DateTime(2026, 10, 18),
        until: DateTime(2026, 10, 18, 14),
      ));
      expect(records.map((r) => r.session.durationMinutes), [30]);
    });

    test('filters combine', () async {
      final records = await sessions.getRecords(SessionFilter(
        subject: 'Physics',
        from: DateTime(2026, 10, 18),
      ));
      expect(records.map((r) => r.session.durationMinutes), [50]);
    });
  });

  test('minutesByTaskSince sums only sessions inside the window', () async {
    final since = now.subtract(const Duration(days: 7));
    await sessions.create(
        session(lab, now.subtract(const Duration(days: 6)), 40));
    await sessions.create(
        session(lab, now.subtract(const Duration(days: 1)), 20));
    await sessions.create(
        session(calc, now.subtract(const Duration(days: 8)), 90));

    expect(await sessions.minutesByTaskSince(since), {lab.id: 60});
  });

  test('deleting a task removes its sessions from History', () async {
    await sessions.create(session(lab, DateTime(2026, 10, 18), 25));
    await sessions.create(session(calc, DateTime(2026, 10, 18), 25));

    await tasks.delete(lab.id!);

    final records = await sessions.getRecords();
    expect(records.map((r) => r.taskTitle), ['Calculus practice']);
  });
}
