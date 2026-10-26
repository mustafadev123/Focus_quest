import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/repositories/prefs_settings_repository.dart';
import '../domain/models/app_settings.dart';
import '../domain/repositories/settings_repository.dart';

final settingsRepositoryProvider =
    Provider<SettingsRepository>((ref) => PrefsSettingsRepository());

/// Saved settings shared by every screen.
class SettingsNotifier extends AsyncNotifier<AppSettings> {
  @override
  Future<AppSettings> build() => ref.watch(settingsRepositoryProvider).load();

  /// Errors propagate so the Settings screen can keep the user's edits.
  Future<void> save(AppSettings settings) async {
    await ref.read(settingsRepositoryProvider).save(settings);
    if (ref.mounted) state = AsyncData(settings);
  }
}

final settingsProvider =
    AsyncNotifierProvider<SettingsNotifier, AppSettings>(SettingsNotifier.new);

/// The saved settings, or the defaults while loading or if loading failed,
/// for features that must keep working either way.
final effectiveSettingsProvider = Provider<AppSettings>(
  (ref) => ref.watch(settingsProvider).value ?? AppSettings.defaults,
);
