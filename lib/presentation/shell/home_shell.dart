import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../dashboard/dashboard_screen.dart';
import '../focus/focus_screen.dart';
import '../history/history_screen.dart';
import '../settings/settings_screen.dart';

/// Bottom-navigation destinations shown in every wireframe.
enum AppTab { tasks, focus, history, settings }

class SelectedTabNotifier extends Notifier<AppTab> {
  @override
  AppTab build() => AppTab.tasks;

  void select(AppTab tab) => state = tab;
}

/// Shared so other screens can switch tabs, for example the Dashboard's
/// Focus button or saving a session, which opens History.
final selectedTabProvider =
    NotifierProvider<SelectedTabNotifier, AppTab>(SelectedTabNotifier.new);

class HomeShell extends ConsumerWidget {
  const HomeShell({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tab = ref.watch(selectedTabProvider);

    return Scaffold(
      body: IndexedStack(
        index: tab.index,
        children: const [
          DashboardScreen(),
          FocusScreen(),
          HistoryScreen(),
          SettingsScreen(),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: tab.index,
        onDestinationSelected: (index) =>
            ref.read(selectedTabProvider.notifier).select(AppTab.values[index]),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.format_list_bulleted),
            label: 'Tasks',
          ),
          NavigationDestination(
            icon: Icon(Icons.play_arrow_outlined),
            label: 'Focus',
          ),
          NavigationDestination(
            icon: Icon(Icons.bar_chart),
            label: 'History',
          ),
          NavigationDestination(
            icon: Icon(Icons.settings_outlined),
            label: 'Settings',
          ),
        ],
      ),
    );
  }
}
