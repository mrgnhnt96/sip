import 'package:mason_logger/mason_logger.dart';
import 'package:sip_cli/domain/filter_type.dart';
import 'package:test/test.dart';

void main() {
  group(FilterType, () {
    group('#formatter', () {
      group(FilterType.dartTest, () {
        final formatter = FilterType.dartTest.formatter!;

        test('should output seconds, index, and loading', () {
          const output = '00:00 +0: loading test/methods_test.dart';

          final (message: formatted, count: (:passing, :failing), :isError) =
              formatter(output);

          const expected = '00:00 +0: loading tests...';

          expect(formatted, expected);
          expect(isError, false);
          expect(passing, 0);
          expect(failing, 0);
        });

        test('should output seconds, index, and finished', () {
          const output = '00:03 +5: All tests passed!';

          final (message: formatted, count: (:passing, :failing), :isError) =
              formatter(output);

          const expected = '00:03 +5: Ran all tests';

          expect(formatted, expected);
          expect(isError, false);
          expect(passing, 5);
          expect(failing, 0);
        });

        test('should output seconds, index, and test name', () {
          const output =
              '00:01 +178: test/e2e/run/env_files/env_files_test.dart: env files e2e runs gracefully command: be reset';

          final (message: formatted, count: (:passing, :failing), :isError) =
              formatter(output);

          const expected =
              '00:01 +178: env files e2e runs gracefully command: be reset';

          expect(resetAll.wrap(formatted), expected);
          expect(isError, false);
          expect(passing, 178);
          expect(failing, 0);
        });

        test('should detect errors', () {
          const output = '''
00:00 +132 -3: test/lib/domain/filter_type_test.dart: FilterType #formatter example [E]                                                                                                                                   
  Expected: false
    Actual: <true>
  
  package:matcher                             expect
  test/lib/domain/filter_type_test.dart 54:9  main.<fn>.<fn>.<fn>
  

To run this test again: /Users/morgan/fvm/versions/3.29.3/bin/cache/dart-sdk/bin/dart test test/lib/domain/filter_type_test.dart -p vm --plain-name 'FilterType #formatter example'
''';

          final (message: formatted, count: (:passing, :failing), :isError) =
              formatter(output);

          const expected =
              '00:00 +132 -3: test/lib/domain/filter_type_test.dart | FilterType #formatter example [E]\n';

          expect(resetAll.wrap(formatted), expected);
          expect(isError, true);
          expect(passing, 132);
          expect(failing, -3);
        });
      });
    });
  });
}
