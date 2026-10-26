import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/aggregates.dart';
import '../domain/models/study_task.dart';
import '../domain/repositories/session_repository.dart';
import 'core_providers.dart';
import 'task_providers.dart';

/// Task chosen for the next focus session. Selecting only preselects it;
/// a session starts only when the user presses Start.
class SelectedTaskNotifier extends Notifier<int?> {
  @override
  int? build() => null;

  void select(int? taskId) => state = taskId;
}

final selectedTaskIdProvider =
    NotifierProvider<SelectedTaskNotifier, int?>(SelectedTaskNotifier.new);

/// Dashboard "Status" filter; null means All.
class StatusFilterNotifier extends Notifier<TaskStatus?> {
  @override
  TaskStatus? build() => null;

  void set(TaskStatus? status) => state = status;
}

final statusFilterProvider =
    NotifierProvider<StatusFilterNotifier, TaskStatus?>(
        StatusFilterNotifier.new);

final visibleTasksProvider = Provider<AsyncValue<List<StudyTask>>>((ref) {
  final filter = ref.watch(statusFilterProvider);
  return ref.watch(tasksProvider).whenData((tasks) => filter == null
      ? tasks
      : tasks.where((t) => t.status == filter).toList());
});

/// Minutes studied since Monday 00:00 of the current week.
final weeklyStudyMinutesProvider = FutureProvider<int>((ref) async {
  ref.watch(dataRevisionProvider);
  final now = ref.watch(clockProvider)();
  final records = await ref
      .watch(sessionRepositoryProvider)
      .getRecords(SessionFilter(from: startOfWeek(now)));
  return totalMinutes(records);
});
