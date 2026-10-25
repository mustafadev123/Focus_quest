# FocusQuest Architecture

## 1. Overview

FocusQuest is planned as an offline-first Flutter application for organizing study tasks and recording focus sessions.

The application will use a layered architecture to keep the user interface, application logic, and local storage separate.

## 2. Architecture Layers

### Presentation Layer

This layer contains the application screens and reusable widgets.

Planned screens:
- Dashboard
- Add/Edit Task
- Focus Session
- History & Insights
- Settings

Riverpod will manage shared application state and notify screens when saved data changes.

### Domain Layer

This layer contains the application's main rules and logic.

It will handle:
- Study-task validation
- Focus-session state transitions
- Study-time calculations
- Smart-helper scoring and explanations
- Recommendation baseline and evaluation logic

The domain logic should not depend directly on Flutter UI widgets.

### Data Layer

This layer manages local persistence.

SQLite will store:
- Study tasks
- Focus-session records

SharedPreferences will store simple settings such as focus duration and reminder preferences.

Repository classes will provide a consistent interface between application logic and local storage.

## 3. Main Data Relationship

One study task can have multiple focus-session records.

Each focus session references its parent study task through `taskId`.

Deleting a task will require confirmation and remove its related session records in a database transaction.

## 4. State Management

Riverpod is the planned state-management solution.

It will provide access to repositories and settings, manage asynchronous loading and errors, and keep data consistent across screens.

## 5. Focus-Session Lifecycle

A focus session will support these states:

- Ready
- Running
- Paused
- Awaiting save
- Saved

The application will record elapsed-time checkpoints so that session recovery does not depend only on a timer remaining in memory.

Saving a finished session should create one history record and refresh the dashboard totals.

## 6. Smart Helper

The smart helper will use a local rule-based scoring method to recommend an eligible study task.

Its logic will be separate from the screen widgets. It will explain recommendations, allow the user to dismiss or override them, and show an appropriate message when there are no eligible tasks.

The helper and a simple baseline will be evaluated using documented test cases.

## 7. Error Handling

The application will validate input before saving records.

Database failures should produce clear messages and preserve user input where possible. Destructive operations will require confirmation.

Asynchronous screen operations will check widget lifecycle state before updating the UI.

## 8. Testing Plan

Planned testing includes:
- Unit tests for validation, scoring, and session logic
- Widget tests for screen interactions and errors
- Integration tests for SQLite operations and persistence
- Tests for session recovery after application restart
- A test-coverage report

## 9. Status

This document describes the planned architecture. Implementation details will be updated as the system is built and tested, following the required instructor approval.
