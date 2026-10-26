# Test coverage

Generated 2026-10-26T03:53 from `flutter test --coverage` (unit and widget tests). The integration tests in `integration_test/` run on a device and are not included in these numbers.

Regenerate with:

```
flutter test --coverage
dart run tool/coverage_report.dart
```

**Total: 95.4%** (2383 of 2498 lines)

## By layer

| Layer | Lines hit | Coverage |
|---|---|---|
| `(root)` | 27 / 27 | 100.0% |
| `data` | 219 / 230 | 95.2% |
| `domain` | 373 / 424 | 88.0% |
| `presentation` | 1539 / 1586 | 97.0% |
| `providers` | 225 / 231 | 97.4% |

## By file

| File | Lines hit | Coverage |
|---|---|---|
| `lib/app.dart` | 27 / 27 | 100.0% |
| `lib/data/database/app_database.dart` | 16 / 19 | 84.2% |
| `lib/data/database/row_mappers.dart` | 37 / 38 | 97.4% |
| `lib/data/repositories/prefs_settings_repository.dart` | 25 / 26 | 96.2% |
| `lib/data/repositories/sqlite_focus_checkpoint_repository.dart` | 41 / 42 | 97.6% |
| `lib/data/repositories/sqlite_session_repository.dart` | 48 / 52 | 92.3% |
| `lib/data/repositories/sqlite_task_repository.dart` | 43 / 44 | 97.7% |
| `lib/data/services/local_report_file_service.dart` | 9 / 9 | 100.0% |
| `lib/domain/aggregates.dart` | 7 / 7 | 100.0% |
| `lib/domain/clock.dart` | 0 / 1 | 0.0% |
| `lib/domain/focus/focus_session.dart` | 91 / 94 | 96.8% |
| `lib/domain/helper/smart_helper.dart` | 67 / 67 | 100.0% |
| `lib/domain/history.dart` | 13 / 17 | 76.5% |
| `lib/domain/insights.dart` | 16 / 20 | 80.0% |
| `lib/domain/models/app_settings.dart` | 28 / 39 | 71.8% |
| `lib/domain/models/session_record.dart` | 1 / 8 | 12.5% |
| `lib/domain/models/study_session.dart` | 26 / 34 | 76.5% |
| `lib/domain/models/study_task.dart` | 28 / 34 | 82.4% |
| `lib/domain/report/study_report.dart` | 48 / 48 | 100.0% |
| `lib/domain/repositories/focus_checkpoint_repository.dart` | 1 / 2 | 50.0% |
| `lib/domain/repositories/session_repository.dart` | 1 / 1 | 100.0% |
| `lib/domain/repositories/task_repository.dart` | 2 / 6 | 33.3% |
| `lib/domain/services/notification_service.dart` | 4 / 4 | 100.0% |
| `lib/domain/validation/validation.dart` | 40 / 42 | 95.2% |
| `lib/presentation/dashboard/dashboard_screen.dart` | 125 / 125 | 100.0% |
| `lib/presentation/dashboard/widgets/recommendation_card.dart` | 100 / 103 | 97.1% |
| `lib/presentation/dashboard/widgets/summary_card.dart` | 28 / 28 | 100.0% |
| `lib/presentation/dashboard/widgets/task_card.dart` | 46 / 46 | 100.0% |
| `lib/presentation/focus/focus_screen.dart` | 195 / 199 | 98.0% |
| `lib/presentation/focus/widgets/completion_overlay.dart` | 48 / 48 | 100.0% |
| `lib/presentation/focus/widgets/review_dialog.dart` | 49 / 50 | 98.0% |
| `lib/presentation/focus/widgets/session_length_dialog.dart` | 24 / 24 | 100.0% |
| `lib/presentation/format.dart` | 23 / 23 | 100.0% |
| `lib/presentation/history/history_screen.dart` | 187 / 192 | 97.4% |
| `lib/presentation/history/report_screen.dart` | 43 / 43 | 100.0% |
| `lib/presentation/history/widgets/daily_minutes_chart.dart` | 65 / 65 | 100.0% |
| `lib/presentation/history/widgets/session_dialog.dart` | 104 / 122 | 85.2% |
| `lib/presentation/settings/settings_screen.dart` | 155 / 163 | 95.1% |
| `lib/presentation/shell/home_shell.dart` | 14 / 14 | 100.0% |
| `lib/presentation/task_actions.dart` | 28 / 30 | 93.3% |
| `lib/presentation/task_form/task_form_screen.dart` | 203 / 209 | 97.1% |
| `lib/presentation/task_form/widgets/minutes_field.dart` | 55 / 55 | 100.0% |
| `lib/presentation/theme.dart` | 29 / 29 | 100.0% |
| `lib/presentation/widgets/state_views.dart` | 18 / 18 | 100.0% |
| `lib/providers/core_providers.dart` | 18 / 19 | 94.7% |
| `lib/providers/dashboard_providers.dart` | 18 / 18 | 100.0% |
| `lib/providers/focus_providers.dart` | 61 / 63 | 96.8% |
| `lib/providers/helper_providers.dart` | 13 / 13 | 100.0% |
| `lib/providers/history_providers.dart` | 49 / 50 | 98.0% |
| `lib/providers/notification_providers.dart` | 28 / 29 | 96.6% |
| `lib/providers/report_providers.dart` | 3 / 4 | 75.0% |
| `lib/providers/settings_providers.dart` | 11 / 11 | 100.0% |
| `lib/providers/task_providers.dart` | 24 / 24 | 100.0% |

## Not measured

No unit or widget test loads these files, so they are not in the totals. Interfaces have no executable lines. `main.dart` and the notification plugin wrapper need a real device; the integration tests replace notifications with a fake and do not call `main`, so these are checked manually on the phone.

- `lib/data/services/local_notification_service.dart`
- `lib/domain/repositories/settings_repository.dart`
- `lib/domain/services/report_file_service.dart`
- `lib/main.dart`
