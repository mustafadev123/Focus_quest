import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'presentation/shell/home_shell.dart';
import 'presentation/theme.dart';
import 'providers/notification_providers.dart';
import 'providers/settings_providers.dart';

class FocusQuestApp extends ConsumerStatefulWidget {
  const FocusQuestApp({super.key});

  @override
  ConsumerState<FocusQuestApp> createState() => _FocusQuestAppState();
}

class _FocusQuestAppState extends ConsumerState<FocusQuestApp> {
  late final AppLifecycleListener _lifecycle;

  @override
  void initState() {
    super.initState();
    // The student may allow or block notifications in phone settings while
    // the app is in the background, so check again on return.
    _lifecycle = AppLifecycleListener(
      onResume: () => ref.invalidate(notificationsAllowedProvider),
    );
  }

  @override
  void dispose() {
    _lifecycle.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Keep scheduled notifications in step with settings and the session.
    ref.watch(reminderSyncProvider);
    ref.watch(sessionAlertSyncProvider);
    final reducedMotion = ref.watch(effectiveSettingsProvider).reducedMotion;

    return MaterialApp(
      title: 'FocusQuest',
      debugShowCheckedModeBanner: false,
      theme: buildFocusQuestTheme(),
      // The in-app Reduced motion setting joins the phone's own setting, so
      // every animation that checks disableAnimations honours either one.
      builder: (context, child) {
        final media = MediaQuery.of(context);
        return MediaQuery(
          data: media.copyWith(
              disableAnimations: media.disableAnimations || reducedMotion),
          child: child!,
        );
      },
      home: const HomeShell(),
    );
  }
}
