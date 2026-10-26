import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:focus_quest/app.dart';
import 'package:focus_quest/data/database/app_database.dart';
import 'package:focus_quest/presentation/dashboard/widgets/task_card.dart';
import 'package:focus_quest/presentation/focus/widgets/completion_overlay.dart';
import 'package:focus_quest/providers/core_providers.dart';
import 'package:focus_quest/providers/notification_providers.dart';
import 'package:integration_test/integration_test.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite/sqflite.dart';

import '../test/support/fake_notification_service.dart';
import '../test/support/test_app.dart' show TestClock;

/// End-to-end checks on a real device: real SQLite, SharedPreferences and
/// background isolates. Only the clock (so a 12-minute session takes no
/// real time) and notifications (so no permission prompt blocks the run)
/// are replaced. A separate database file keeps the student's own data
/// untouched, and saved settings are restored afterwards.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  late String dbPath;
  late TestClock clock;
  Database? db;
  ProviderContainer? container;
  late Map<String, Object> savedPrefs;

  setUpAll(() async {
    dbPath = p.join(await getDatabasesPath(), 'integration_test.db');
    final prefs = await SharedPreferences.getInstance();
    savedPrefs = {for (final k in prefs.getKeys()) k: prefs.get(k)!};
  });

  setUp(() async {
    await deleteDatabase(dbPath);
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
    clock = TestClock(DateTime.now());
  });

  Future<void> closeApp(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    container?.dispose();
    container = null;
    await db?.close();
    db = null;
  }

  tearDown(() async {
    container?.dispose();
    await db?.close();
    await deleteDatabase(dbPath);
  });

  tearDownAll(() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
    for (final MapEntry(:key, :value) in savedPrefs.entries) {
      switch (value) {
        case bool v:
          await prefs.setBool(key, v);
        case int v:
          await prefs.setInt(key, v);
        case double v:
          await prefs.setDouble(key, v);
        case String v:
          await prefs.setString(key, v);
        case List v:
          await prefs.setStringList(key, v.cast<String>());
      }
    }
  });

  /// Starts the app the way `main` does, on the test database file.
  Future<void> launch(WidgetTester tester) async {
    db = await AppDatabase.open(path: dbPath);
    container = ProviderContainer(
      retry: (_, __) => null,
      overrides: [
        databaseProvider.overrideWithValue(db!),
        clockProvider.overrideWithValue(clock.call),
        notificationServiceProvider
            .overrideWithValue(FakeNotificationService()),
      ],
    );
    await tester.pumpWidget(UncontrolledProviderScope(
      container: container!,
      child: const FocusQuestApp(),
    ));
    await tester.pumpAndSettle();
  }

  /// Closes everything and launches again on the same files.
  Future<void> restart(WidgetTester tester) async {
    await closeApp(tester);
    await launch(tester);
  }

  Finder button(String label) => find.ancestor(
        of: find.text(label),
        matching: find.byWidgetPredicate((w) => w is ButtonStyleButton),
      );

  Future<void> tap(WidgetTester tester, Finder finder) async {
    await tester.ensureVisible(finder.first);
    await tester.pumpAndSettle();
    await tester.tap(finder.first);
    await tester.pumpAndSettle();
  }

  Future<void> scrollTo(WidgetTester tester, String text) =>
      tester.scrollUntilVisible(find.text(text), 200,
          scrollable: find.byType(Scrollable).first);

  Future<void> openTab(WidgetTester tester, String label) => tap(
      tester,
      find.descendant(
          of: find.byType(NavigationBar), matching: find.text(label)));

  /// Closes the keyboard and scrolls the task form to Save task, as on a
  /// real phone the open keyboard hides the bottom of the form.
  Future<void> saveForm(WidgetTester tester) async {
    FocusManager.instance.primaryFocus?.unfocus();
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text('Save task'), 200,
        scrollable: find
            .descendant(
                of: find.byType(Form), matching: find.byType(Scrollable))
            .first);
    await tap(tester, find.text('Save task'));
  }

  Future<void> addTask(
      WidgetTester tester, String title, String subject) async {
    await tap(tester, find.text('Add task'));
    await tester.enterText(
        find.widgetWithText(TextFormField, 'e.g. Review recursion notes'),
        title);
    await tester.enterText(
        find.widgetWithText(TextFormField, 'e.g. Data Structures'), subject);
    await saveForm(tester);
  }

  Future<int> rows(String table) async =>
      (await db!.rawQuery('SELECT COUNT(*) AS n FROM $table')).single['n']!
          as int;

  testWidgets(
      'task → focus → review → save → History, and it survives a restart',
      (tester) async {
    await launch(tester);
    expect(find.text('No tasks yet'), findsOneWidget);

    await addTask(tester, 'Lab 3 report', 'Physics');
    expect(
        find.descendant(
            of: find.byType(TaskCard), matching: find.text('Lab 3 report')),
        findsOneWidget);

    await tap(tester, find.widgetWithText(FilledButton, 'Focus'));
    expect(find.text('Ready'), findsOneWidget);
    await tap(tester, button('Start'));
    expect(find.text('Running'), findsOneWidget);

    clock.advance(const Duration(minutes: 12));
    await tester.pump(const Duration(seconds: 1));
    await tap(tester, button('Finish'));
    expect(find.text('Review session'), findsOneWidget);
    expect(find.text('12:00'), findsOneWidget);

    await tester.tap(button('Save session'));
    await tester.pumpAndSettle();
    await tester.pump(CompletionOverlay.holdDuration);
    await tester.pumpAndSettle();

    // Save opens History with the new record and totals.
    expect(find.text('History and Insights'), findsOneWidget);
    expect(find.text('12 min'), findsOneWidget);
    expect(find.text('12m studied', findRichText: true), findsOneWidget);
    expect(await rows(AppDatabase.sessionsTable), 1);
    expect(await rows(AppDatabase.activeSessionTable), 0);

    await restart(tester);
    expect(find.text('12m'), findsOneWidget); // Dashboard weekly total
    await openTab(tester, 'History');
    expect(find.text('Lab 3 report'), findsOneWidget);
    expect(find.text('12 min'), findsOneWidget);
  });

  testWidgets('a running session is restored after a restart', (tester) async {
    await launch(tester);
    await addTask(tester, 'Calculus practice', 'Calculus');
    await tap(tester, find.widgetWithText(FilledButton, 'Focus'));
    await tap(tester, button('Start'));
    clock.advance(const Duration(minutes: 5));
    await tester.pump(const Duration(seconds: 1));
    await tap(tester, button('Pause'));
    clock.advance(const Duration(minutes: 30)); // paused time is not counted

    await restart(tester);
    await openTab(tester, 'Focus');
    expect(find.text('Paused'), findsOneWidget);
    expect(find.text('20:00'), findsOneWidget);
    expect(await rows(AppDatabase.activeSessionTable), 1);
  });

  testWidgets(
      'session add, edit and delete in History; deleting a task cascades',
      (tester) async {
    await launch(tester);
    await addTask(tester, 'Reading', 'History');

    await openTab(tester, 'History');
    await tap(tester, find.text('Add session'));
    await tester.enterText(
        find.descendant(
            of: find.byType(AlertDialog), matching: find.byType(TextFormField)),
        '20');
    await tap(tester, find.widgetWithText(FilledButton, 'Save'));
    expect(find.text('20 min'), findsOneWidget);

    await tap(tester, find.widgetWithText(OutlinedButton, 'Edit'));
    await tester.enterText(
        find.descendant(
            of: find.byType(AlertDialog), matching: find.byType(TextFormField)),
        '15');
    await tap(tester, find.widgetWithText(FilledButton, 'Save'));
    expect(find.text('15 min'), findsOneWidget);
    final stored = await db!.query(AppDatabase.sessionsTable);
    expect(stored.single['duration_minutes'], 15);

    await tap(tester, find.widgetWithText(OutlinedButton, 'Delete'));
    await tap(tester, find.widgetWithText(FilledButton, 'Delete'));
    expect(await rows(AppDatabase.sessionsTable), 0);

    // Record another session, then delete the task with it.
    await tap(tester, find.text('Add session'));
    await tap(tester, find.widgetWithText(FilledButton, 'Save'));
    expect(await rows(AppDatabase.sessionsTable), 1);

    await openTab(tester, 'Tasks');
    await tap(tester, find.byTooltip('More actions for Reading'));
    await tap(tester, find.text('Delete').last);
    expect(
        find.text("This also deletes 1 saved session. This can't be "
            'undone.'),
        findsOneWidget);
    await tap(tester, find.widgetWithText(FilledButton, 'Delete'));

    expect(await rows(AppDatabase.tasksTable), 0);
    expect(await rows(AppDatabase.sessionsTable), 0);
    expect(find.text('No tasks yet'), findsOneWidget);
  });

  testWidgets('task edits persist across a restart', (tester) async {
    await launch(tester);
    await addTask(tester, 'Draft essay', 'English');

    await tester.longPress(find.descendant(
        of: find.byType(TaskCard), matching: find.text('Draft essay')));
    await tester.pumpAndSettle();
    await tester.enterText(
        find.widgetWithText(TextFormField, 'Draft essay'), 'Final essay');
    await saveForm(tester);

    await restart(tester);
    expect(
        find.descendant(
            of: find.byType(TaskCard), matching: find.text('Final essay')),
        findsOneWidget);
    expect(find.text('Draft essay'), findsNothing);
  });

  testWidgets('preferences are saved and still there after a restart',
      (tester) async {
    await launch(tester);
    await openTab(tester, 'Settings');

    final slider = tester.getRect(find.byType(Slider));
    await tester.tapAt(Offset(slider.left + 4, slider.center.dy)); // 5 min
    await tester.pumpAndSettle();
    await tap(tester, find.text('Reduced motion'));
    await scrollTo(tester, 'Dark');
    await tap(tester, find.text('Dark'));
    await scrollTo(tester, 'Save settings');
    await tap(tester, find.text('Save settings'));
    expect(find.text('Settings saved'), findsOneWidget);

    await restart(tester);
    await openTab(tester, 'Settings');
    expect(find.text('5 min'), findsNWidgets(2)); // value and range label
    final context = tester.element(find.text('Focus duration'));
    expect(Theme.of(context).brightness, Brightness.dark);
    expect(MediaQuery.disableAnimationsOf(context), isTrue);

    // The saved duration is the Focus target after the restart.
    await openTab(tester, 'Tasks');
    await addTask(tester, 'Flashcards', 'Spanish');
    await tap(tester, find.widgetWithText(FilledButton, 'Focus'));
    expect(find.text('05:00'), findsOneWidget);
  });
}
