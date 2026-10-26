import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sqflite/sqflite.dart';

import '../data/repositories/sqlite_session_repository.dart';
import '../data/repositories/sqlite_task_repository.dart';
import '../domain/clock.dart';
import '../domain/repositories/session_repository.dart';
import '../domain/repositories/task_repository.dart';

/// Opened in `main` before the app starts and supplied as an override.
final databaseProvider = Provider<Database>(
  (ref) => throw UnimplementedError('databaseProvider must be overridden'),
);

final clockProvider = Provider<Clock>((ref) => systemClock);

/// Tests override these with fakes.
final taskRepositoryProvider = Provider<TaskRepository>(
  (ref) => SqliteTaskRepository(
    ref.watch(databaseProvider),
    clock: ref.watch(clockProvider),
  ),
);

final sessionRepositoryProvider = Provider<SessionRepository>(
  (ref) => SqliteSessionRepository(
    ref.watch(databaseProvider),
    clock: ref.watch(clockProvider),
  ),
);

/// Increments after every successful write to tasks or sessions.
///
/// Read providers watch it, so the Dashboard, History and Focus Session
/// screens all refresh after a change made on any screen.
class DataRevisionNotifier extends Notifier<int> {
  @override
  int build() => 0;

  void bump() => state++;
}

final dataRevisionProvider =
    NotifierProvider<DataRevisionNotifier, int>(DataRevisionNotifier.new);
