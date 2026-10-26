/// "4h 20m", "45m" or "2h", as in the Dashboard and History wireframes.
String formatStudyTime(int minutes) {
  final hours = minutes ~/ 60;
  final rest = minutes % 60;
  if (hours == 0) return '${rest}m';
  if (rest == 0) return '${hours}h';
  return '${hours}h ${rest}m';
}

/// Timer display such as "18:42"; minutes are not wrapped into hours.
String formatClock(Duration duration) {
  final seconds = duration.inSeconds;
  final mm = (seconds ~/ 60).toString().padLeft(2, '0');
  final ss = (seconds % 60).toString().padLeft(2, '0');
  return '$mm:$ss';
}

/// Spoken form of [formatClock], e.g. "18 minutes 42 seconds".
String describeClock(Duration duration) {
  final minutes = duration.inMinutes;
  final seconds = duration.inSeconds % 60;
  return '$minutes ${minutes == 1 ? 'minute' : 'minutes'} '
      '$seconds ${seconds == 1 ? 'second' : 'seconds'}';
}

/// Spoken form of [formatStudyTime] for screen readers.
String describeStudyTime(int minutes) {
  final hours = minutes ~/ 60;
  final rest = minutes % 60;
  final parts = [
    if (hours > 0) '$hours ${hours == 1 ? 'hour' : 'hours'}',
    if (rest > 0 || hours == 0) '$rest ${rest == 1 ? 'minute' : 'minutes'}',
  ];
  return parts.join(' ');
}
