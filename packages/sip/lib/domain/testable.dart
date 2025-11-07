import 'package:path/path.dart' as path;

class Testable {
  Testable({required this.absolute, required this.optimizedPath})
    : fileName = path.basenameWithoutExtension(absolute),
      relativeToOptimized = path.relative(
        absolute,
        from: path.dirname(optimizedPath),
      );

  final String absolute;
  final String fileName;
  final String optimizedPath;
  final String relativeToOptimized;
}
