import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:focus_quest/data/database/app_database.dart';
import 'package:focus_quest/data/repositories/sqlite_task_repository.dart';
import 'package:focus_quest/domain/focus/focus_session.dart';
import 'package:focus_quest/domain/models/study_task.dart';
import 'package:focus_quest/providers/core_providers.dart';
import 'package:focus_quest/providers/dashboard_providers.dart';
import 'package:focus_quest/providers/focus_providers.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../support/test_database.dart';

void main() {
  late Directory dir;
  late String path;
  late DateTime now;
  late int taskId;
  final opened = <Database>[];

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('focus_quest_focus');
    path = p.join(dir.path, AppDatabase.fileName);
    now = DateTime(2026, 10, 25, 18);

    final db = await openTestDatabase(path: path);
    final task = await SqliteTaskRepository(db, clock: () => now).create(
      title: 'Review recursion notes',
      subject: 'Data Structures',
      priority: TaskPriority.high,
      estimatedMinutes: 25,
    );
    taskId = task.id!;
    await db.close();
  });

  tearDown(() async {
    for (final db in opened) {
      await db.close();
    }
    opened.clear();
    // Windows cannot delete the folder while a database file is open.
    await dir.delete(recursive: true);
  });

  /// A fresh container on the same database file, like an app launch.
  Future<ProviderContainer> launch() async {
    final db = await openTestDatabase(path: path);
    opened.add(db);
    final container = ProviderContainer(
      retry: (_, __) => null,
      overrides: [
        databaseProvider.overrideWithValue(db),
        clockProvider.overrideWithValue(() => now),
      ],
    );
    addTearDown(container.dispose);
    container.listen(focusControllerProvider, (_, __) {});
    return container;
  }

  Future<FocusSession> session(ProviderContainer c) =>
      c.read(focusControllerProvider.future);

  FocusController controller(ProviderContainer c) =>
      c.read(focusControllerProvider.notifier);

  Future<int> recordCount() async {
    final db = await openTestDatabase(path: path);
    opened.add(db);
    final rows = await db.rawQuery('SELECT COUNT(*) AS n FROM study_sessions');
    return rows.single['n'] as int;
  }

  test('starts Ready for the task selected on the Dashboard', () async {
    final app = await launch();
    expect((await session(app)).taskId, isNull);

    app.read(selectedTaskIdProvider.notifier).select(taskId);
    final ready = await session(app);
    expect(ready.phase, FocusPhase.ready);
    expect(ready.taskId, taskId);
    expect(ready.target, const Duration(minutes: defaultFocusMinutes));
  });

  test('a running session is restored after a restart and keeps counting',
      () async {
    final first = await launch();
    first.read(selectedTaskIdProvider.notifier).select(taskId);
    await session(first);
    await controller(first).start();
    now = now.add(const Duration(minutes: 5));
    first.dispose();

    now = now.add(const Duration(minutes: 3));
    final second = await launch();
    final restored = await session(second);
    expect(restored.phase, FocusPhase.running);
    expect(restored.taskId, taskId);
    expect(restored.activeAt(now), const Duration(minutes: 8));
  });

  test('paused time stays excluded across a restart', () async {
    final first = await launch();
    first.read(selectedTaskIdProvider.notifier).select(taskId);
    await session(first);
    await controller(first).start();
    now = now.add(const Duration(minutes: 4));
    await controller(first).pause();
    first.dispose();

    now = now.add(const Duration(hours: 2));
    final second = await launch();
    final restored = await session(second);
    expect(restored.phase, FocusPhase.paused);
    expect(restored.activeAt(now), const Duration(minutes: 4));
  });

  test('a session awaiting save survives a restart and saves once', () async {
    final first = await launch();
    first.read(selectedTaskIdProvider.notifier).select(taskId);
    await session(first);
    await controller(first).start();
    now = now.add(const Duration(minutes: 10));
    await controller(first).finish();
    first.dispose();

    final second = await launch();
    expect((await session(second)).phase, FocusPhase.awaitingSave);
    final record = await controller(second).save();
    expect(record!.durationMinutes, 10);
    expect((await session(second)).phase, FocusPhase.saved);
    expect(await recordCount(), 1);
  });

  test('concurrent and repeated saves create one record', () async {
    final app = await launch();
    app.read(selectedTaskIdProvider.notifier).select(taskId);
    await session(app);
    await controller(app).start();
    now = now.add(const Duration(minutes: 7));
    await controller(app).finish();

    final revision = app.read(dataRevisionProvider);
    await Future.wait([controller(app).save(), controller(app).save()]);
    await controller(app).save();

    expect(await recordCount(), 1);
    expect(app.read(dataRevisionProvider), revision + 1);
  });

  test('the target being reached opens the review but does not save', () async {
    final app = await launch();
    app.read(selectedTaskIdProvider.notifier).select(taskId);
    await session(app);
    await controller(app).start();

    now = now.add(const Duration(minutes: 24));
    expect(await controller(app).finishIfTargetReached(), isFalse);
    now = now.add(const Duration(minutes: 2));
    expect(await controller(app).finishIfTargetReached(), isTrue);

    expect((await session(app)).phase, FocusPhase.awaitingSave);
    expect(await recordCount(), 0);
  });

  test('Reset discards the checkpoint so nothing is restored', () async {
    final first = await launch();
    first.read(selectedTaskIdProvider.notifier).select(taskId);
    await session(first);
    await controller(first).start();
    await controller(first).reset();
    expect((await session(first)).phase, FocusPhase.ready);
    first.dispose();

    final second = await launch();
    expect((await session(second)).phase, FocusPhase.ready);
    expect(await recordCount(), 0);
  });

  test('choosing another task is ignored while a session is running', () async {
    final app = await launch();
    app.read(selectedTaskIdProvider.notifier).select(taskId);
    await session(app);
    await controller(app).start();

    controller(app).selectTask(999);
    expect(app.read(selectedTaskIdProvider), taskId);
    expect((await session(app)).taskId, taskId);
  });
}
