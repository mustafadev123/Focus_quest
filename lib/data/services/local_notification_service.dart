import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

import '../../domain/models/app_settings.dart';
import '../../domain/services/notification_service.dart';

/// Android notifications through flutter_local_notifications.
///
/// Times are scheduled as UTC instants computed from local time. The daily
/// reminder repeats at the same UTC time, so it is rescheduled at every
/// launch and settings change to follow daylight-saving changes. Scheduling
/// is inexact, so no exact-alarm permission is needed; an alert may arrive
/// a little late on a sleeping phone.
class LocalNotificationService implements NotificationService {
  LocalNotificationService([FlutterLocalNotificationsPlugin? plugin])
      : _plugin = plugin ?? FlutterLocalNotificationsPlugin();

  final FlutterLocalNotificationsPlugin _plugin;

  static const _reminderId = 1;
  static const _sessionEndId = 2;
  static const _settingsChannel = MethodChannel('focus_quest/settings');

  static const _reminderDetails = NotificationDetails(
    android: AndroidNotificationDetails(
      'study_reminders',
      'Study reminders',
      channelDescription: 'Daily reminder to start a focus session',
    ),
  );
  static const _sessionDetails = NotificationDetails(
    android: AndroidNotificationDetails(
      'session_end',
      'Session-end alerts',
      channelDescription: 'Tells you when a focus session reaches its target',
      importance: Importance.high,
      priority: Priority.high,
    ),
  );

  AndroidFlutterLocalNotificationsPlugin? get _android =>
      _plugin.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();

  Future<void> initialize() async {
    tz_data.initializeTimeZones();
    await _plugin.initialize(
      settings: const InitializationSettings(
        // Monochrome status-bar icon; the full-colour logo would show as a
        // plain square.
        android: AndroidInitializationSettings('@drawable/ic_notification'),
      ),
    );
  }

  @override
  Future<bool> areEnabled() async =>
      await _android?.areNotificationsEnabled() ?? false;

  @override
  Future<bool> requestPermission() async =>
      await _android?.requestNotificationsPermission() ?? false;

  @override
  Future<void> scheduleDailyReminder(ReminderTime time) {
    return _plugin.zonedSchedule(
      id: _reminderId,
      scheduledDate:
          tz.TZDateTime.from(nextReminderAt(time, DateTime.now()), tz.UTC),
      notificationDetails: _reminderDetails,
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      title: 'Time to study',
      body: 'Open FocusQuest and start a focus session.',
      matchDateTimeComponents: DateTimeComponents.time,
    );
  }

  @override
  Future<void> cancelDailyReminder() => _plugin.cancel(id: _reminderId);

  @override
  Future<void> scheduleSessionEnd({
    required DateTime at,
    required String taskTitle,
    required int minutes,
  }) {
    return _plugin.zonedSchedule(
      id: _sessionEndId,
      scheduledDate: tz.TZDateTime.from(at, tz.UTC),
      notificationDetails: _sessionDetails,
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      title: 'Focus session complete',
      body: '$taskTitle reached $minutes minutes. '
          'Open FocusQuest to review and save it.',
    );
  }

  @override
  Future<void> cancelSessionEnd() => _plugin.cancel(id: _sessionEndId);

  @override
  Future<void> openSystemSettings() =>
      _settingsChannel.invokeMethod<void>('openNotificationSettings');
}
