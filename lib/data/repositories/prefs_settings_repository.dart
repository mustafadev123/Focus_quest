import 'package:shared_preferences/shared_preferences.dart';

import '../../domain/models/app_settings.dart';
import '../../domain/repositories/settings_repository.dart';
import '../../domain/validation/validation.dart';

/// Stores settings in SharedPreferences using the keys from proposal
/// Section 8, plus the reminder time and reduced-motion choice from the
/// Settings wireframe.
class PrefsSettingsRepository implements SettingsRepository {
  PrefsSettingsRepository({Future<SharedPreferences> Function()? prefs})
      : _prefs = prefs ?? SharedPreferences.getInstance;

  final Future<SharedPreferences> Function() _prefs;

  static const sessionMinutesKey = 'session_minutes';
  static const remindersEnabledKey = 'reminders_enabled';
  static const reminderMinutesKey = 'reminder_minutes';
  static const reducedMotionKey = 'reduced_motion';
  static const themeModeKey = 'theme_mode';

  @override
  Future<AppSettings> load() async {
    final prefs = await _prefs();
    const d = AppSettings.defaults;

    final minutes = prefs.getInt(sessionMinutesKey);
    final reminder = prefs.getInt(reminderMinutesKey);
    return AppSettings(
      sessionMinutes:
          minutes != null && validateEstimatedMinutes(minutes) == null
              ? minutes
              : d.sessionMinutes,
      remindersEnabled:
          prefs.getBool(remindersEnabledKey) ?? d.remindersEnabled,
      reminderTime:
          (reminder == null ? null : ReminderTime.fromMinutes(reminder)) ??
              d.reminderTime,
      reducedMotion: prefs.getBool(reducedMotionKey) ?? d.reducedMotion,
      themeMode:
          AppThemeMode.fromName(prefs.getString(themeModeKey)) ?? d.themeMode,
    );
  }

  @override
  Future<void> save(AppSettings settings) async {
    if (!settings.isValid) {
      throw ArgumentError.value(settings, 'settings', 'Invalid settings');
    }
    final prefs = await _prefs();
    final results = await Future.wait([
      prefs.setInt(sessionMinutesKey, settings.sessionMinutes),
      prefs.setBool(remindersEnabledKey, settings.remindersEnabled),
      prefs.setInt(
          reminderMinutesKey, settings.reminderTime.minutesSinceMidnight),
      prefs.setBool(reducedMotionKey, settings.reducedMotion),
      prefs.setString(themeModeKey, settings.themeMode.name),
    ]);
    if (results.contains(false)) {
      throw StateError('Device storage refused the settings');
    }
  }
}
