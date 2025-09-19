import 'dart:async';

import 'package:lint_kit/lint_kit.dart';

abstract interface class Linter {
  const Linter();

  FutureOr<Iterable<Lint>> lint(AnalyzedFile file);
}
