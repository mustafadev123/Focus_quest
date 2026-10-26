
import 'dart:async';

import 'package:shared_preferences/shared_preferences.dart';

class FocusTimerService {
  static const String _elapsedKey = 'focus_elapsed_seconds';
  static const String _startedKey = 'focus_started_at';
  static const String _runningKey = 'focus_is_running';
  static const String _finishedKey = 'focus_is_finished';

  DateTime? _startedAt;
  Duration _elapsedBeforeStart = Duration.zero;
  bool _isRunning = false;
  bool _isFinished = false;

  Timer? _ticker;

  Duration get elapsed {
    if (_isRunning && _startedAt != null) {
      return _elapsedBeforeStart +
          DateTime.now().difference(_startedAt!);
    }
    return _elapsedBeforeStart;
  }

  bool get isRunning => _isRunning;
  bool get isFinished => _isFinished;

  Future<void> restore() async {
    final prefs = await SharedPreferences.getInstance();

    _elapsedBeforeStart = Duration(
      seconds: prefs.getInt(_elapsedKey) ?? 0,
    );

    _isFinished = prefs.getBool(_finishedKey) ?? false;
    _isRunning = prefs.getBool(_runningKey) ?? false;

    final storedStart = prefs.getInt(_startedKey);

    if (_isRunning && storedStart != null) {
      final previousStart =
          DateTime.fromMillisecondsSinceEpoch(storedStart);
      _elapsedBeforeStart += DateTime.now().difference(previousStart);
      _startedAt = DateTime.now();
      _startTicker();
      await _persist();
    } else {
      _startedAt = null;
    }
  }

  Future<void> start() async {
    if (_isRunning || _isFinished) return;

    _startedAt = DateTime.now();
    _isRunning = true;
    _startTicker();
    await _persist();
  }

  Future<void> pause() async {
    if (!_isRunning) return;

    _elapsedBeforeStart = elapsed;
    _startedAt = null;
    _isRunning = false;
    _ticker?.cancel();

    await _persist();
  }

  Future<void> resume() async {
    if (_isRunning || _isFinished) return;
    await start();
  }

  Future<Duration> finish() async {
    if (_isRunning) {
      _elapsedBeforeStart = elapsed;
    }

    _startedAt = null;
    _isRunning = false;
    _isFinished = true;
    _ticker?.cancel();

    await _persist();
    return _elapsedBeforeStart;
  }

  Future<void> reset() async {
    _ticker?.cancel();
    _startedAt = null;
    _elapsedBeforeStart = Duration.zero;
    _isRunning = false;
    _isFinished = false;

    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_elapsedKey);
    await prefs.remove(_startedKey);
    await prefs.remove(_runningKey);
    await prefs.remove(_finishedKey);
  }

  Future<void> _persist() async {
    final prefs = await SharedPreferences.getInstance();

    await prefs.setInt(_elapsedKey, _elapsedBeforeStart.inSeconds);
    await prefs.setBool(_runningKey, _isRunning);
    await prefs.setBool(_finishedKey, _isFinished);

    if (_isRunning && _startedAt != null) {
      await prefs.setInt(
        _startedKey,
        _startedAt!.millisecondsSinceEpoch,
      );
    } else {
      await prefs.remove(_startedKey);
    }
  }

  void _startTicker() {
    _ticker?.cancel();
    _ticker = Timer.periodic(
      const Duration(seconds: 1),
      (_) {},
    );
  }

  void dispose() {
    _ticker?.cancel();
  }
}
