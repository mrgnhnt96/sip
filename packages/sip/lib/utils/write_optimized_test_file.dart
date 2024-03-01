import 'package:sip_cli/domain/testable.dart';

String writeOptimizedTestFile(
  Iterable<Testable> testables, {
  required bool isFlutterPackage,
}) {
  String testImport() {
    var package = 'test';
    if (isFlutterPackage) {
      package = 'flutter_test';
    }

    return "import 'package:$package/$package.dart';";
  }

  return '''
${testImport()}
${testables.map(_writeImport).join('\n')}

void main() {
  ${testables.map(_writeTest).join('\n  ')}
}
''';
}

String _writeTest(Testable testable) {
  return "group('${testable.relativeToOptimized}', () => ${testable.fileName}.main());";
}

String _writeImport(Testable testable) {
  return "import '${testable.relativeToOptimized}' as ${testable.fileName};";
}
