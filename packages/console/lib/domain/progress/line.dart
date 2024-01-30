import 'package:sip_console/domain/progress/finisher.dart';
import 'package:sip_console/domain/progress/frame.dart';
import 'package:sip_console/utils/ansi.dart';

/// A line is a single line of progress that can be updated and finished.
class Line {
  Line({
    required this.key,
    required Frame frames,
    required this.text,
  })  : _frames = frames,
        _stopwatch = Stopwatch() {
    _liveFrame = _frames.progress.get(0);

    _stopwatch
      ..reset
      ..start();
  }

  final int key;
  Frame _frames;

  String _liveFrame = '';

  final String text;
  bool _done = false;
  FinisherType? _finishedType;
  final Stopwatch _stopwatch;

  bool isDone() => _done;
  bool get wasSuccessful => _finishedType == FinisherType.success;
  bool get wasCancelled => _finishedType == FinisherType.cancelled;
  bool get wasFailure => _finishedType == FinisherType.failure;

  void updateFrame(String frame) => _liveFrame = frame;

  void finish(FinisherType type) {
    _done = true;
    _finishedType = type;
    _stopwatch.stop();
  }

  String get _time {
    final elapsedTime = _stopwatch.elapsed.inMilliseconds;
    final displayInMilliseconds = elapsedTime < 100;
    final time = displayInMilliseconds ? elapsedTime : elapsedTime / 1000;

    final formattedTime =
        displayInMilliseconds ? '${time}ms' : '${time.toStringAsFixed(1)}s';
    return '${darkGray.wrap('($formattedTime)')}';
  }

  String get success => '${lightGreen.wrap(_frames.success)} $text $_time';
  String get loading => '${lightGreen.wrap(_liveFrame)} $text $_time';
  String get failure => '${lightRed.wrap(_frames.failure)} $text $_time';
  String get cancelled => '${lightYellow.wrap(_frames.cancelled)} $text $_time';

  String get string {
    if (isDone()) {
      if (wasSuccessful) {
        return success;
      } else if (wasCancelled) {
        return cancelled;
      } else if (wasFailure) {
        return failure;
      }
    }

    return loading;
  }
}
