import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app.dart';
import 'data/database/app_database.dart';
import 'data/services/local_notification_service.dart';
import 'providers/core_providers.dart';
import 'providers/notification_providers.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final database = await AppDatabase.open();
  final notifications = LocalNotificationService();
  try {
    await notifications.initialize();
  } catch (_) {
    // Notifications are optional; the app works without them.
  }

  runApp(
    ProviderScope(
      // Failed loads show an error with a Retry button instead of retrying
      // silently in the background.
      retry: (_, __) => null,
      overrides: [
        databaseProvider.overrideWithValue(database),
        notificationServiceProvider.overrideWithValue(notifications),
      ],
      child: const FocusQuestApp(),
    ),
  );
}
