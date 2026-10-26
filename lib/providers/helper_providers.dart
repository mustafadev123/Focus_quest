import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/helper/smart_helper.dart';
import 'core_providers.dart';
import 'settings_providers.dart';
import 'task_providers.dart';

/// "Available time" on the Suggested-task card; starts at the focus
/// duration from Settings.
class AvailableMinutesNotifier extends Notifier<int> {
  @override
  int build() => ref.watch(effectiveSettingsProvider).sessionMinutes;

  void set(int minutes) => state = minutes;
}

final availableMinutesProvider =
    NotifierProvider<AvailableMinutesNotifier, int>(
        AvailableMinutesNotifier.new);

/// The helper's recommendation for the current tasks, available time and
/// the last seven days of saved sessions. Recomputed after every change.
final recommendationProvider = FutureProvider<HelperResult>((ref) async {
  ref.watch(dataRevisionProvider);
  final tasks = await ref.watch(tasksProvider.future);
  final available = ref.watch(availableMinutesProvider);
  final now = ref.watch(clockProvider)();
  final recent = await ref
      .watch(sessionRepositoryProvider)
      .minutesByTaskSince(now.subtract(SmartHelper.recentWindow));
  return SmartHelper.recommend(
    tasks: tasks,
    availableMinutes: available,
    recentMinutesByTask: recent,
  );
});
