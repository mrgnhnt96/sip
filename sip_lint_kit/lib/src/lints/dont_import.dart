import 'package:lint_kit/lint_kit.dart';
import 'package:sip_lint_kit/src/lints/utils/linter.dart';

class DontImport implements Linter {
  const DontImport();

  static const code = 'dont_import';
  static const message = 'Do not import this package';

  @override
  Iterable<Lint> lint(AnalyzedFile file) sync* {
    final lines = file.content.split('\n');
    for (final (index, line) in lines.indexed) {
      if (line.contains("import 'package:")) {
        yield Lint(
          code: code,
          message: 'JK this is fine',
          range: Range.entireLine(index),
          path: file.path,
        ).addIgnoreActions(lines);
      }
    }
  }
}
