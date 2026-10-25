# FocusQuest — Focus & Study Planner

## Project Overview

FocusQuest is a Flutter mobile application designed to help students organize study tasks, track focus sessions, and review their study activity.

The goal is to provide a simple app that works offline and stores information locally.

## Team

**Team Name:** Desi_hackers

- **Muhammad Mustufa:** Study task management, dashboard, SQLite repositories, and settings.
- **Praneeth Shankar Ravuri:** Focus session workflow, session recovery, smart helper, local notifications, and study-summary file operations.

Both team members will contribute to architecture, testing, documentation, and integration.

## Planned Screens

1. Dashboard
2. Add/Edit Task
3. Focus Session
4. History & Insights
5. Settings

## Planned Features

- Create, view, edit, and delete study tasks.
- Start, pause, finish, and reset focus sessions.
- Save and review study-session records.
- Filter session history and view study-time summaries.
- Store user preferences locally.
- Recommend study tasks using an explainable local smart helper.
- Validate inputs and confirm destructive actions.
- Restore saved records after the application restarts.

## Technology Stack

- Flutter
- Dart
- SQLite using `sqflite`
- SharedPreferences
- Riverpod for state management
- Local notifications
- Local file operations

## Data Storage

SQLite will store study tasks and focus-session records. Each session will be associated with a study task.

SharedPreferences will store simple settings, such as preferred focus duration and reminder preferences.

The application is planned to work offline without a cloud database or remote AI service.

## Smart Helper

The smart helper will use a rule-based scoring method to recommend a suitable study task. It will explain its recommendation and allow the user to accept, dismiss, or choose another task.

Its results will be evaluated against a simple baseline using documented test cases.

## Testing and Documentation

The project will include unit tests, widget tests, integration tests, and a test-coverage report.

Technical decisions will be documented in `ARCHITECTURE.md`. The smart-helper approach and evaluation will be documented in `AI_FEATURE.md`.

## Project Management

GitHub is used for version control, and ClickUp is used to organize tasks, responsibilities, deadlines, and project progress.

- **Repository:** https://github.com/mustafadev123/Focus_quest
- **ClickUp Board:** https://app.clickup.com/90141781342/v/li/901422406428

## Current Status

This README describes the planned project scope. Implementation status, setup instructions, testing results, and known limitations will be updated as the work is completed and verified.
