# FocusQuest Team Contributions

Team **Desi_hackers**: Muhammad Mustufa and Praneeth Shankar Ravuri (graduate pathway).

## 1. Areas of responsibility

The following split reflects the team's confirmed responsibilities. Feature ownership and commit authorship are recorded separately. Some files support more than one feature and therefore appear under both members.

### Muhammad Mustufa

| Area | Code | Tests or verification |
|---|---|---|
| SQLite schema and repository layer | `lib/data/database/app_database.dart`, `lib/data/database/row_mappers.dart`, `lib/data/repositories/sqlite_task_repository.dart`, `lib/data/repositories/sqlite_session_repository.dart`, `lib/domain/repositories/` | `test/data/app_database_test.dart`, `test/data/sqlite_task_repository_test.dart`, `test/data/sqlite_session_repository_test.dart` |
| StudyTask CRUD and validated Add/Edit form | `lib/presentation/task_form/`, `lib/presentation/task_actions.dart`, `lib/providers/task_providers.dart`, `lib/domain/validation/validation.dart` | `test/presentation/task_form_screen_test.dart`, `test/presentation/task_actions_test.dart`, `test/providers/task_providers_test.dart`, `test/domain/validation_test.dart` |
| Dashboard and task integration | `lib/presentation/dashboard/dashboard_screen.dart`, `lib/presentation/dashboard/widgets/task_card.dart`, `lib/presentation/dashboard/widgets/summary_card.dart`, `lib/providers/dashboard_providers.dart` | `test/presentation/dashboard_screen_test.dart`, `test/domain/aggregates_test.dart` |
| History filters and aggregate calculations | `lib/presentation/history/history_screen.dart`, filter/totals logic in `lib/providers/history_providers.dart`, `lib/domain/history.dart`, `lib/domain/aggregates.dart` | `test/presentation/history_screen_test.dart`, `test/domain/history_test.dart` |
| Settings and saved preferences | `lib/presentation/settings/settings_screen.dart`, `lib/data/repositories/prefs_settings_repository.dart`, `lib/providers/settings_providers.dart`, `lib/domain/models/app_settings.dart` | `test/presentation/settings_screen_test.dart`, `test/data/prefs_settings_repository_test.dart` |
| Dark mode and theme selection | `lib/presentation/theme.dart`, theme controls in Settings, saved theme preference | `test/presentation/theme_test.dart`, settings and preferences tests |
| Seven-day History chart | `lib/domain/insights.dart`, `lib/presentation/history/widgets/daily_minutes_chart.dart` | Chart aggregation and widget checks in the repository test suite, plus light/dark visual review |
| App icon and branding | Custom FocusQuest app icon and platform icon assets | Visual check of the installed app icon |
| Android build configuration | Android project configuration and release APK build setup | Release APK build, installation and launch checks |
| Unit and database tests | Domain validation and local data layer | `test/domain/validation_test.dart`, `test/data/` |

Mustufa's repository-layer work includes the SQLite session repository. Praneeth's session ownership below covers session workflows, UI actions and timer behavior that use that repository.

### Praneeth Shankar Ravuri

| Area | Code | Tests |
|---|---|---|
| StudySession CRUD and Focus Session screen | `lib/presentation/focus/`, `lib/presentation/history/widgets/session_dialog.dart`, `SessionActions` in `lib/providers/history_providers.dart` | `test/presentation/focus_screen_test.dart`, session add/edit/delete tests in `test/presentation/history_screen_test.dart` |
| Timer lifecycle and restart recovery | `lib/domain/focus/focus_session.dart`, `lib/providers/focus_providers.dart`, `lib/data/repositories/sqlite_focus_checkpoint_repository.dart` | `test/domain/focus_session_test.dart`, `test/providers/focus_controller_test.dart`, `test/data/focus_checkpoint_repository_test.dart` |
| Smart helper, baseline and evaluation work | `lib/domain/helper/smart_helper.dart`, `lib/providers/helper_providers.dart`, `lib/presentation/dashboard/widgets/recommendation_card.dart`, [AI_FEATURE.md](../AI_FEATURE.md) | `test/domain/smart_helper_test.dart`, `test/providers/helper_providers_test.dart`, `test/presentation/recommendation_card_test.dart` |
| Local notifications | `lib/domain/services/notification_service.dart`, `lib/data/services/local_notification_service.dart`, `lib/providers/notification_providers.dart`, Android notification integration | `test/domain/notification_schedule_test.dart`, `test/presentation/notifications_test.dart` |
| Background processing and report file operations | Isolate execution for History totals in `lib/providers/history_providers.dart`, `lib/domain/report/study_report.dart`, `lib/data/services/local_report_file_service.dart`, `lib/providers/report_providers.dart`, `lib/presentation/history/report_screen.dart` | `test/domain/study_report_test.dart`, `test/data/local_report_file_service_test.dart`, `test/presentation/report_screen_test.dart` |
| Session and widget tests | Focus, helper, notifications and report workflows | `test/presentation/focus_screen_test.dart`, `test/presentation/recommendation_card_test.dart`, `test/presentation/notifications_test.dart`, `test/presentation/report_screen_test.dart` |

Praneeth owns background execution of History summaries. Mustufa owns the filtering and aggregate calculations used by that workflow. Notification-specific Android changes belong to Praneeth, while general Android build configuration belongs to Mustufa.

Evaluation responsibility does not establish that an evaluation was completed. See `AI_FEATURE.md` for the evidence and status. Calculated or simulated comparisons must remain labeled as such.

### Shared

| Area | Code or document | Tests or evidence |
|---|---|---|
| Riverpod architecture and dependency injection | `lib/providers/core_providers.dart`, `lib/main.dart`, `lib/app.dart`, [ARCHITECTURE.md](../ARCHITECTURE.md) | `test/support/` fakes and test app, `test/presentation/home_shell_test.dart` |
| Integration testing and accessibility review | `integration_test/app_test.dart`, accessibility review across screens | `test/presentation/theme_test.dart`, 2× text-size tests across `test/presentation/`, team device checks |
| Documentation and presentation | `README.md`, `ARCHITECTURE.md`, `AI_FEATURE.md`, `docs/`, presentation | Both members reviewed and presented their areas of responsibility |

## 2. Commit record

The supplied repository audit records these non-merge commit counts as of `4e4cedc`. These are a historical snapshot, not current totals or a measure of individual effort.

| Git author | Commits |
|---|---|
| Muhammad mustufa | 28 |
| Praneeth Ravuri / rpraneeths | 12 |

Commits attributed to Praneeth Ravuri / rpraneeths in that audit:

- Planning documents: `5ac3ba9`, `b4993ef`, `8ec4480`, `cce41e6`.
- Flutter project scaffold: `c9d1571`.
- First implementation of sessions, timer and smart helper: `f2290ae`. This was later integrated into the layered structure. Its helper formula and tie-breaking were retained, and duplicate files were removed.
- Final documentation uploads: `6afe90e`, `7aa2928`, `c9ae315`, `092e65a`, `0c233e1`, `e062440`.

### AI assistance and team ownership


The responsibility tables describe the team's ownership of features and their review and verification. The person who committed a file is not necessarily its sole implementer.

### Branches and reviews

The supplied audit reports that commits were made directly to `main`, with no feature branches, pull requests or recorded review threads. Team review should not be described as a GitHub PR review where no such record exists.

## 3. Kanban and ClickUp

- The team reports that the instructor waived the Kanban evidence requirement, so no `Kanban_Contribution_Evidence.pdf` is included.
- Board: <https://sharing.clickup.com/90141781342/l/h/6-901422406428-1/fe85bd20531ae5c>.
- The planning snapshot from October 18 is in the proposal's Appendix B.
- Additional ClickUp screenshots will be attached by Praneeth and remain pending.
