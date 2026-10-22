import 'package:sip_cli/src/utils/test_library_annotations.dart';
import 'package:test/test.dart';

void main() {
  group(TestLibraryAnnotations, () {
    Map<String, String> parse(String content) =>
        TestLibraryAnnotations.parse(content).arguments;

    test('reads every annotation package:test reads', () {
      const content = '''
@Tags(['slow', 'golden'])
@TestOn('vm')
@Skip('flaky')
@Timeout(Duration(seconds: 45))
@OnPlatform({'windows': Skip('no symlinks')})
@Retry(3)
library;

import 'package:test/test.dart';
''';

      expect(parse(content), {
        'tags': "['slow', 'golden']",
        'testOn': "'vm'",
        'skip': "'flaky'",
        'timeout': 'Timeout(Duration(seconds: 45))',
        'onPlatform': "{'windows': Skip('no symlinks')}",
        'retry': '3',
      });
    });

    test('reads @Skip() without a reason as skip: true', () {
      expect(parse('@Skip()\nlibrary;'), {'skip': 'true'});
    });

    test('keeps Timeout named constructors and Timeout.none', () {
      expect(parse('@Timeout.factor(2)\nlibrary;'), {
        'timeout': 'Timeout.factor(2)',
      });
      expect(parse('@Timeout.none\nlibrary;'), {'timeout': 'Timeout.none'});
    });

    test('drops the import prefix the file used for package:test', () {
      const content = '''
@t.Tags(['slow'])
@t.Timeout.factor(2)
@t.OnPlatform({'windows': t.Timeout.factor(3), 'mac': t.Skip('t.Skip')})
library;

import 'package:test/test.dart' as t;
''';

      expect(parse(content), {
        'tags': "['slow']",
        'timeout': 'Timeout.factor(2)',
        'onPlatform': "{'windows': Timeout.factor(3), 'mac': Skip('t.Skip')}",
      });
    });

    test(
      'joins multi-line arguments and drops comments and trailing commas',
      () {
        const content = '''
@OnPlatform({
  // Windows runners are slow.
  'windows': Timeout.factor(2),
  'mac': Skip('see "#12"'), /* for now */
})
library;
''';

        expect(parse(content), {
          'onPlatform':
              '''{ 'windows': Timeout.factor(2), 'mac': Skip('see "#12"'), }''',
        });
      },
    );

    test(
      'skips comments, a script tag and other annotations before library',
      () {
        const content = '''
#!/usr/bin/env dart
// Copyright header with @Tags(['not-this']).
/* A block /* nested */ comment. */
/// Library docs.
@JS()
@Tags(['real'])
library my_test;
''';

        expect(parse(content), {'tags': "['real']"});
      },
    );

    test("reads string arguments holding ')' and quotes", () {
      expect(parse('''@Skip("can't parse ) yet")\nlibrary;'''), {
        'skip': '''"can't parse ) yet"''',
      });
      expect(parse("@TestOn(r'vm && !windows')\nlibrary;"), {
        'testOn': "r'vm && !windows'",
      });
    });

    test('ignores annotations that are not on the library directive', () {
      expect(parse("import 'a.dart';\n@Tags(['x'])\nvoid main() {}"), isEmpty);
      expect(parse("@Tags(['x'])\nvoid main() {}"), isEmpty);
      expect(parse("@Tags(['x'])\nlibraryish() {}"), isEmpty);
    });

    test('is empty for a file without annotations', () {
      expect(TestLibraryAnnotations.parse('void main() {}').isEmpty, isTrue);
      expect(TestLibraryAnnotations.parse('library;').isEmpty, isTrue);
    });

    test('source is the arguments as named arguments', () {
      expect(
        TestLibraryAnnotations.parse(
          "@Tags(['slow'])\n@TestOn('vm')\nlibrary;",
        ).source,
        ", tags: ['slow'], testOn: 'vm'",
      );
    });
  });
}
