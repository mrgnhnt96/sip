import 'package:sip_cli/src/domain/testable.dart';

String writeOptimizedTestFile(
  Iterable<Testable> testables, {
  required ({String packageName, String barrelFile})? barrelFile,
}) {
  var barrel = '';

  if (barrelFile != null) {
    final (:packageName, barrelFile: file) = barrelFile;
    barrel = "import 'package:$packageName/$file';\n";
  }

  var count = 0;
  final indexedTestables = testables.map((e) => (count++, e)).toList();
  return '''
import 'dart:async';
$barrel
import 'package:test/test.dart';
${indexedTestables.map((e) => _writeImport(e.$1, e.$2)).join('\n')}

void main() {
  ${indexedTestables.map((e) => _writeTest(e.$1, e.$2)).join('\n  ')}
}
''';
}

String _writeTest(int index, Testable testable) {
  return "group('${testable.relativeToOptimized}', () { _i$index.main(); });";
}

String _writeImport(int index, Testable testable) {
  return "import '${testable.relativeToOptimized}' as _i$index;";
}
