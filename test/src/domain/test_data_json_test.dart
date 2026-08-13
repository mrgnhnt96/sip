import 'package:file/memory.dart';
import 'package:sip_cli/src/domain/script_to_run.dart';
import 'package:sip_cli/src/domain/test_data.dart';
import 'package:test/test.dart';

import '../../utils/test_scoped.dart';

void main() {
  group('TestData.toJson', () {
    // sip forces the `github` reporter by exporting GITHUB_ACTIONS=true (see
    // `TesterMixin.createTestCommand`), so this is the shape a failure
    // actually arrives in.
    const failureChunk = '''
::endgroup::
::group::❌ test/a_test.dart fails loudly (failed)
Expected: <2>
  Actual: <1>

package:matcher        expect
test/a_test.dart 4:23  main.<fn>
::endgroup::''';

    ScriptToRun script() => ScriptToRun('dart test', workingDirectory: '.');

    testScoped(
      'reports a clean run as passed',
      fileSystem: MemoryFileSystem.test,
      () {
        final data = TestData(quiet: true)
          ..parse(script(), '::group::✅ Passing tests')
          ..parse(script(), '✅ test/a_test.dart passes');

        final json = data.toJson();

        expect(json['passed'], isTrue);
        expect(json['failures'], isEmpty);
        expect(json['errors'], isEmpty);
        expect(json['counts'], containsPair('passing', 1));
        expect(json['counts'], containsPair('failing', 0));
      },
    );

    testScoped(
      'reports a failure with its file and name',
      fileSystem: MemoryFileSystem.test,
      () {
        final data = TestData(quiet: true)..parse(script(), failureChunk);

        final json = data.toJson();

        expect(json['passed'], isFalse);
        expect(json['counts'], containsPair('failing', 1));

        final failures = (json['failures']! as List)
            .cast<Map<String, Object?>>();

        expect(failures, hasLength(1));
        expect(failures.single['path'], 'test/a_test.dart');
        expect(failures.single['test'], contains('fails loudly'));
        expect(failures.single['error'], contains('Expected: <2>'));
        expect(failures.single['error'], contains('Actual: <1>'));
      },
    );

    testScoped(
      'cuts a failure message where the next report begins',
      fileSystem: MemoryFileSystem.test,
      () {
        // An error accumulates raw runner output, so whatever the runner
        // printed next lands on the end of the message. That is invisible in
        // the pretty output but a JSON reader gets the whole string, so it is
        // cut back to the failure it belongs to.
        final data = TestData(quiet: true)
          ..parse(script(), failureChunk)
          ..parse(script(), '⏭️ test/a_test.dart skipped one (skipped)');

        final failures = (data.toJson()['failures']! as List)
            .cast<Map<String, Object?>>();

        final error = failures.single['error']! as String;

        expect(error, contains('Actual: <1>'));
        expect(error, isNot(contains('skipped one')));
        expect(error, isNot(contains('::error::')));
      },
    );

    testScoped(
      'reports a run that failed without any test failing',
      fileSystem: MemoryFileSystem.test,
      () {
        // A compile error or crashed runner leaves the counters at zero. A
        // reader that only counted `failures` would call this run green.
        final data = TestData(quiet: true)
          ..addError(null, 'The Dart compiler exited unexpectedly');

        final json = data.toJson();

        expect(json['passed'], isFalse);
        expect(json['failures'], isEmpty);
        expect(
          json['errors'],
          contains(contains('Dart compiler exited unexpectedly')),
        );
      },
    );

    testScoped(
      'reports skipped tests separately',
      fileSystem: MemoryFileSystem.test,
      () {
        final data = TestData(quiet: true)
          ..parse(script(), '✅ test/a_test.dart skipped one (skipped)');

        final json = data.toJson();

        // A skip is not a failure.
        expect(json['passed'], isTrue);
        expect(json['skipped'], hasLength(1));
      },
    );
  });
}
