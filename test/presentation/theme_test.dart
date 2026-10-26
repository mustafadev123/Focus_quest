import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:focus_quest/domain/models/app_settings.dart';
import 'package:focus_quest/presentation/shell/home_shell.dart';
import 'package:focus_quest/presentation/theme.dart';

import '../support/fake_settings_repository.dart';
import '../support/test_app.dart';

/// WCAG contrast ratio between two opaque colours.
double _contrast(Color a, Color b) {
  final la = a.computeLuminance();
  final lb = b.computeLuminance();
  final hi = la > lb ? la : lb;
  final lo = la > lb ? lb : la;
  return (hi + 0.05) / (lo + 0.05);
}

Brightness _brightness(WidgetTester tester) =>
    Theme.of(tester.element(find.byType(HomeShell))).brightness;

void main() {
  for (final (name, scheme) in [('light', lightScheme), ('dark', darkScheme)]) {
    test('$name scheme keeps text and control contrast', () {
      // Text needs 4.5:1; outlines of controls need 3:1.
      expect(_contrast(scheme.onSurface, scheme.surface), greaterThan(4.5));
      expect(
          _contrast(scheme.onSurfaceVariant, scheme.surface), greaterThan(4.5));
      expect(_contrast(scheme.onPrimary, scheme.primary), greaterThan(4.5));
      expect(_contrast(scheme.error, scheme.surface), greaterThan(4.5));
      expect(_contrast(scheme.onErrorContainer, scheme.errorContainer),
          greaterThan(4.5));
      expect(_contrast(scheme.onInverseSurface, scheme.inverseSurface),
          greaterThan(4.5));
      expect(_contrast(scheme.outline, scheme.surface), greaterThan(3));
      expect(_contrast(scheme.onSurface, scheme.surfaceContainerHigh),
          greaterThan(4.5));
    });
  }

  testWidgets('System follows the phone setting', (tester) async {
    tester.platformDispatcher.platformBrightnessTestValue = Brightness.dark;
    addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);

    await pumpTestApp(tester);
    expect(_brightness(tester), Brightness.dark);
  });

  testWidgets('Light and Dark override the phone setting', (tester) async {
    tester.platformDispatcher.platformBrightnessTestValue = Brightness.dark;
    addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);

    await pumpTestApp(tester,
        settings: FakeSettingsRepository(
            const AppSettings(themeMode: AppThemeMode.light)));
    expect(_brightness(tester), Brightness.light);
  });

  testWidgets('choosing Dark in Settings and saving switches the app',
      (tester) async {
    final settings = FakeSettingsRepository();
    final container = await pumpTestApp(tester, settings: settings);
    container.read(selectedTabProvider.notifier).select(AppTab.settings);
    await tester.pumpAndSettle();
    expect(_brightness(tester), Brightness.light);

    await tester.scrollUntilVisible(find.text('Dark'), 200,
        scrollable: find.byType(Scrollable).first);
    await tester.tap(find.text('Dark'));
    await tester.pumpAndSettle();
    expect(_brightness(tester), Brightness.light, reason: 'not saved yet');

    await tester.scrollUntilVisible(find.text('Save settings'), 200,
        scrollable: find.byType(Scrollable).first);
    await tester.tap(find.text('Save settings'));
    await tester.pumpAndSettle();

    expect(settings.stored.themeMode, AppThemeMode.dark);
    expect(_brightness(tester), Brightness.dark);
    expect(
        Theme.of(tester.element(find.byType(HomeShell)))
            .scaffoldBackgroundColor,
        darkScheme.surface);
  });

  testWidgets('every tab renders in dark mode at 2x text scale',
      (tester) async {
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    final container = await pumpTestApp(tester,
        settings: FakeSettingsRepository(
            const AppSettings(themeMode: AppThemeMode.dark)));

    for (final tab in AppTab.values) {
      container.read(selectedTabProvider.notifier).select(tab);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull, reason: tab.name);
    }
    expect(ProviderScope.containerOf(tester.element(find.byType(HomeShell))),
        same(container));
  });
}
