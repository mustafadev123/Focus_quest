# FocusQuest Project Report

CSC 6360 Mobile Application Development, Project One · Team Desi_hackers · Graduate pathway

## 1. Problem

Students often have several pieces of work due at once: an exam, a lab report, a reading. They switch between them, lose track of what was finished, and can't tell where their study time went. Most planners keep a to-do list but neither help choose what to do next nor show how time was spent.

## 2. Target users

Students who want to organise their own academic tasks and see their study activity. The app is for one person on one phone and needs no account or internet connection.

## 3. Solution

FocusQuest is an offline Android app built with Flutter. It brings together task planning, timed focus sessions with a saved history, and a rule-based helper that suggests the next task and explains why.

| Inputs (from the student) | Outputs (to the student) |
|---|---|
| Tasks: title, subject, priority, estimate, status | Task list with weekly progress |
| Focus actions: Start, Pause, Resume, Finish, Save, Reset | Countdown, a review of the time studied, a saved session record |
| Manual session records and corrections | History list, totals, a seven-day chart |
| Available time for a suggestion | One suggested task with reasons and a score breakdown |
| Settings: duration, reminder, reduced motion, theme | Reminders, session-end alerts, a text summary report |

## 4. Screens and navigation

Bottom navigation has four tabs: **Tasks**, **Focus**, **History**, **Settings**. These are the tabs in the proposal's wireframes. Add/Edit Task and the report preview open as separate screens.

| Screen | Purpose | Main states |
|---|---|---|
| **Dashboard** (Tasks tab) | Weekly summary, Suggested next task, task list with status filter, Focus button per task | Empty ("No tasks yet"), loading, error with Retry, data. Landscape: list beside the summary. |
| **Add / Edit Task** | Title, subject (with suggestions), priority, estimate (slider plus number box), status | Field errors, saving, save failed with Retry, unsaved-changes prompt, Delete task in Edit mode |
| **Focus Session** | Task choice, status chip, countdown, Start/Pause/Resume/Finish, Reset, review dialog | Ready, Running, Paused, Awaiting save, Saved; completion animation; no-task state |
| **History and Insights** | Task, subject and date filters; totals; seven-day chart; sessions with Edit/Delete; Add session; Text report | No sessions yet, no matches, loading, error with Retry |
| **Settings** | Focus duration, daily reminder and time, reduced motion, theme | Notifications-off card, save failed, Settings saved |

**Navigation flow:**
- **Tasks:** Focus on a task opens the Focus tab with that task selected. Long press or ⋮ → Edit opens the task form.
- **Focus:** saving a session plays the completion animation, then opens History.
- **History:** Text report opens the report preview.
- **Leaving early:** a form with unsaved changes asks before closing. Leaving during a running session keeps its checkpoint.

## 5. Local data model

**SQLite:**

| Entity | Fields | Rules |
|---|---|---|
| **StudyTask** | id, title, subject, priority, estimatedMinutes, status, createdAt, updatedAt | Title 1–60, subject 1–40, priority 1–3, estimate 5–120, status pending/completed, ids never reused |
| **StudySession** | id, taskId, startedAt, endedAt, durationMinutes, status | Belongs to one task (deleted with it). 1–120 minutes. End not before start. Status completed / ended early / manual. |
| **Active session checkpoint** | task, state, start, active time, target, last resume, finish time | At most one row; restores a session after a restart |

- **One task has many sessions.** Deleting a task removes its sessions in one transaction, after a confirmation stating how many.
- **SharedPreferences** holds: focus duration, reminder on/off and time, reduced motion, theme.

Full detail is in [ARCHITECTURE.md](../ARCHITECTURE.md) §4.

## 6. Major design decisions

1. **Four bottom tabs**, as in the wireframes, rather than the three named in the proposal text.
2. **Task status is stored as pending/completed** and shown as "To do"/"Completed". The wireframe's "In progress" was dropped to match the data rules.
3. **Gestures and buttons for every action.** Tap selects (with a highlight), long press edits, swipe deletes, and the ⋮ menu offers Edit and Delete.
4. **History filters by task, subject and date.** Subject was added to the wireframe's two filters to meet the written requirement.
5. **The History edit dialog includes a start time**, required by the text but not shown in the wireframe.
6. **The delete confirmation states how many sessions will be removed.**
7. **Timer time comes from saved timestamps**, checkpointed in SQLite before each change. This gives restart recovery and duplicate-save protection.
8. **A "Review and save" button** appears in Awaiting save, so a session can still be saved after closing the review dialog.
9. **A one-off session length can be set on the Focus screen** while Ready. Settings keeps the default.
10. **The Theme setting** (System / Light / Dark) from the wireframe's optional row, with a contrast-checked dark scheme.
11. **A seven-day chart in History**, an approved addition defined in the [README](../README.md).
12. **Notifications: one opt-in for both** daily reminders and session-end alerts, the single switch in the wireframe. Scheduling is inexact.

## 7. Graduate requirements

| Requirement (proposal §10) | Where it is met |
|---|---|
| Riverpod state management: global state, async loading/errors | `lib/providers`: tasks, focus session, settings, filters. Error and Retry handling on every load. |
| Separate presentation / domain / data layers | `lib/presentation`, `lib/domain` (plain Dart), `lib/data` |
| Repository interfaces and dependency injection | Six interfaces in the domain, implementations in data, supplied by providers; tests replace them with fakes |
| Reactive cross-screen updates | A revision counter refreshes Dashboard, History and Focus after any write |
| ARCHITECTURE.md with diagram and trade-offs | [ARCHITECTURE.md](../ARCHITECTURE.md) |
| Implicit animation | `AnimatedContainer` highlight on the selected task |
| Explicit animation | `AnimationController` completion check after Save |
| Reduced motion | Phone setting or in-app setting turns both animations off |
| Background processing | History totals and report text prepared with `compute` in a background isolate; recovery from persisted timestamps |
| Local notifications | Opt-in daily reminder and session-end alert; permission-denied feedback; cancel/reschedule on pause, reset, finish and settings changes |
| File operations | Study summary written to a text file, read back for the preview, with write and read failure messages |
| Smart helper with baseline and evaluation | Implemented and tested on development cases, plus an illustrative calculated comparison on five team cases. **A completed held-out evaluation has not been recorded** ([AI_FEATURE.md](../AI_FEATURE.md) §7). |
| At least 10 unit tests, widget tests, integration tests, coverage report | 258 unit and widget tests, 5 integration tests on a phone, 95.4% measured coverage |
| Two-device / emulator checks; portrait/landscape; accessibility; notifications | Automated layout and accessibility checks done. Landscape, TalkBack and large text, notifications and airplane mode are reported working by the team on the phone. **No second device or emulator recorded yet** ([TEST_REPORT.md](TEST_REPORT.md) §7). |

## 8. Testing summary

- **Unit and widget tests:** 258 / 258 pass on commit `917dbe6`. `flutter analyze` reports no issues.
- **Integration tests:** 5 / 5 pass on a Samsung SM-S731U1 (Android 17) at `917dbe6`. They cover:
  - the full task → focus → review → save → History flow
  - restart recovery
  - session and task CRUD with cascade delete
  - task edits and preferences after a restart
- **Coverage:** 95.4% of measured lines. `main.dart` and the notification plugin wrapper are not measured.
- **Release APK:** built (54.1 MB). It installed on the Samsung phone and launched without a crash. The team reports a manual feature check on the release build.
- **These results still apply:** the code is unchanged since `917dbe6` apart from three added test assertions, after which all 258 tests passed again.
- **Manual device checks, reported by the team as working:** notifications, landscape, TalkBack and large text, airplane-mode persistence, the History chart, the release APK. Device and dates are still to be supplied.
- **Still required:** a second device or emulator.

Full detail, including failures found and fixed, is in [TEST_REPORT.md](TEST_REPORT.md).

## 9. Technical challenges

- **Restart-safe timing without a background service:** solved with immutable, timestamp-based session state and a SQLite checkpoint written before each change.
- **Saving exactly once:** inserting the record and deleting the checkpoint in one transaction, conditional on the checkpoint still existing, defeats double taps, retries and crashes.
- **Keeping data on screen while it refreshes:** an early version briefly showed a loading spinner after every save, which would have cut off the completion animation.
- **Large text sizes:** several dropdowns overflowed at 2× text and were made to shrink with an ellipsis. Widget tests at 2× text found each one.
- **Android build setup:** the generated project used an outdated Gradle setup, and an old package used a removed Flutter API. Both were updated before the app would build.
- **Integrating parallel work:** an earlier duplicate implementation in the repository used a conflicting database schema. Its useful logic (helper formula and tie-breaking) was moved into the layered structure, and the duplicate was removed.
- **Real-phone differences:** on the phone, the on-screen keyboard hides the bottom of the task form. Desktop tests can't see this; the on-device integration tests did.

## 10. Peer feedback and revisions

### 10.1 Peer observation (reported by the team)

The team reports that a peer tried the app and gave feedback, which led to the revisions below. The peer then tried the revised app again (a peer retry). **No direct quote, timing figures or other measures of improvement were recorded,** so none are given here. *The date of the observation and the peer's role (for example, classmate) are pending.*

| Observation | Revision | Repository evidence |
|---|---|---|
| The peer found the original coloured interface distracting | The interface was changed to grayscale | The first app commit (`8fe3325`) replaced the Flutter template's purple theme with the grayscale theme in `lib/presentation/theme.dart`. The proposal's wireframes (Oct 18) were already grayscale. |
| The helper originally did not account for task priority | Its calculation was revised to include priority | **To be clarified.** Every recorded version of the helper includes priority: the proposal's formula (Oct 18, priority weighted 50%), the earlier plan in AI_FEATURE.md (`8ec4480`), the first implementation (`f2290ae`) and the current code. This revision therefore cannot be traced to a commit. The team should confirm which version lacked priority, for example an early prototype or a design draft outside this repository. |

### 10.2 Revisions from the team's own testing

Not peer feedback:
- **Cancel and Save task:** Cancel was a small text button squeezed to the left. They now share the row in equal halves; a test checks the layout.
- **Session length:** the length of a single session could only be changed through Settings. A one-off length can now be set on the Focus screen while Ready.

## 11. Known limitations

- **Android only;** iOS was not built or tested.
- **Notifications** are inexact and need the reminder switched on. Delivery is reported working by the team, but no log is stored.
- **The helper** ignores deadlines, and a completed held-out evaluation has not been recorded.
- **The History chart** counts a session on the day it started.
- **The release APK** is signed with the debug key.
- **Manual device checks** are team reports without stored logs or screenshots. **No second device or emulator** has been recorded.

## 12. Team contributions

| Member | Responsible for |
|---|---|
| **Muhammad Mustufa** | SQLite schema and repositories; StudyTask CRUD and validated Add/Edit form; Dashboard and task integration; History filters and study totals; Settings and saved preferences; unit and database tests |
| **Praneeth Shankar Ravuri** | StudySession CRUD and Focus Session screen; timer lifecycle and restart recovery; smart helper, baseline and evaluation work; local notifications; background processing and report file operations; session and widget tests |
| **Shared** | Riverpod architecture and dependency injection; integration testing and accessibility review; documentation and presentation |

Code and test locations for each area, and the git commit record, are in [CONTRIBUTIONS.md](CONTRIBUTIONS.md). AI assistance is recorded in [AI_Usage_Log.md](../AI_Usage_Log.md).

**Kanban evidence:** the team reports that the instructor waived this requirement. ClickUp screenshots will be attached by Praneeth (*pending*).

**Presentation:** recorded as `FocusQuest_Presentation.mp4` (16 min 39 s): https://www.youtube.com/watch?v=Qr1W7RMeTus

**Individual reflections:** deferred.
