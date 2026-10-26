import '../validation/validation.dart';

/// Time of day for the daily reminder, independent of Flutter.
class ReminderTime {
  const ReminderTime(this.hour, this.minute)
      : assert(hour >= 0 && hour < 24),
        assert(minute >= 0 && minute < 60);

  /// From minutes since midnight; out-of-range values give null.
  static ReminderTime? fromMinutes(int minutes) {
    if (minutes < 0 || minutes >= 24 * 60) return null;
    return ReminderTime(minutes ~/ 60, minutes % 60);
  }

  final int hour;
  final int minute;

  int get minutesSinceMidnight => hour * 60 + minute;

  @override
  bool operator ==(Object other) =>
      other is ReminderTime && other.hour == hour && other.minute == minute;

  @override
  int get hashCode => Object.hash(hour, minute);

  @override
  String toString() => 'ReminderTime($hour:$minute)';
}

/// Preferences from the Settings screen, stored on the device.
class AppSettings {
  const AppSettings({
    this.sessionMinutes = defaultSessionMinutes,
    this.remindersEnabled = false,
    this.reminderTime = defaultReminderTime,
    this.reducedMotion = false,
  });

  static const defaultSessionMinutes = 25;
  static const defaultReminderTime = ReminderTime(19, 0);
  static const defaults = AppSettings();

  /// Focus session target, 5–120 minutes.
  final int sessionMinutes;
  final bool remindersEnabled;
  final ReminderTime reminderTime;

  /// Turns off non-essential animation in addition to the phone's own
  /// accessibility setting.
  final bool reducedMotion;

  bool get isValid => validateEstimatedMinutes(sessionMinutes) == null;

  AppSettings copyWith({
    int? sessionMinutes,
    bool? remindersEnabled,
    ReminderTime? reminderTime,
    bool? reducedMotion,
  }) {
    return AppSettings(
      sessionMinutes: sessionMinutes ?? this.sessionMinutes,
      remindersEnabled: remindersEnabled ?? this.remindersEnabled,
      reminderTime: reminderTime ?? this.reminderTime,
      reducedMotion: reducedMotion ?? this.reducedMotion,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is AppSettings &&
      other.sessionMinutes == sessionMinutes &&
      other.remindersEnabled == remindersEnabled &&
      other.reminderTime == reminderTime &&
      other.reducedMotion == reducedMotion;

  @override
  int get hashCode => Object.hash(
      sessionMinutes, remindersEnabled, reminderTime, reducedMotion);

  @override
  String toString() => 'AppSettings($sessionMinutes min, reminders '
      '$remindersEnabled at $reminderTime, reducedMotion $reducedMotion)';
}
