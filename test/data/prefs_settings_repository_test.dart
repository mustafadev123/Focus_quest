import 'package:flutter_test/flutter_test.dart';
import 'package:focus_quest/data/repositories/prefs_settings_repository.dart';
import 'package:focus_quest/domain/models/app_settings.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('nothing saved yet gives the documented defaults', () async {
    expect(await PrefsSettingsRepository().load(), AppSettings.defaults);
    expect(AppSettings.defaults.sessionMinutes, 25);
    expect(AppSettings.defaults.remindersEnabled, isFalse);
    expect(AppSettings.defaults.reminderTime, const ReminderTime(19, 0));
    expect(AppSettings.defaults.reducedMotion, isFalse);
  });

  test('saved settings survive a new repository, like an app restart',
      () async {
    const settings = AppSettings(
      sessionMinutes: 45,
      remindersEnabled: true,
      reminderTime: ReminderTime(7, 30),
      reducedMotion: true,
    );
    await PrefsSettingsRepository().save(settings);

    expect(await PrefsSettingsRepository().load(), settings);
  });

  test('uses the proposal key names', () async {
    await PrefsSettingsRepository()
        .save(const AppSettings(sessionMinutes: 30, remindersEnabled: true));
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getInt('session_minutes'), 30);
    expect(prefs.getBool('reminders_enabled'), isTrue);
  });

  test('invalid stored values fall back to defaults instead of failing',
      () async {
    SharedPreferences.setMockInitialValues({
      'session_minutes': 200,
      'reminder_minutes': -5,
      'reduced_motion': true,
    });
    final loaded = await PrefsSettingsRepository().load();
    expect(loaded.sessionMinutes, 25);
    expect(loaded.reminderTime, const ReminderTime(19, 0));
    expect(loaded.reducedMotion, isTrue);
  });

  test('refuses to save a focus duration outside 5–120', () async {
    expect(
        () => PrefsSettingsRepository()
            .save(const AppSettings(sessionMinutes: 4)),
        throwsArgumentError);
  });

  test('the theme choice is saved and an unknown value means System', () async {
    await PrefsSettingsRepository()
        .save(const AppSettings(themeMode: AppThemeMode.dark));
    expect(
        (await PrefsSettingsRepository().load()).themeMode, AppThemeMode.dark);

    SharedPreferences.setMockInitialValues({'theme_mode': 'sepia'});
    expect((await PrefsSettingsRepository().load()).themeMode,
        AppThemeMode.system);
  });

  test('reminder time converts to and from minutes since midnight', () {
    expect(const ReminderTime(19, 5).minutesSinceMidnight, 1145);
    expect(ReminderTime.fromMinutes(1145), const ReminderTime(19, 5));
    expect(ReminderTime.fromMinutes(24 * 60), isNull);
  });
}
