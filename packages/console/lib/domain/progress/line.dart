import 'package:sip_console/utils/ansi.dart';

class Line {
  Line({
    required this.key,
    required String frame,
    required this.doneFrame,
    required this.text,
  })  : _frame = frame,
        _stopwatch = Stopwatch() {
    _stopwatch
      ..reset
      ..start();
  }

  final int key;
  String _frame;
  final String text;
  final String doneFrame;
  bool _done = false;
  bool isDone() => _done;
  final Stopwatch _stopwatch;

  void updateFrame(String frame) => _frame = frame;

  void finish() {
    _done = true;
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

  String get loading => '${lightGreen.wrap(_frame)} $text $_time';
  String get done => '${lightGreen.wrap(doneFrame)} $text $_time';
}
