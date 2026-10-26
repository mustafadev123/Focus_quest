import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:focus_quest/presentation/shell/home_shell.dart';

import '../support/test_app.dart';

void main() {
  testWidgets('starts on the Dashboard with four labelled destinations',
      (tester) async {
    await pumpTestApp(tester);

    expect(find.text('FocusQuest'), findsOneWidget);
    for (final label in ['Tasks', 'Focus', 'History', 'Settings']) {
      expect(
        find.descendant(
          of: find.byType(NavigationBar),
          matching: find.text(label),
        ),
        findsOneWidget,
      );
    }
  });

  testWidgets('tapping a destination shows that screen', (tester) async {
    await pumpTestApp(tester);

    await tester.tap(find.text('History'));
    await tester.pumpAndSettle();
    expect(find.text('History and Insights'), findsOneWidget);
    expect(find.text('FocusQuest'), findsNothing);

    await tester.tap(find.text('Settings'));
    await tester.pumpAndSettle();
    expect(
      find.descendant(of: find.byType(AppBar), matching: find.text('Settings')),
      findsOneWidget,
    );
  });

  testWidgets('other screens can switch tabs through the provider',
      (tester) async {
    final container = await pumpTestApp(tester);

    container.read(selectedTabProvider.notifier).select(AppTab.focus);
    await tester.pumpAndSettle();

    expect(find.text('Focus Session'), findsOneWidget);
    final bar = tester.widget<NavigationBar>(find.byType(NavigationBar));
    expect(bar.selectedIndex, AppTab.focus.index);
  });

  testWidgets('navigation stays usable at 2x text scale in landscape',
      (tester) async {
    tester.view.physicalSize = const Size(1600, 800);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

    await pumpTestApp(tester);
    await tester.tap(find.text('History'));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('History and Insights'), findsOneWidget);
  });
}
