import 'dart:io';

import 'package:sip_cli/src/domain/filter_type.dart' as filter;
import 'package:sip_cli/src/domain/filter_type.dart';
import 'package:test/test.dart';

void main() {
  group(FilterType, () {
    final resetToStart = filter.resetToStart(hasTerminal: true);
    final clearToEnd = filter.clearToEnd(hasTerminal: true);

    group('#formatter', () {
      group(FilterType.dartTest, () {
        final formatter = FilterType.dartTest.formatter(
          hasTerminal: true,
          terminalColumns: 1000,
        )!;

        test('should output seconds, index, and loading', () {
          const output = '00:00 +0: loading test/methods_test.dart';

          final (
            message: formatted,
            count: (:passing, :failing, :skipped),
            :isError,
          ) = formatter(
            output,
          );

          final expected =
              '${resetToStart}00:00 +0: loading tests...$clearToEnd';

          expect(formatted, expected);
          expect(isError, false);
          expect(passing, 0);
          expect(skipped, 0);
          expect(failing, 0);
        });

        test('should output seconds, index, and finished', () {
          const output = '00:03 +5: All tests passed!';

          final (
            message: formatted,
            count: (:passing, :failing, :skipped),
            :isError,
          ) = formatter(
            output,
          );

          final expected =
              '${resetToStart}00:03 +5: Tests completed$clearToEnd';

          expect(formatted, expected);
          expect(isError, false);
          expect(passing, 5);
          expect(skipped, 0);
          expect(failing, 0);
        });

        test('should output seconds, index, and test name', () {
          const output =
              '00:01 +178: test/e2e/run/env_files/env_files_test.dart: env files e2e runs gracefully command: be reset';

          final (
            message: formatted,
            count: (:passing, :failing, :skipped),
            :isError,
          ) = formatter(
            output,
          );

          final expected =
              '${resetToStart}00:01 +178: env files e2e runs '
              'gracefully command: be reset$clearToEnd';

          expect(formatted, expected);
          expect(isError, false);
          expect(passing, 178);
          expect(skipped, 0);
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

          final (
            message: formatted,
            count: (:passing, :failing, :skipped),
            :isError,
          ) = formatter(
            output,
          );

          final expected =
              '${resetToStart}00:00 +132 -3: test/lib/domain/filter_type_test.dart | '
              'FilterType #formatter example [E]$clearToEnd\n';

          expect(formatted, expected);
          expect(isError, true);
          expect(passing, 132);
          expect(skipped, 0);
          expect(failing, 3);
        });

        test('should detect skipped tests', () {
          const output =
              '00:00 +132 ~2: test/lib/domain/filter_type_test.dart: FilterType #formatter example';

          final (
            message: formatted,
            count: (:passing, :failing, :skipped),
            :isError,
          ) = formatter(
            output,
          );

          final expected =
              '${resetToStart}00:00 +132 ~2: FilterType '
              '#formatter example$clearToEnd';

          expect(formatted, expected);
          expect(isError, false);
          expect(passing, 132);
          expect(skipped, 2);
          expect(failing, 0);
        });

        test('should ignore extra information', () {
          const output = _extraInfoDartTest;

          final (
            message: formatted,
            count: (:passing, :failing, :skipped),
            :isError,
          ) = formatter(
            output,
          );

          final expected =
              '${resetToStart}00:09 +96 ~2: Home Screen Trip '
              'shows when user has a trip$clearToEnd';

          expect(formatted, expected);
          expect(isError, false);
          expect(passing, 96);
          expect(skipped, 2);
          expect(failing, 0);
        });
      });

      group(FilterType.flutterTest, () {
        final formatter = FilterType.flutterTest.formatter(
          hasTerminal: true,
          terminalColumns: 1000,
        )!;

        test('should output seconds, index, and loading', () {
          const output =
              '00:01 +0: loading /Users/morgan/Documents/develop.nosync/couchsurfing/cushions/apps/mobile/packages/ui/test/enums/onboarding_branches_test.dart ';

          final (
            message: formatted,
            count: (:passing, :failing, :skipped),
            :isError,
          ) = formatter(
            output,
          );

          final expected =
              '${resetToStart}00:01 +0: loading tests...$clearToEnd';

          expect(formatted, expected);
          expect(isError, false);
          expect(passing, 0);
          expect(skipped, 0);
          expect(failing, 0);
        });

        test('should output seconds, index, and finished', () {
          const output = '00:03 +5: All tests passed!';

          final (
            message: formatted,
            count: (:passing, :failing, :skipped),
            :isError,
          ) = formatter(
            output,
          );

          final expected =
              '${resetToStart}00:03 +5: Tests completed$clearToEnd';

          expect(formatted, expected);
          expect(isError, false);
          expect(passing, 5);
          expect(skipped, 0);
          expect(failing, 0);
        });

        test('should output seconds, index, and test name', () {
          const output =
              '00:09 +77: /apps/mobile/packages/ui/test/lib/screens/home/home_screen_single_friend_request_test.dart: Single Friend Request shows when friend requests is accepted';
          final (
            message: formatted,
            count: (:passing, :failing, :skipped),
            :isError,
          ) = formatter(
            output,
          );

          final expected =
              '${resetToStart}00:09 +77: Single Friend Request '
              'shows when friend '
              'requests is accepted$clearToEnd';

          expect(formatted, expected);
          expect(isError, false);
          expect(passing, 77);
          expect(skipped, 0);
          expect(failing, 0);
        });

        test('should detect errors', () {
          IOOverrides.runWithIOOverrides(() {
            const output = '''
00:00 +132 -3: /test/lib/domain/filter_type_test.dart: FilterType #formatter example [E]                                                                                                                                   
  Expected: false
    Actual: <true>
  
  package:matcher                             expect
  test/lib/domain/filter_type_test.dart 54:9  main.<fn>.<fn>.<fn>
  

To run this test again: /Users/morgan/fvm/versions/3.29.3/bin/cache/dart-sdk/bin/dart test /test/lib/domain/filter_type_test.dart -p vm --plain-name 'FilterType #formatter example'
''';

            final (
              message: formatted,
              count: (:passing, :failing, :skipped),
              :isError,
            ) = formatter(
              output,
            );

            final expected =
                '${resetToStart}00:00 +132 -3: test/lib/domain/filter_type_test.dart | FilterType #formatter example [E]$clearToEnd\n';

            expect(formatted, expected);
            expect(isError, true);
            expect(passing, 132);
            expect(skipped, 0);
            expect(failing, 3);
          }, _TestIOOverrides('/'));
        });

        test('should detect skipped tests', () {
          const output =
              '00:00 +132 ~2: /test/lib/domain/filter_type_test.dart: FilterType #formatter example';

          final (
            message: formatted,
            count: (:passing, :failing, :skipped),
            :isError,
          ) = formatter(
            output,
          );

          final expected =
              '${resetToStart}00:00 +132 ~2: FilterType '
              '#formatter example$clearToEnd';

          expect(formatted, expected);
          expect(isError, false);
          expect(passing, 132);
          expect(skipped, 2);
          expect(failing, 0);
        });

        test('should ignore extra information', () {
          const output = _extraInfoFlutterTest;

          final (
            message: formatted,
            count: (:passing, :failing, :skipped),
            :isError,
          ) = formatter(
            output,
          );

          final expected =
              '${resetToStart}00:09 +96 ~2: Home Screen Trip shows '
              'when user has a trip$clearToEnd';

          expect(formatted, expected);
          expect(isError, false);
          expect(passing, 96);
          expect(skipped, 2);
          expect(failing, 0);
        });
      });
    });
  });
}

const _extraInfoFlutterTest = '''
type 'Null' is not a subtype of type 'Future<HttpClientRequest>'
type 'Null' is not a subtype of type 'Future<HttpClientRequest>'
type 'Null' is not a subtype of type 'Future<HttpClientRequest>'
type 'Null' is not a subtype of type 'Future<HttpClientRequest>'
type 'Null' is not a subtype of type 'Future<HttpClientRequest>'
type 'Null' is not a subtype of type 'Future<HttpClientRequest>'
type 'Null' is not a subtype of type 'Future<HttpClientRequest>'
type 'Null' is not a subtype of type 'Future<HttpClientRequest>'
type 'Null' is not a subtype of type 'Future<HttpClientRequest>'
type 'Null' is not a subtype of type 'Future<HttpClientRequest>'
type 'Null' is not a subtype of type 'Future<HttpClientRequest>'
type 'Null' is not a subtype of type 'Future<HttpClientRequest>'
type 'Null' is not a subtype of type 'Future<HttpClientRequest>'
type 'Null' is not a subtype of type 'Future<HttpClientRequest>'
type 'Null' is not a subtype of type 'Future<HttpClientRequest>'
type 'Null' is not a subtype of type 'Future<HttpClientRequest>'
type 'Null' is not a subtype of type 'Future<HttpClientRequest>'
type 'Null' is not a subtype of type 'Future<HttpClientRequest>'
type 'Null' is not a subtype of type 'Future<HttpClientRequest>'
type 'Null' is not a subtype of type 'Future<HttpClientRequest>'
type 'Null' is not a subtype of type 'Future<HttpClientRequest>'
type 'Null' is not a subtype of type 'Future<HttpClientRequest>'
type 'Null' is not a subtype of type 'Future<HttpClientRequest>'
type 'Null' is not a subtype of type 'Future<HttpClientRequest>'
type 'Null' is not a subtype of type 'Future<HttpClientRequest>'
type 'Null' is not a subtype of type 'Future<HttpClientRequest>'
type 'Null' is not a subtype of type 'Future<HttpClientRequest>'
type 'Null' is not a subtype of type 'Future<HttpClientRequest>'
type 'Null' is not a subtype of type 'Future<HttpClientRequest>'
type 'Null' is not a subtype of type 'Future<HttpClientRequest>'
00:09 +96 ~2: /Users/morgan/Documents/develop.nosync/couchsurfing/cushions/apps/mobile/packages/ui/test/lib/screens/home/home_screen_trip_test.dart: Home Screen Trip shows when user has a trip
''';
const _extraInfoDartTest = '''
type 'Null' is not a subtype of type 'Future<HttpClientRequest>'
type 'Null' is not a subtype of type 'Future<HttpClientRequest>'
type 'Null' is not a subtype of type 'Future<HttpClientRequest>'
type 'Null' is not a subtype of type 'Future<HttpClientRequest>'
type 'Null' is not a subtype of type 'Future<HttpClientRequest>'
type 'Null' is not a subtype of type 'Future<HttpClientRequest>'
type 'Null' is not a subtype of type 'Future<HttpClientRequest>'
type 'Null' is not a subtype of type 'Future<HttpClientRequest>'
type 'Null' is not a subtype of type 'Future<HttpClientRequest>'
type 'Null' is not a subtype of type 'Future<HttpClientRequest>'
type 'Null' is not a subtype of type 'Future<HttpClientRequest>'
type 'Null' is not a subtype of type 'Future<HttpClientRequest>'
type 'Null' is not a subtype of type 'Future<HttpClientRequest>'
type 'Null' is not a subtype of type 'Future<HttpClientRequest>'
type 'Null' is not a subtype of type 'Future<HttpClientRequest>'
type 'Null' is not a subtype of type 'Future<HttpClientRequest>'
type 'Null' is not a subtype of type 'Future<HttpClientRequest>'
type 'Null' is not a subtype of type 'Future<HttpClientRequest>'
type 'Null' is not a subtype of type 'Future<HttpClientRequest>'
type 'Null' is not a subtype of type 'Future<HttpClientRequest>'
type 'Null' is not a subtype of type 'Future<HttpClientRequest>'
type 'Null' is not a subtype of type 'Future<HttpClientRequest>'
type 'Null' is not a subtype of type 'Future<HttpClientRequest>'
type 'Null' is not a subtype of type 'Future<HttpClientRequest>'
type 'Null' is not a subtype of type 'Future<HttpClientRequest>'
type 'Null' is not a subtype of type 'Future<HttpClientRequest>'
type 'Null' is not a subtype of type 'Future<HttpClientRequest>'
type 'Null' is not a subtype of type 'Future<HttpClientRequest>'
type 'Null' is not a subtype of type 'Future<HttpClientRequest>'
type 'Null' is not a subtype of type 'Future<HttpClientRequest>'
00:09 +96 ~2: test/lib/screens/home/home_screen_trip_test.dart: Home Screen Trip shows when user has a trip
''';

class _TestIOOverrides extends IOOverrides {
  _TestIOOverrides(this.root);

  final String root;

  @override
  Directory getCurrentDirectory() {
    return Directory(root);
  }
}
