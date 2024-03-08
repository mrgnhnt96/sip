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

    final times = [
      if (hours > 0) '${formattedHours}h',
      if (minutes > 0) '${formattedMinutes}m',
      '${formattedSeconds}s',
    ];

    final extraNumbersPattern = RegExp(r'\.(\d)\d+(\w)');
    for (final time in times) {
      final match = extraNumbersPattern.firstMatch(time);
      var updatedTime = time;

      if (match != null) {
        final soloNumber = match.group(1)!;
        final indicator = match.group(2)!;

        updatedTime = '${time.split('.').first}.$soloNumber$indicator';
      }

      updatedTime = updatedTime.replaceAll('.0', '');

      times[times.indexOf(time)] = updatedTime;
    }

    return times.join(' ').trim();
  }
}
