import '../models/app_settings.dart';

abstract interface class SettingsRepository {
  /// Saved settings; missing or invalid values fall back to the defaults.
  Future<AppSettings> load();

  /// Throws if the device storage refuses the write.
  Future<void> save(AppSettings settings);
}
