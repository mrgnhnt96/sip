class ProgressAnimation {
  ProgressAnimation({
    this.frames = _defaultFrames,
    this.step = const Duration(milliseconds: 100),
    this.done = '✓',
  }) : assert(frames.length > 0, 'frames must not be empty');

  static const _defaultFrames = [
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
  final String done;

  final Duration step;
}
