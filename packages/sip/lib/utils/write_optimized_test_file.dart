import 'package:sip_cli/domain/testable.dart';

String writeOptimizedTestFile(
  Iterable<Testable> testables, {
  required bool isFlutterPackage,
}) {
  var count = 0;
  final indexedTestables = testables.map((e) => (count++, e)).toList();
  return '''
${_testImport(isFlutterPackage: isFlutterPackage)}
${indexedTestables.map((e) => _writeImport(e.$1, e.$2)).join('\n')}

void main() {
  ${indexedTestables.map((e) => _writeTest(e.$1, e.$2)).join('\n  ')}
}
''';
}

String _testImport({required bool isFlutterPackage}) {
  var package = 'test';
  if (isFlutterPackage) {
    package = 'flutter_test';
  }

  return "import 'package:$package/$package.dart';";
}

String _writeTest(int index, Testable testable) {
  return "group('${testable.relativeToOptimized}', () => _i$index.main());";
}

String _writeImport(int index, Testable testable) {
  return "import '${testable.relativeToOptimized}' as _i$index;";
}
