# FocusQuest Test Report

This report separates **automated results** (run by the Flutter test tools) from **physical-device verification** (checks done by hand on a phone). Nothing listed under "still required" has been verified.

## 1. Environment

| Item | Value |
|---|---|
| Flutter | 3.47.4 (stable channel) |
| Dart | 3.13.3 |
| Host | Windows 11 (10.0.26200) |
| Test device | Samsung SM-S731U1, Android 17 (API 37), device id `R5CYA0BD7ET` |
| Commit tested | `917dbe6` (unit, widget and integration tests) |

## 2. Commands

```
flutter analyze
flutter test                                  # unit and widget tests
flutter test --coverage                       # same, writing coverage/lcov.info
dart run tool/coverage_report.dart            # turns lcov.info into COVERAGE.md
flutter test integration_test -d <device-id>  # on-device integration tests
```

## 3. Automated results

| Suite | Command | Code tested | Result |
|---|---|---|---|
| Static analysis | `flutter analyze` | `917dbe6` | No issues |
| Unit and widget tests | `flutter test` | `917dbe6` | **258 / 258 passed** |
| Coverage | `flutter test --coverage` | `917dbe6` | **95.4%** (2383 of 2498 measured lines) |
| Integration tests | `flutter test integration_test -d R5CYA0BD7ET` | `917dbe6` | **5 / 5 passed** on the Samsung phone (47 s) |
| Release build | `flutter build apk --release` | `917dbe6` | Built `build/app/outputs/flutter-apk/app-release.apk` (54.1 MB, 192 s). Min SDK 24, target SDK 36, version 1.0.0. |
| Release install and launch | `flutter install -d R5CYA0BD7ET --release`, then launched with `adb` | `917dbe6` | Installed. The app started and was still running 8 s later, with no crash or Flutter error in the device log. **This shows it starts; it does not verify the features in the release build.** |

**These results still apply to the current code.** Since `917dbe6`, the only code change is commit `966eefc`, which added three baseline assertions to `test/domain/smart_helper_test.dart`. That file (11 / 11) and the full unit and widget suite (258 / 258) were run again after the change and passed. Later commits changed documentation only.

**Notes on the integration run:**
- **The first attempt on `917dbe6` ran no tests.** All five were reported "did not complete" at 0:00, before any test started. The test app failed to launch or connect, most likely because the phone had just been reconnected. No assertion failed. The immediate second attempt built, installed and passed all five.
- **During the History test, Flutter warned that one tap landed on the scrolling list** at (316.1, 596.8) instead of its target. The test still passed, so all of its checks held, but the tap's positioning should be made more robust.
- **An earlier run, before `917dbe6`, also passed 5 / 5** on the same phone.

The unit and widget suite has 252 test declarations. 258 tests run because the colour-contrast test in `theme_test.dart` runs once for the light scheme and once for the dark scheme.

### 3.1 Tests by file

| Layer | File | Tests |
|---|---|---|
| Domain | `test/domain/validation_test.dart` | 17 |
| | `test/domain/focus_session_test.dart` | 18 |
| | `test/domain/smart_helper_test.dart` | 11 |
| | `test/domain/aggregates_test.dart` | 4 |
| | `test/domain/history_test.dart` | 4 |
| | `test/domain/insights_test.dart` | 6 |
| | `test/domain/notification_schedule_test.dart` | 6 |
| | `test/domain/study_report_test.dart` | 3 |
| Data | `test/data/app_database_test.dart` | 10 |
| | `test/data/sqlite_task_repository_test.dart` | 10 |
| | `test/data/sqlite_session_repository_test.dart` | 14 |
| | `test/data/focus_checkpoint_repository_test.dart` | 9 |
| | `test/data/prefs_settings_repository_test.dart` | 7 |
| | `test/data/local_report_file_service_test.dart` | 4 |
| Providers | `test/providers/task_providers_test.dart` | 5 |
| | `test/providers/focus_controller_test.dart` | 10 |
| | `test/providers/helper_providers_test.dart` | 4 |
| Presentation | `test/presentation/home_shell_test.dart` | 4 |
| | `test/presentation/dashboard_screen_test.dart` | 10 |
| | `test/presentation/task_form_screen_test.dart` | 13 |
| | `test/presentation/task_actions_test.dart` | 12 |
| | `test/presentation/recommendation_card_test.dart` | 10 |
| | `test/presentation/focus_screen_test.dart` | 20 |
| | `test/presentation/history_screen_test.dart` | 12 |
| | `test/presentation/history_chart_test.dart` | 8 |
| | `test/presentation/report_screen_test.dart` | 5 |
| | `test/presentation/settings_screen_test.dart` | 8 |
| | `test/presentation/notifications_test.dart` | 8 |
| | `test/presentation/theme_test.dart` | 5 |
| Integration | `integration_test/app_test.dart` | 5 |

### 3.2 How the tests are isolated

- **Database tests** run against a real SQLite engine on the host through `sqflite_common_ffi`, using in-memory or temporary-file databases. This includes upgrading a version-1 database file to version 2.
- **Widget tests** pump the whole app with in-memory fake repositories and a clock the test controls (`test/support/`). This lets them check timing, such as paused time and the 7-day window, exactly.
- **Background isolates:** in widget tests, the History totals and the report builder run synchronously, because isolates cannot run inside the widget-test fake clock. The real isolate path is checked separately by unit tests (`history_test.dart`, `study_report_test.dart`) using `compute`.
- **Integration tests** run on the phone with real SQLite, SharedPreferences and isolates.
  - Only the clock and the notification service are replaced, so a 12-minute session takes no real time and no permission prompt blocks the run.
  - They use a separate database file (`integration_test.db`), and restore the phone's saved settings afterwards.
  - "Restart" means closing and reopening the database and starting a fresh app instance.

## 4. Coverage

- **Total:** 95.4% of measured lines (2383 / 2498)
- **By layer:**

  | Layer | Coverage |
  |---|---|
  | domain | 88.0% |
  | data | 95.2% |
  | providers | 97.4% |
  | presentation | 97.0% |

- **Full report:** [`COVERAGE.md`](../COVERAGE.md), per file. The raw data is `coverage/lcov.info` (ignored by git).
- **Scope:** unit and widget tests only. Integration tests are not measured.
- **Not measured,** because no unit or widget test loads these files:
  - `lib/main.dart` and `lib/data/services/local_notification_service.dart` need a real device and are checked manually (section 7.1)
  - `settings_repository.dart` and `report_file_service.dart` are interfaces with no executable lines
- **Low-coverage files** are mostly equality, `hashCode` and `toString` methods. Also lower: `clock.dart`, the system clock that tests replace, and the default background-isolate builders, which widget tests replace and unit tests exercise directly.

## 5. Test matrix

| Requirement | Automated evidence | On a device |
|---|---|---|
| Task create / read / update / delete | `sqlite_task_repository_test`, `task_providers_test`, `task_form_screen_test`, `task_actions_test` | Integration: add task; edit task survives restart; delete via ⋮ menu |
| Task validation (title 1–60, subject 1–40, estimate 5–120) | `validation_test`, `app_database_test` (CHECK constraints), `task_form_screen_test` | — |
| Session create / read / update / delete | `sqlite_session_repository_test`, `history_screen_test`, `focus_controller_test` | Integration: History add, edit, delete; Focus save |
| Session validation (1–120 min, no future start or end) | `validation_test`, `history_test`, `history_screen_test` | — |
| Cascade delete with confirmation count | `app_database_test`, `sqlite_task_repository_test`, `task_actions_test` | Integration: "This also deletes 1 saved session", then both tables empty |
| Active task cannot be deleted | `sqlite_task_repository_test`, `task_actions_test` | — |
| Focus states, pause timing, target cap | `focus_session_test`, `focus_screen_test` | Integration: 12-minute session saved as 12 min |
| Restart recovery | `focus_controller_test`, `focus_checkpoint_repository_test` | Integration: paused session restored with 20:00 left after a restart |
| Duplicate-save prevention | `focus_session_test`, `focus_checkpoint_repository_test`, `focus_controller_test`, `focus_screen_test`, `task_form_screen_test` | — |
| Save opens History; totals refresh | `focus_screen_test`, `history_screen_test` | Integration: History and Dashboard show 12 min after save and after restart |
| History filters and totals (isolate) | `sqlite_session_repository_test`, `history_test`, `history_screen_test` | — |
| Seven-day chart | `insights_test`, `history_chart_test` | Manual: checked by eye on the phone, reported by the team (§7.1) |
| Smart helper: normal, no history, invalid, boundary, tie, counterexample | `smart_helper_test` (every proposal §9 example), `helper_providers_test` | — |
| Recommendation accept / dismiss / override | `recommendation_card_test` | — |
| Held-out helper evaluation vs baseline | **Not run.** An illustrative calculated comparison on five team cases is in AI_FEATURE.md §7; it is not a held-out evaluation. | — |
| Settings saved and restored | `prefs_settings_repository_test`, `settings_screen_test` | Integration: 5 min, reduced motion and dark theme survive a restart |
| Dark mode | `theme_test` (contrast, System / Light / Dark) | Integration: dark theme after restart |
| Reduced motion | `task_actions_test`, `focus_screen_test`, `settings_screen_test` | Integration: still on after restart |
| Notifications: scheduling logic and permission flow | `notification_schedule_test`, `notifications_test` (fake service) | Manual: delivery and permission-denied card reported working by the team (§7.1) |
| Text report: write, read back, failures | `study_report_test`, `local_report_file_service_test`, `report_screen_test` | — |
| Offline operation | `lib/` contains no network code or network packages, and no test depends on network access | Integration tests use only local storage. Manual: airplane-mode persistence reported working by the team (§7.1). |
| Database upgrade v1 → v2 | `focus_checkpoint_repository_test` (upgrades a real version-1 file and keeps its data) | Informal only: the phone had a version-1 database from earlier builds and the app kept working after the upgrade. Not checked explicitly. |
| Accessibility labels, large text | Screen-reader labels and 2× text-scale checks in the widget tests | Manual: TalkBack and large text reported working by the team (§7.1) |

## 6. Portrait and landscape

**Automated** (widget tests, simulated screen sizes):
- 2× text size in landscape for the app shell, Dashboard, Focus Session, History, Settings and the Add Task form
- the Dashboard in portrait at 2× text
- every tab in dark mode at 2× text
- the History chart on a phone-sized portrait screen in dark mode at 2× text
- the Dashboard places the task list beside the summary in landscape

**On the phone:** see the landscape row in section 7.

## 7. Manual device checks

These were done by hand by the team, not by the test tools. **No logs, screenshots or recordings of them are stored in the repository.** Fields marked *pending* are details the team still needs to supply.

### 7.1 Confirmed by the team

The team reports each check below as working. **Device and date for all rows: pending.**

| Check | What was checked | Result |
|---|---|---|
| Notifications | Daily reminder arrives; session-end alert arrives while the app is in the background; the "Notifications are off" card and **Open phone settings** appear after permission is denied | Works |
| Landscape | Dashboard (list beside summary), Focus, History with the chart, Settings | Works |
| TalkBack and large text | Core flow with the screen reader and a large system font | Works |
| Airplane mode | Data saved with networking off is still there after closing and reopening the app | Works |
| History chart | Checked by eye on the phone | Works |
| Release APK | Feature check on the release build, beyond the install and launch recorded in section 3 | Works |

Earlier informal use during development also covered adding, editing and deleting tasks, running and saving focus sessions, the completion animation and the move to History.

### 7.2 Still required

1. **Second device or emulator** (proposal §10; question T1): **not recorded.** Needed: the device or emulator name, its Android version, the date, which flows were run (or whether the integration tests were run on it), and the result.

## 8. Failures found during testing, and fixes

| Found by | Problem | Fix |
|---|---|---|
| Repository test | Correcting a session's start time left the old end time behind, which the database rejected | End time is now derived from start time plus duration (`StudySession.corrected`) |
| Widget test, 2× text | The Dashboard status filter overflowed | Shrinks with an ellipsis |
| Widget test | Settings switches toggled only on the small switch, not the label | The whole row toggles |
| Widget test | The completion animation's pause left a timer running if the screen closed | Cancellable timer, cleared on dispose |
| During implementation | After any save, Dashboard and Focus briefly showed a loading spinner while data refreshed, which would cut off the completion animation | They keep showing the current data while refreshing |
| Widget test, 2× text | The Available-time dropdown on the Suggested-task card overflowed by 13 px | Fixed in `917dbe6`, with a regression test that fails without the fix |
| Build | The Android build failed: outdated Gradle setup and an old `shared_preferences` using a removed Flutter API | Gradle configuration migrated; packages upgraded |
| Merge | Merge-conflict markers in a committed macOS file; a test that did not compile | Removed |
| Integration test (phone) | The on-screen keyboard hid the bottom of the task form, so the test could not reach Save task | The test now closes the keyboard and scrolls, as a person does. The app itself behaved correctly. |
| Integration test (phone) | A test edited a manual session so it would end in the future | The app correctly refused it; the test's expectation was corrected |

## 9. Remaining risks

- **Notifications:** scheduling is inexact, so alerts may arrive a few minutes late on a sleeping phone. The daily reminder repeats at a fixed moment, so after a daylight-saving change it is off by an hour until the app is next opened. The plugin wrapper and `main.dart` are not covered by automated tests.
- **The chart counts a session wholly on the day it started**, even if it ran past midnight.
- **Helper quality** has been checked only on development examples and an illustrative calculation, not on held-out cases.
- **Release build:** the team reports a manual feature check on it (§7.1), but no log of that check is stored. Release builds are compiled differently from the debug builds the tests use. It is signed with the debug key.
- **One integration-test tap** in the History test landed on the list rather than its target (section 3). The test passed, but that tap should be positioned more robustly.
- **Manual checks have no stored evidence.** The results in §7.1 are team reports, without device, date, logs or screenshots.
- **No second device or emulator** has been recorded (§7.2).
