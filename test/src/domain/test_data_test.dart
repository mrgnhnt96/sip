import 'package:file/memory.dart';
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
