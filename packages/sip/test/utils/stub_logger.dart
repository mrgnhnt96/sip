import 'package:mason_logger/mason_logger.dart';
import 'package:mocktail/mocktail.dart';

extension LoggerX on Logger {
  void stub({
    Level level = Level.quiet,
  }) {
    final instance = this;
    when(() => instance.level).thenReturn(level);
    when(() => instance.progress(any())).thenReturn(_MockProgress());
  }
}

class _MockProgress extends Mock implements Progress {}
