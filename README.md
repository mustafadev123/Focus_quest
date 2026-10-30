# FocusQuest

An offline Flutter app for planning study tasks, recording focus sessions, and receiving explainable local recommendations.

CSC 6360 Mobile Application Development, Project One · Team **Desi_hackers** (graduate pathway).

- **GitHub:** https://github.com/mustafadev123/Focus_quest
- **ClickUp board:** https://sharing.clickup.com/90141781342/l/h/6-901422406428-1/fe85bd20531ae5c

## Overview

Students often have several pieces of work due at once and lose track of what to do next and where their study time went. FocusQuest keeps everything on the phone:

- study tasks
- timed focus sessions with a saved history
- a rule-based helper that suggests the next task and explains why

It needs no account, no network and no cloud service.

## Implemented features

| Area | What it does |
|---|---|
| **Dashboard** | Weekly summary (tasks done, minutes studied this week), Suggested next task card, task list with a status filter, and empty, loading and error states. In landscape, the list sits beside the summary. |
| **Tasks** | Add and edit with validation (title 1–60, subject 1–40, estimate 5–120 min) and a slider with a number box. A failed save keeps the input for Retry, and leaving with unsaved changes asks first. Tap selects a task, long press edits, swipe deletes; the ⋮ menu offers the same actions. Deleting asks for confirmation, shows how many sessions will go with the task, and is blocked while that task has an unsaved focus session. |
| **Focus Session** | Ready / Running / Paused / Awaiting save / Saved, with a countdown to the target. Paused time is not counted. A one-off session length can be set while Ready. Finish, or reaching 00:00, opens a review; nothing is saved without Save session. Reset asks first. Progress is checkpointed in SQLite and restored after a restart. Saving runs a completion animation, then opens History. |
| **History and Insights** | Session list filtered by task, subject and date (today, this week, this month, all time). Totals are computed in a background isolate. A seven-day study-minutes chart. Add, edit and delete sessions. A text summary report saved to a file and previewed from it. |
| **Settings** | Focus duration, daily reminder with time, reduced motion, and theme (System / Light / Dark), saved with SharedPreferences. |
| **Smart helper** | Scores each eligible task by priority, time fit and the last seven days of study, explains its choice, and can be accepted, dismissed or overridden. A baseline is included for comparison. See [AI_FEATURE.md](AI_FEATURE.md). |
| **Notifications** | Optional daily reminder and session-end alert, with an explanation and a link to the phone's settings if permission is denied. |
| **Accessibility** | Screen-reader labels, large-text layouts, an alternative to every gesture, reduced motion, and contrast-checked light and dark themes. |

### History chart definitions

The "Last 7 days" chart is an addition to the History wireframe, approved by the team. It sits between the summary row and the session list.

- **Days:** the last seven local calendar days, today included, oldest on the left. Days are built from calendar dates, so a daylight-saving change never skips or repeats one. Zero-minute days keep a column.
- **Filters:** it follows History's task and subject filters (named in its label) but not the date filter; the card says so.
- **What counts:** every saved session matching those filters, whatever its status. A session's full duration counts on the day it started; sessions crossing midnight are not split.
- **Refresh:** it updates after any session save, edit or delete, and when a filter changes.
- **Hidden** when there are no sessions at all, so the "No sessions yet" state stays as in the wireframe.
- **Screen readers** hear one summary of the week instead of 21 separate labels.

## Requirements

- Flutter **3.47.4** (stable channel), Dart **3.13.3**
- Android SDK with platform 36; the app supports **Android 7.0 (API 24) and newer**, targeting API 36
- Windows only: Developer Mode on, which Flutter needs to build plugins
- An Android phone with USB debugging, or an emulator. Integration tests and notifications need one.

### Dependencies

| Package | Use |
|---|---|
| `flutter_riverpod` | State management and dependency injection |
| `sqflite`, `path` | SQLite for tasks, sessions and the focus checkpoint |
| `shared_preferences` | Settings |
| `path_provider` | Folder for the text report |
| `flutter_local_notifications`, `timezone` | Reminders and session-end alerts |
| `intl` | Date formatting |

Development only: `flutter_test`, `integration_test`, `sqflite_common_ffi` (SQLite for host tests), `flutter_lints`, `flutter_launcher_icons`.

## Setup and run

```
git clone https://github.com/mustafadev123/Focus_quest.git
cd Focus_quest
flutter pub get
flutter devices          # the phone or emulator should be listed
flutter run              # debug build on the connected device
```

## Test

```
flutter analyze
flutter test                                   # unit and widget tests
flutter test --coverage                        # with coverage
dart run tool/coverage_report.dart             # writes COVERAGE.md
flutter test integration_test -d <device-id>   # on a phone or emulator
```

The integration tests use a separate database file and restore the device's saved settings afterwards. Results are in [docs/TEST_REPORT.md](docs/TEST_REPORT.md).

## Build

```
flutter build apk --release
```

Output: `build/app/outputs/flutter-apk/app-release.apk` (about 54 MB). It is signed with the debug key, which is suitable for course testing but not for store publishing.

To regenerate the launcher icon from `assets/icon/app_icon.png`:

```
dart run flutter_launcher_icons
```

## Documentation

| Document | Contents |
|---|---|
| [ARCHITECTURE.md](ARCHITECTURE.md) | Layers, state management, persistence, recovery, lifecycle, trade-offs |
| [AI_FEATURE.md](AI_FEATURE.md) | Smart helper, baseline, test cases and evaluation status |
| [docs/TEST_REPORT.md](docs/TEST_REPORT.md) | Test commands, results, test matrix, device checks, failures and fixes |
| [COVERAGE.md](COVERAGE.md) | Line coverage by layer and file |
| [docs/PROJECT_REPORT.md](docs/PROJECT_REPORT.md) | Problem, solution, screens, data model, graduate requirements |
| [AI_Usage_Log.md](AI_Usage_Log.md) | Record of AI assistance |
| [docs/CONTRIBUTIONS.md](docs/CONTRIBUTIONS.md) | Team responsibilities, code and test locations, commit record |

## Status

**Automated checks** (commit `917dbe6`; the code is unchanged since then apart from three added test assertions):

| Check | Result |
|---|---|
| `flutter analyze` | No issues |
| Unit and widget tests | 258 / 258 passed |
| Integration tests | 5 / 5 passed on a Samsung SM-S731U1 (Android 17) |
| Line coverage | 95.4% of measured lines, from unit and widget tests only. `main.dart` and the notification plugin wrapper are not measured. See [COVERAGE.md](COVERAGE.md). |

**Manual device checks:** the team reports notifications, landscape, TalkBack and large text, airplane-mode persistence, the History chart and the release APK all working on the phone. **A second device or emulator has not yet been recorded.** Details are in [docs/TEST_REPORT.md](docs/TEST_REPORT.md).

**Presentation:** recorded as `FocusQuest_Presentation.mp4` (16 min 39 s). *Video link: pending.*

## Known limitations

- **Android only.** iOS was not built or tested.
- **Notifications** are scheduled inexactly, so they may arrive a few minutes late on a sleeping phone. After a daylight-saving change, the daily reminder is off by an hour until the app is next opened.
- **The helper** does not model deadlines. Its comparison with the baseline is an illustrative calculation,  a completed held-out evaluation ([AI_FEATURE.md](AI_FEATURE.md)).
- **The History chart** counts a session wholly on the day it started.
- **The release APK** is signed with the debug key.
- **A second-device or emulator check** is still to be recorded ([docs/TEST_REPORT.md](docs/TEST_REPORT.md)).

## Team contributions

| Member | Responsible for |
|---|---|
| **Muhammad Mustufa** | SQLite schema and repositories; StudyTask CRUD and the validated Add/Edit form; Dashboard and task integration; History filters and study totals; Settings and saved preferences; unit and database tests |
| **Praneeth Shankar Ravuri** | StudySession CRUD and the Focus Session screen; timer lifecycle and restart recovery; smart helper, baseline and evaluation work; local notifications; background processing and report file operations; session and widget tests |
| **Shared** | Riverpod architecture and dependency injection; integration testing and accessibility review; documentation and presentation |

Code and test locations for each area, and the git commit record, are in [docs/CONTRIBUTIONS.md](docs/CONTRIBUTIONS.md). AI assistance is recorded in [AI_Usage_Log.md](AI_Usage_Log.md).

**Kanban evidence:** the team reports that the instructor waived this requirement. ClickUp screenshots will be added by Praneeth (*pending*).
