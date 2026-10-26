import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/services/notification_service.dart';
import 'core_providers.dart';
import 'focus_providers.dart';
import 'settings_providers.dart';
import 'task_providers.dart';

/// Initialised in `main` and supplied as an override; tests use a fake.
final notificationServiceProvider = Provider<NotificationService>(
  (ref) => throw UnimplementedError('notificationServiceProvider override'),
);

/// Whether the phone currently allows FocusQuest notifications. Refreshed
/// after a permission request and whenever the app returns to the
/// foreground, since the student may change it in phone settings.
final notificationsAllowedProvider = FutureProvider<bool>(
    (ref) => ref.watch(notificationServiceProvider).areEnabled());

/// Notifications are optional, so a platform failure must never break the
/// rest of the app.
void _quietly(Future<void> Function() action) {
  unawaited(action().catchError((Object _) {}));
}

/// Keeps the daily reminder in step with Settings and the permission.
final reminderSyncProvider = Provider<void>((ref) {
  final settings = ref.watch(settingsProvider).value;
  if (settings == null) return; // keep whatever is scheduled until loaded
  final allowed = ref.watch(notificationsAllowedProvider).value ?? false;
  final service = ref.watch(notificationServiceProvider);

  _quietly(() => settings.remindersEnabled && allowed
      ? service.scheduleDailyReminder(settings.reminderTime)
      : service.cancelDailyReminder());
});

/// Schedules the session-end alert while a session runs and cancels it on
/// pause, reset, finish or save. Opted into with the Daily reminder switch.
final sessionAlertSyncProvider = Provider<void>((ref) {
  final settings = ref.watch(settingsProvider).value;
  final session = ref.watch(focusControllerProvider).value;
  if (settings == null || session == null) return;
  final allowed = ref.watch(notificationsAllowedProvider).value ?? false;
  final tasks = ref.watch(tasksProvider).value ?? const [];
  final service = ref.watch(notificationServiceProvider);
  final now = ref.read(clockProvider)();

  final at = session.targetReachedAt;
  if (!settings.remindersEnabled ||
      !allowed ||
      at == null ||
      !at.isAfter(now)) {
    _quietly(service.cancelSessionEnd);
    return;
  }
  final title = tasks
          .where((t) => t.id == session.taskId)
          .map((t) => t.title)
          .firstOrNull ??
      'Your task';
  _quietly(() => service.scheduleSessionEnd(
        at: at,
        taskTitle: title,
        minutes: session.target.inMinutes,
      ));
});
