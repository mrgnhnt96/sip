extension StopWatchX on Stopwatch {
  String format() => TimeX.format(elapsedMilliseconds);
}

class TimeX {
  const TimeX._();
  static String format(int ms) {
    final seconds = ms / 1000;
    final minutes = seconds ~/ 60;
    final hours = minutes ~/ 60;

    final formattedSeconds = (seconds % 60).toString();
    final formattedMinutes = (minutes % 60).toString();
    final formattedHours = hours.toString();

    return [
      if (hours > 0) '${formattedHours}h',
      if (minutes > 0) '${formattedMinutes}m',
      '${formattedSeconds}s',
    ].join(' ').trim().replaceAll('.0', '');
  }
}
