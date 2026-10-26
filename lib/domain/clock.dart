/// Source of the current time, injected so tests can use a fixed clock.
typedef Clock = DateTime Function();

DateTime systemClock() => DateTime.now();
