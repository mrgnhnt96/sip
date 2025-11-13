import 'package:sip_cli/src/utils/stopwatch_extensions.dart';

class Time {
  Time() : _stopwatches = {TimeKey.core: Stopwatch()..start()};

  final Map<TimeKey, Stopwatch> _stopwatches;

  Stopwatch get(TimeKey key) {
    return _stopwatches[key] ??= Stopwatch()..start();
  }

  String snapshot(TimeKey key) {
    return get(key).format();
  }

  void cleanUp() {
    for (final stopwatch in _stopwatches.values) {
      stopwatch.stop();
    }

    _stopwatches.clear();
  }
}

enum TimeKey { core, test }
