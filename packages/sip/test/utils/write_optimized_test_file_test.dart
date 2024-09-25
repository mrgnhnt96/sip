import 'package:sip_cli/domain/testable.dart';
import 'package:sip_cli/utils/write_optimized_test_file.dart';
import 'package:test/test.dart';

void main() {
  group('writeOptimizedTestFile', () {
    late List<Testable> testables;
    setUp(() {
      testables = [
        Testable(
          optimizedPath: './test/.optimized_test.dart',
          absolute: './test/lib/core_1/test1_test.dart',
          testType: null,
        ),
        Testable(
          optimizedPath: './test/.optimized_test.dart',
          absolute: './test/lib/core/test1_test.dart',
          testType: null,
        ),
      ];
    });

    test('does not duplicate name imports', () {
      final content = writeOptimizedTestFile(
        testables,
        isFlutterPackage: false,
        barrelFile: null,
      );

      final namespacesPattern = RegExp(r"import \'.*\' as (.*)\;");

      final matches = namespacesPattern.allMatches(content);
      final namespaces = matches.map((e) => e.group(1));
      final uniqueNamespaces = {...namespaces};

      expect(namespaces.length, 2);
      expect(namespaces.length, uniqueNamespaces.length);
    });

    test('includes barrel file when provided', () {
      final content = writeOptimizedTestFile(
        testables,
        isFlutterPackage: false,
        barrelFile: (packageName: 'domain', barrelFile: 'domain.dart'),
      );

      expect(content, contains("import 'package:domain/domain.dart';"));
    });

    test('does not include barrel file when not provided', () {
      final content = writeOptimizedTestFile(
        testables,
        isFlutterPackage: false,
        barrelFile: null,
      );

      expect(content, isNot(contains("import 'package:domain/domain.dart';")));
    });
  });
}
