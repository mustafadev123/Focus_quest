import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app.dart';
import 'data/database/app_database.dart';
import 'providers/core_providers.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final database = await AppDatabase.open();

  runApp(
    ProviderScope(
      // Failed loads show an error with a Retry button instead of retrying
      // silently in the background.
      retry: (_, __) => null,
      overrides: [databaseProvider.overrideWithValue(database)],
      child: const FocusQuestApp(),
    ),
  );
}
