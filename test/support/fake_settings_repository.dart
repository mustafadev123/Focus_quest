import 'package:focus_quest/domain/models/app_settings.dart';
import 'package:focus_quest/domain/repositories/settings_repository.dart';

/// In-memory [SettingsRepository] that can be told to fail.
class FakeSettingsRepository implements SettingsRepository {
  FakeSettingsRepository([this.stored = AppSettings.defaults]);

  AppSettings stored;
  Object? failNextSave;
  Object? failNextLoad;

  @override
  Future<AppSettings> load() async {
    final error = failNextLoad;
    if (error != null) {
      failNextLoad = null;
      throw error;
    }
    return stored;
  }

  @override
  Future<void> save(AppSettings settings) async {
    final error = failNextSave;
    if (error != null) {
      failNextSave = null;
      throw error;
    }
    stored = settings;
  }
}
