import 'package:lint_kit/lint_kit.dart';
import 'package:sip_lint_kit/src/sip_lint_kit_analysis.dart';

LintKitAnalyzer entrypoint() {
  return const SipLintKitAnalysis();
}
