# FocusQuest Smart Helper

## 1. Feature Overview

FocusQuest will include a local, rule-based smart helper that recommends a study task based on the task's priority, estimated duration, available study time, and recent study activity.

The helper is designed to explain its recommendation and allow the student to accept, dismiss, or choose another task.

This is a rule-based scoring heuristic, not a trained machine-learning model. The calculation will be kept separate from the Flutter user interface.

## 2. Inputs and Limits

The helper will use the following inputs:

- Task priority: 1 (low), 2 (medium), or 3 (high).
- Estimated task duration: 5–120 minutes.
- Available study time: 5–120 minutes.
- Recent study activity: recorded study minutes during the previous seven days.
- Task status: only valid, noncompleted tasks are eligible.

Invalid task durations will be excluded. Invalid available-time values will produce a clear validation message.

## 3. Scoring Method

For each eligible task:

- P = (priority - 1) / 2
- F = min(availableMinutes / estimatedMinutes, 1)
- R = 1 / (1 + recentStudyMinutes / 25)

The final score is:

**Score = 0.50P + 0.30F + 0.20R**

The helper recommends the eligible task with the highest score.

If scores are tied, the task with the oldest creation time wins. If creation times are equal, the lowest task ID wins.

The explanation will identify how task priority, available-time fit, and recent study activity influenced the recommendation.

## 4. User Control and Fallbacks

The helper will support these behaviors:

- **Accept:** select the recommended task without automatically starting a session.
- **Dismiss:** hide or decline the recommendation.
- **Override:** allow the student to choose another task.
- **No eligible tasks:** display a message prompting the student to create a task.
- **No study history:** calculate a recommendation using available task information and clearly disclose that no history was available.
- **Invalid input:** show an understandable error or exclude invalid task data.

The helper will not silently create, update, or delete records.

## 5. Baseline

The baseline will select the highest-priority eligible task.

When priorities are tied, it will select the oldest task. If creation times are equal, it will select the lowest task ID.

The helper and baseline will be evaluated on the same valid scenarios.

## 6. Evaluation Plan

Evaluation will include:

- Normal task data.
- Empty history and no eligible tasks.
- Invalid inputs.
- Minimum and maximum duration values.
- Recent-activity history cutoff and unusually large activity totals.
- Tied task scores.
- A counterexample involving an urgent deadline that the scoring method does not consider.

For the graduate pathway, at least five valid held-out scenarios will be defined before evaluation. The acceptable choices for each scenario will be recorded before running either method.

The primary metric will be top-choice agreement with the predefined acceptable choices, reported as the number of correct recommendations divided by the number of test cases and as a percentage.

Actual evaluation results will be added only after running the tests. Expected results and synthetic examples will not be presented as completed experiments.

### 6.1 Held-Out Evaluation Scenarios

The following five scenarios are proposed for evaluation. Record the expected acceptable choice before running the helper or baseline, and do not use these scenarios to tune the scoring formula before evaluating them.

| Scenario | Input or condition | Expected behavior to verify |
|---|---|---|
| 1. Single eligible task | One valid, noncompleted task | Recommend the only eligible task. |
| 2. Different priorities | Multiple valid tasks with different priorities and durations | Calculate every eligible task's score and select the highest-scoring task. Compare it with the highest-priority baseline. |
| 3. Available-time fit | Available time is shorter than the estimated durations of multiple tasks | Apply the defined fit formula and rank tasks by their final scores. |
| 4. Completed high-priority task | The highest-priority task is completed, while at least one valid task remains incomplete | Exclude the completed task and recommend from the eligible tasks. |
| 5. Equal scores | Two eligible tasks have equal scores | Choose the oldest task; if creation times match, choose the lowest task ID. |

These are planned scenarios, not completed experiments. Before evaluation, define concrete task values, recent-study totals, expected scores, acceptable choices, and the baseline choice for each case.

### 6.2 Evaluation Procedure

1. Prepare the concrete test inputs and record expected acceptable choices before execution.
2. Run the helper and the baseline against the same scenario inputs.
3. Record the helper's actual recommendation, the baseline recommendation, and whether each