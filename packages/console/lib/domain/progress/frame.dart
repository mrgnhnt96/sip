import 'package:sip_console/domain/progress/progress_animation.dart';

class Frame {
  Frame({
    required this.success,
    required this.cancelled,
    required this.failure,
    required this.progress,
  });

  const Frame.defaults()
      : success = '✔',
        cancelled = '⚠',
        failure = '✖',
        progress = const ProgressAnimation.defaults();

  final String success;
  final String cancelled;
  final String failure;
  final ProgressAnimation progress;
}
