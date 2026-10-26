import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app.dart';
import 'data/database/app_database.dart';
import 'providers/core_providers.dart';
import 'screens/focus_session_screen.dart';
import 'screens/history_screen.dart';
import 'screens/recommendation_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final database = await AppDatabase.open();

  runApp(
    ProviderScope(
      retry: (_, __) => null,
      overrides: [databaseProvider.overrideWithValue(database)],
      child: const FocusQuestApp(),
    ),
  );
}

class FocusQuestNavigation extends StatefulWidget {
  const FocusQuestNavigation({super.key});

  @override
  State<FocusQuestNavigation> createState() =>
      _FocusQuestNavigationState();
}

class _FocusQuestNavigationState extends State<FocusQuestNavigation> {
  int _selectedIndex = 0;

  static const List<Widget> _screens = [
    FocusSessionScreen(),
    HistoryScreen(),
    RecommendationScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _screens[_selectedIndex],
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        onDestinationSelected: (index) {
          setState(() => _selectedIndex = index);
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.timer_outlined),
            selectedIcon: Icon(Icons.timer),
            label: 'Focus',
          ),
          NavigationDestination(
            icon: Icon(Icons.history),
            selectedIcon: Icon(Icons.history_rounded),
            label: 'History',
          ),
          NavigationDestination(
            icon: Icon(Icons.lightbulb_outline),
            selectedIcon: Icon(Icons.lightbulb),
            label: 'Smart Helper',
          ),
        ],
      ),
    );
  }
}