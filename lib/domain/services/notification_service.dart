import '../models/app_settings.dart';

/// Local notifications, behind an interface so the rest of the app and the
/// tests never depend on the platform plugin.
abstract interface class NotificationService {
  /// Whether the system currently allows FocusQuest to notify.
  Future<bool> areEnabled();

  /// Asks the system for permission; returns whether it is granted.
  Future<bool> requestPermission();

  /// Replaces the daily study reminder.
  Future<void> scheduleDailyReminder(ReminderTime time);

  Future<void> cancelDailyReminder();

  /// Replaces the alert for the running session, shown at [at].
  Future<void> scheduleSessionEnd({
    required DateTime at,
    required String taskTitle,
    required int minutes,
  });

  Future<void> cancelSessionEnd();

  /// Opens the phone's notification settings for FocusQuest.
  Future<void> openSystemSettings();
}

/// The next time [time] occurs after [now], today or tomorrow, local time.
DateTime nextReminderAt(ReminderTime time, DateTime now) {
  final today = DateTime(now.year, now.month, now.day, time.hour, time.minute);
  return today.isAfter(now)
      ? today
      : DateTime(now.year, now.month, now.day + 1, time.hour, time.minute);
}
