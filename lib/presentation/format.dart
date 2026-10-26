/// "4h 20m", "45m" or "2h", as in the Dashboard and History wireframes.
String formatStudyTime(int minutes) {
  final hours = minutes ~/ 60;
  final rest = minutes % 60;
  if (hours == 0) return '${rest}m';
  if (rest == 0) return '${hours}h';
  return '${hours}h ${rest}m';
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
