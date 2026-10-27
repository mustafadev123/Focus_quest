# FocusQuest Smart Helper

> **Evaluation status: the held-out evaluation required by proposal §9 has NOT been run.** The cases in section 6 are **development cases**: the proposal's worked examples, used while building and testing the helper. They are not held-out cases and must not be reported as such. Section 7 says what is needed to complete the evaluation.

## 1. What it is

A **rule-based scoring heuristic**, not a trained machine-learning model. It suggests one study task on the Dashboard's "Suggested next task" card and explains why. It runs entirely on the phone, from tasks and sessions stored in local SQLite. It sends nothing anywhere and never creates, changes or deletes data.

- **Logic:** `lib/domain/helper/smart_helper.dart` (plain Dart, no Flutter widgets)
- **Wiring:** `recommendationProvider` in `lib/providers/helper_providers.dart`
- **Card:** `lib/presentation/dashboard/widgets/recommendation_card.dart`

## 2. Inputs

| Input | Source | Units and limits |
|---|---|---|
| Task priority | Task | 1 (low), 2 (medium), 3 (high) |
| Estimated duration | Task | Minutes, 5–120 |
| Task status | Task | Only `pending` tasks are eligible |
| Available time | "Available time" dropdown on the card | Minutes, 5–120. The dropdown offers 5, 10, 15, 20, 25, 30, 45, 60, 90 and 120, starting at the Settings focus duration. |
| Recent study | Saved sessions started within the last 7 days (`now − 7 days` up to now), summed per task | Minutes; tasks with none count as 0 |

**Eligible task:** saved, not completed, with an estimate of 5–120 minutes. Anything else is skipped, not guessed at.

## 3. Formula

For each eligible task:

- **P** = (priority − 1) / 2
- **F** = min(available ÷ estimate, 1)
- **R** = 1 / (1 + recent minutes ÷ 25)

**Score = 0.50·P + 0.30·F + 0.20·R**

- **Highest score wins.**
- **Ties** (scores within 1e-9) go to the oldest creation time, then the lowest task id.
- **Available time outside 5–120** is rejected with a validation error.
- **No eligible task:** no recommendation is made.

## 4. Explanation and user controls

**The card shows:**
- the task title
- a short summary, e.g. "Medium priority · fits your time"
- a **Why this task?** link listing one reason per part of the score:
  - "Medium priority."
  - "Its estimate of 30 min fits in your 30 min." *or* "…is longer than your 60 min, so it fits 67%."
  - "You studied it for 10 min in the last 7 days." / "You have not studied it in the last 7 days." / **with no recent study at all:** "No study history from the last 7 days was used, so only priority and time fit decided."
- a score breakdown, e.g. "Score 0.75 = priority 0.25 + time fit 0.30 + recent activity 0.20"
- "Rule-based suggestion from priority, time fit and recent study. It is not a trained AI model."

| Control | Behaviour |
|---|---|
| **Use task** (accept) | Selects the task and sets that session's length to the available time, then opens Focus in **Ready**. It never starts a session or saves anything. It is refused, with a message, while another session is in progress. |
| **Not now** (dismiss) | Hides the suggestion; **Show suggested task** brings it back. No data changes. |
| **Override** | Choose any other task with its **Focus** button. |
| Available time | Changing it recalculates the suggestion. |
| No eligible task | With tasks but none eligible (all completed), the card says "Nothing to suggest: every task is completed." with **Create a task**. With no tasks at all, the card is hidden and the Dashboard's "No tasks yet / + Add task" state is the create prompt. |

## 5. Baseline

The highest-priority eligible task; ties go to the oldest creation time, then the lowest id (proposal §9). It uses no time fit and no history. Implemented as `SmartHelper.baseline` and tested alongside the helper.

## 6. Development cases: expected vs observed

These are the proposal's §9 worked examples, plus window checks. They were known while the helper was built, so they verify the implementation; they do **not** measure how good its suggestions are. "Observed" is what the code computes, asserted by the tests listed. Scores are exact values; the proposal rounds to two decimals.

| Case | Input | Expected (proposal) | Observed | Baseline | Test |
|---|---|---|---|---|---|
| Normal | 60 min available. A: priority 3, 90 min, no recent study. B: priority 2, 30 min, 50 recent min. C: priority 1, 45 min, no recent study. | A 0.90, B 0.62, C 0.50 → A | A 0.900, B 0.617, C 0.500 → **A** | A | `smart_helper_test` |
| Time fit and recent study | 30 min. A: priority 3, 90 min, 25 recent. B: priority 2, 30 min, none. | A 0.70, B 0.75 → B | A 0.700, B 0.750 → **B** | A | `smart_helper_test` |
| No history | 60 min. A: priority 3, 120 min. B: priority 2, 30 min. No sessions. | A 0.85, B 0.75 → A; says no history used | A 0.850, B 0.750 → **A**; explanation says no history used | A | `smart_helper_test`, `recommendation_card_test` |
| No eligible task | No tasks, or all completed | Create-a-task message; nothing recommended | `NoEligibleTask`; card shows **Create a task** | none | `smart_helper_test`, `recommendation_card_test` |
| Invalid input | A task with 0 min; available 3 or 200 | 0-min task skipped; 3 and 200 rejected | 0-min task skipped; 3 and 200 throw a validation error | 0-min task skipped | `smart_helper_test` |
| Boundary | 120-min task with 5 available; 5-min task with 120; 500 recent min | Fit 0.04 and 1.00; R ≈ 0.05, never below 0 | Fit 0.0417 and 1.000; R 0.0476 (> 0) | — | `smart_helper_test` |
| 7-day window | Sessions 6 and 8 days ago, 100 min each, on two otherwise equal tasks | 6-day session counts; 8-day does not | 100 vs 0 recent minutes; the task without recent study wins | — | `helper_providers_test` (real SQLite) |
| Tie | Two tasks, priority 2, 30 min, no study; 30 available | Both 0.75; created first wins; then lower id | Both 0.750; created first chosen; with equal creation times the lower id wins | same | `smart_helper_test` |
| Counterexample | 30 available. X: priority 2, 120 min, due tomorrow. Y: priority 2, 30 min, due in two weeks. | X 0.53, Y 0.75 → Y despite X's deadline | X 0.525, Y 0.750 → **Y** | X (created first) | `smart_helper_test` |

**Result:** all development cases behave as the proposal specifies. These are correctness checks, so no accuracy figure is reported from them.

**Where the helper and baseline differ here, and why:**
- **Time fit and recent study:** the helper prefers the task that fits the available time and hasn't just been studied. The baseline always picks the higher priority. Which is "right" depends on the student, which is exactly what held-out cases with pre-agreed acceptable answers are meant to settle.
- **Counterexample:** the helper picks the short task and ignores X's deadline, because deadlines are not an input. The baseline picks X only because it was created first, not because it knows the deadline either.

## 7. Held-out evaluation (NOT RUN)

**Required by proposal §9:**
1. At least **5 valid held-out scenarios**, separate from the development cases above.
2. The acceptable choice(s) for each must be **written and frozen before** running either method.
3. Run the helper and the baseline on the **same** scenarios.
4. **Metric:** top-choice agreement with the acceptable choices, reported as correct/total and as a percentage, for both methods.
5. **If the results lead to changing the helper,** new held-out cases must be reserved for the next measurement.

**Planned scenario outlines** (from the earlier plan; still without concrete values):

| # | Scenario | Behaviour to check |
|---|---|---|
| 1 | Single eligible task | Recommend the only eligible task |
| 2 | Different priorities and durations | Highest score; compare with the baseline |
| 3 | Available time shorter than several estimates | The fit formula decides the ranking |
| 4 | Highest-priority task is completed | It is excluded; recommend from the rest |
| 5 | Equal scores | Oldest task, then the lowest id |

Scenarios 4 and 5 overlap the development cases' behaviour, so they need **new concrete inputs** to count as held out.

**Still needed:**
- the concrete inputs and the frozen acceptable choices for each scenario, with the date they were frozen
- the run itself (it can be automated as a test that reads the frozen file, so it is repeatable)
- the results table, error analysis and any justified revision

**Frozen-case template:**

| ID | Tasks (priority, estimate, status, created) | Recent minutes per task | Available | Acceptable choice(s) | Frozen on |
|---|---|---|---|---|---|
| H1 | | | | | |
| H2 | | | | | |
| H3 | | | | | |
| H4 | | | | | |
| H5 | | | | | |

**Results** (to be filled in only after a real run):

| ID | Helper choice | Correct? | Baseline choice | Correct? |
|---|---|---|---|---|
| … | | | | |
| **Total** | | n / N (%) | | n / N (%) |

## 8. Offline computation and restart

- **No network, no cloud.** The recommendation is computed on the device in `recommendationProvider`, from the local task list and `SessionRepository.minutesByTaskSince(now − 7 days)`. The app has no network code.
- **Recalculated on every change**, through the shared revision counter: after task or session changes, when the available time changes, and at every launch.
- **Nothing is stored for the helper.** After a restart it is recomputed from the persisted tasks and sessions, whose survival across restarts is covered by the on-device integration tests ([docs/TEST_REPORT.md](docs/TEST_REPORT.md)). There is no dedicated test of the card after a restart.

## 9. Alternative considered

- **Deadline-aware scoring:** add a due date to tasks and a deadline term. It would fix the counterexample, but needs a new task field, a migration and UI changes outside the proposal. It is left as future work.
- **A trained model:** rejected. There's no training data, it would be hard to explain, and the proposal requires a transparent local heuristic.

## 10. Limitations

- **No deadlines, exam dates, dependencies or difficulty:** a high score is decision support, not a guarantee.
- **The weights (0.50 / 0.30 / 0.20) and the 25-minute recent-activity scale** come from the proposal and have not been tuned or validated on real student data.
- **Recent activity counts minutes, not outcomes:** a long, unproductive session lowers a task's score just as much as a productive one.
- **Small, synthetic examples only so far.** No result here is evidence of real-world effectiveness.

## 11. Tests and coverage

| Test file | What it checks |
|---|---|
| [`test/domain/smart_helper_test.dart`](test/domain/smart_helper_test.dart) | Every §9 example, ties, invalid input, boundaries, explanation text, ranking |
| [`test/providers/helper_providers_test.dart`](test/providers/helper_providers_test.dart) | 7-day window on real SQLite, Settings default, recalculation on available-time change, no tasks |
| [`test/presentation/recommendation_card_test.dart`](test/presentation/recommendation_card_test.dart) | Card, Why this task?, no history, Use task, Not now, override, all-completed state, refusal during a session, large text |

**Coverage:** `smart_helper.dart` 100%, `helper_providers.dart` 100%, `recommendation_card.dart` 97.1% ([COVERAGE.md](COVERAGE.md)).

## 12. Individual contributions

Deferred.
