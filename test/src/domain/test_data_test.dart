import 'package:file/memory.dart';
import 'package:mason_logger/mason_logger.dart';
import 'package:mocktail/mocktail.dart';
import 'package:platform/platform.dart';
import 'package:sip_cli/src/domain/script_to_run.dart';
import 'package:sip_cli/src/domain/test_data.dart';
import 'package:test/test.dart';

import '../../utils/test_scoped.dart';

void main() {
  group(TestData, () {
    // The `github` reporter closes the previous group on the line before it
    // opens the next one, so a failure reaches the parser as a chunk that
    // starts with `::endgroup::`. sip forces this reporter by exporting
    // GITHUB_ACTIONS=true (see `TesterMixin.createTestCommand`), so this is
    // the normal shape of a failure, not an edge case.
    const failureChunk = '''
::endgroup::
::group::❌ test/a_test.dart fails (failed)
Expected: <2>
  Actual: <1>

package:matcher        expect
test/a_test.dart 4:23  main.<fn>
::endgroup::''';

    testScoped(
      'a non-zero exit with nothing parsed is reported as failed in json',
      fileSystem: MemoryFileSystem.test,
      () {
        final data = TestData(quiet: true)..addExitFailure('pkg_a', 70);

        final json = data.toJson();

        expect(json['passed'], isFalse);
        expect(json['errors'], ['pkg_a exited with code 70']);
      },
    );

    group('printResults outside CI', () {
      late _MockLogger logger;

      String printed() => verify(
        () => logger.write(captureAny()),
      ).captured.cast<String>().join();

      testScoped(
        'names the command behind a non-zero exit',
        fileSystem: MemoryFileSystem.test,
        platform: () => FakePlatform(environment: {}),
        logger: () => logger = _MockLogger(),
        () {
          TestData()
            ..addExitFailure('Running (flutter) tests in test', 1)
            ..printResults();

          expect(
            printed(),
            allOf(
              contains('❌ Failed to finish'),
              contains('Running (flutter) tests in test exited with code 1'),
            ),
          );
        },
      );

      testScoped(
        'names an error raised by one command',
        fileSystem: MemoryFileSystem.test,
        platform: () => FakePlatform(environment: {}),
        logger: () => logger = _MockLogger(),
        () {
          final script = ScriptToRun('dart test', workingDirectory: '.');
          TestData()
            ..parse(script, '✅ test/a_test.dart passes')
            ..addError(script, 'The Dart compiler exited unexpectedly')
            ..printResults();

          expect(printed(), contains('The Dart compiler exited unexpectedly'));
        },
      );

      testScoped(
        'prints no failure section when nothing failed',
        fileSystem: MemoryFileSystem.test,
        platform: () => FakePlatform(environment: {}),
        logger: () => logger = _MockLogger(),
        () {
          TestData().printResults();

          expect(printed(), isNot(contains('Failed to finish')));
        },
      );
    });

    testScoped(
      'json passes when nothing failed and no command exited non-zero',
      fileSystem: MemoryFileSystem.test,
      () {
        final json = TestData(quiet: true).toJson();

        expect(json['passed'], isTrue);
        expect(json['errors'], isEmpty);
      },
    );

    testScoped(
      'counts a failure that arrives after ::endgroup::',
      fileSystem: MemoryFileSystem.test,
      () {
        // One script instance for every chunk: the per-script state that
        // tracks the last reported test is keyed by identity, and it is that
        // state the swallowed failure was appended to.
        final script = ScriptToRun('dart test', workingDirectory: '.');

        final data = TestData()
          ..parse(script, '::group::✅ Passing tests')
          ..parse(script, '✅ test/a_test.dart passes')
          ..parse(script, failureChunk);

        expect(data.passing, 1);
        expect(data.failing, 1, reason: 'the failure must not be swallowed');
      },
    );

    // test_core >= 0.6.18 wraps passes in a `::group::✅ Passing tests`
    // section. That header is not a result: it must count the same whether
    // the pipe delivers it alone or glued to the `::endgroup::` before it.
    group('section headers', () {
      const pass = '✅ test/a_test.dart adds';

      testScoped(
        'are not counted when they share a chunk with ::endgroup::',
        fileSystem: MemoryFileSystem.test,
        () {
          final script = ScriptToRun('dart test', workingDirectory: '.');
          final data = TestData(quiet: true)
            ..parse(script, pass)
            ..parse(script, '::endgroup::\n::group::✅ Passing tests\n');

          expect(data.passing, 1);
        },
      );

      testScoped(
        'are not counted when they arrive alone',
        fileSystem: MemoryFileSystem.test,
        () {
          final script = ScriptToRun('dart test', workingDirectory: '.');
          final data = TestData(quiet: true)
            ..parse(script, pass)
            ..parse(script, '::endgroup::\n')
            ..parse(script, '::group::✅ Passing tests\n');

          expect(data.passing, 1);
        },
      );

      testScoped(
        'do not leak into the name of the next test',
        fileSystem: MemoryFileSystem.test,
        () {
          final script = ScriptToRun('dart test', workingDirectory: '.');
          final data = TestData(quiet: true)
            ..parse(script, '::group::✅ Passing tests')
            ..parse(script, pass);

          expect(data.passing, 1);
          expect(data.successes.single.test, 'adds');
        },
      );

      testScoped(
        'do not hide a failure that follows them',
        fileSystem: MemoryFileSystem.test,
        () {
          final script = ScriptToRun('dart test', workingDirectory: '.');
          final data = TestData(quiet: true)
            ..parse(script, '::group::✅ Passing tests\n$pass')
            ..parse(script, failureChunk)
            ..parse(script, '::group::✅ Passing tests\n$pass');

          expect(data.passing, 2);
          expect(data.failing, 1);
        },
      );
    });

    // `flutter test` marks a skip with ⏭️ (U+23ED U+FE0F), and test_core's
    // own github reporter with ❎. Either one starts a new result; it is not
    // a continuation of the test reported before it (#29).
    group('skipped results', () {
      for (final icon in ['⏭️', '❎']) {
        testScoped(
          '$icon after a pass is counted as its own skip',
          fileSystem: MemoryFileSystem.test,
          () {
            final script = ScriptToRun('dart test', workingDirectory: '.');
            final data = TestData(quiet: true)
              ..parse(script, '✅ test/a_test.dart a')
              ..parse(script, '$icon test/tagged_test.dart tagged (skipped)');

            expect(data.passing, 1);
            expect(data.skipped, 1);
            expect(data.successes.single.error, isNull);
            expect(data.skips.single.path, 'test/tagged_test.dart');
            expect(data.skips.single.test, 'tagged (skipped)');
          },
        );
      }
    });

    testScoped(
      'buffers an unclosed group until it closes',
      fileSystem: MemoryFileSystem.test,
      () {
        final script = ScriptToRun('dart test', workingDirectory: '.');
        final data = TestData()
          ..parse(script, '::group::❌ test/a_test.dart fails (failed)');

        expect(data.failing, 0, reason: 'the group has not closed yet');

        data.parse(script, 'Expected: <2>\n::endgroup::');

        expect(data.failing, 1);
      },
    );
  });
}

class _MockLogger extends Mock implements Logger {}
