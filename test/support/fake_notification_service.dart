import 'package:focus_quest/domain/models/app_settings.dart';
import 'package:focus_quest/domain/services/notification_service.dart';

/// Records what would be scheduled, without any platform plugin.
class FakeNotificationService implements NotificationService {
  FakeNotificationService({this.allowed = false, this.grantOnRequest = true});

  bool allowed;

  /// What the "system" answers when permission is requested.
  bool grantOnRequest;

  int permissionRequests = 0;
  int settingsOpened = 0;
  ReminderTime? dailyReminder;
  ({DateTime at, String taskTitle, int minutes})? sessionEnd;

  @override
  Future<bool> areEnabled() async => allowed;

  @override
  Future<bool> requestPermission() async {
    permissionRequests++;
    allowed = grantOnRequest;
    return allowed;
  }

  @override
  Future<void> scheduleDailyReminder(ReminderTime time) async =>
      dailyReminder = time;

  @override
  Future<void> cancelDailyReminder() async => dailyReminder = null;

  @override
  Future<void> scheduleSessionEnd({
    required DateTime at,
    required String taskTitle,
    required int minutes,
  }) async =>
      sessionEnd = (at: at, taskTitle: taskTitle, minutes: minutes);

  @override
  Future<void> cancelSessionEnd() async => sessionEnd = null;

  @override
  Future<void> openSystemSettings() async => settingsOpened++;
}
