import 'package:lint_kit/lint_kit.dart';
import 'package:sip_lint_kit/src/lints/bad_object.dart';
import 'package:sip_lint_kit/src/lints/dont_import.dart';
import 'package:sip_lint_kit/src/lints/utils/linter.dart';

class SipLintKitAnalysis implements LintKitAnalyzer {
  const SipLintKitAnalysis();

  @override
  String get packageName => 'sip_lint_kit';

  @override
  List<LintKitAnalyzer> get plugins => [];

  List<Linter> get _linters => [
        DontImport(),
        BadObject(),
      ];

  @override
  Future<List<Message>> analyze(
    AnalyzedFile file,
    AnalysisOptions? options,
  ) async {
    final messages = <Lint>[];

    for (final linter in _linters) {
      switch (linter.lint(file)) {
        case final Future<Iterable<Lint>> lint:
          final result = await lint;
          messages.addAll(result);
        case final Iterable<Lint> lint:
          messages.addAll(lint);
      }
    }

    return messages;
  }
}
