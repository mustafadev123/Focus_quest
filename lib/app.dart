import 'package:flutter/material.dart';

import 'presentation/shell/home_shell.dart';
import 'presentation/theme.dart';

class FocusQuestApp extends StatelessWidget {
  const FocusQuestApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'FocusQuest',
      debugShowCheckedModeBanner: false,
      theme: buildFocusQuestTheme(),
      home: const HomeShell(),
    );
  }
}
