import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'presentation/shell/home_shell.dart';
import 'presentation/theme.dart';
import 'providers/settings_providers.dart';

class FocusQuestApp extends ConsumerWidget {
  const FocusQuestApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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
