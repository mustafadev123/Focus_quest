import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/models/study_task.dart';
import '../domain/repositories/task_repository.dart';
import '../providers/dashboard_providers.dart';
import '../providers/focus_providers.dart';
import '../providers/task_providers.dart';

const _activeTaskMessage =
    'Finish or reset the focus session for this task before deleting it.';

/// The delete flow shared by the task menu, swipe-to-delete and the Edit
/// screen: refuse while the task has an unsaved focus session, confirm with
/// the number of sessions that go with it, then delete.
///
/// Returns true if the task was deleted.
Future<bool> confirmAndDeleteTask(
  BuildContext context,
  WidgetRef ref,
  StudyTask task,
) async {
  final messenger = ScaffoldMessenger.of(context);
  void say(String text) =>
      messenger.showSnackBar(SnackBar(content: Text(text)));

  final session = ref.read(focusControllerProvider).value;
  if (session != null && session.isInProgress && session.taskId == task.id) {
    say(_activeTaskMessage);
    return false;
  }

  final notifier = ref.read(tasksProvider.notifier);
  final int sessions;
  try {
    sessions = await notifier.countSessions(task.id!);
  } catch (_) {
    say("Couldn't delete the task. Try again.");
    return false;
  }
  if (!context.mounted) return false;

  final confirmed = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Delete this task?'),
      content: Text(
        sessions == 0
            ? "This can't be undone."
            : "This also deletes $sessions saved "
                "${sessions == 1 ? 'session' : 'sessions'}. "
                "This can't be undone.",
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(true),
          child: const Text('Delete'),
        ),
      ],
    ),
  );
  if (confirmed != true) return false;

  try {
    await notifier.delete(task.id!);
  } on ActiveTaskDeletionException {
    say(_activeTaskMessage);
    return false;
  } catch (_) {
    say("Couldn't delete the task. Try again.");
    return false;
  }

  if (ref.read(selectedTaskIdProvider) == task.id) {
    ref.read(selectedTaskIdProvider.notifier).select(null);
  }
  say('Task deleted');
  return true;
}
