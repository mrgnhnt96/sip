/// A progress animation.
class ProgressAnimation {
  ProgressAnimation({
    required this.frames,
    this.stepDuration = const Duration(milliseconds: 100),
  }) : assert(frames.isNotEmpty, 'frames must not be empty');

  const ProgressAnimation.defaults()
      : frames = defaultFrames,
        stepDuration = const Duration(milliseconds: 100);

  static const defaultFrames = [
    '⠋',
    '⠙',
    '⠹',
    '⠸',
    '⠼',
    '⠴',
    '⠦',
    '⠧',
    '⠇',
    '⠏',
  ];

  /// The list of animation frames.
  final List<String> frames;

  final Duration stepDuration;

  Future<void> step() => Future<void>.delayed(stepDuration);

  String get(int index) => frames[index % frames.length];
}
