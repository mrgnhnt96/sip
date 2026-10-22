import 'package:file/file.dart';
import 'package:file/memory.dart';
import 'package:mason_logger/mason_logger.dart';
import 'package:meta/meta.dart';
import 'package:mocktail/mocktail.dart';
import 'package:sip_cli/src/commands/test_command/test_command.dart';
import 'package:sip_cli/src/domain/args.dart';
import 'package:sip_cli/src/domain/bindings.dart';
import 'package:sip_cli/src/domain/command_result.dart';
import 'package:test/test.dart';

import '../../utils/test_scoped.dart';

void main() {
  // https://github.com/mrgnhnt96/sip/issues/1
  group('sip test with a file path', () {
    late FileSystem fs;
    late Bindings bindings;

    setUp(() {
      bindings = _MockBindings();
      fs = MemoryFileSystem.test();

      when(
        () => bindings.runScriptWithOutput(
          any(),
          onOutput: any(named: 'onOutput'),
          bail: any(named: 'bail'),
        ),
      ).thenAnswer(
        (_) async => const CommandResult(exitCode: 0, output: '', error: ''),
      );

      fs.file('/pkg/pubspec.yaml')
        ..createSync(recursive: true)
        ..writeAsStringSync('''
name: pkg

environment:
  sdk: ">=3.6.0 <4.0.0"
''');
      for (final name in ['my_test.dart', 'other_test.dart']) {
        fs.file('/pkg/test/path/$name')
          ..createSync(recursive: true)
          ..writeAsStringSync('void main() {}');
      }
      fs.currentDirectory = fs.directory('/pkg');
    });

    // Mirrors the real dispatch: Args.parse of the whole command line, then
    // the `test` path segment handed to TestCommand.
    @isTest
    void test(String description, List<String> argv) {
      late Args args;

      testScoped(
        description,
        () async {
          final result = await const TestCommand().run(
            args.path.skip(1).toList(),
          );

          expect(result.code, ExitCode.success.code);

          final scripts = verify(
            () => bindings.runScriptWithOutput(
              captureAny(),
              onOutput: any(named: 'onOutput'),
              bail: any(named: 'bail'),
            ),
          ).captured.cast<String>();

          expect(scripts, hasLength(1));
          expect(scripts.single, contains('/pkg/test/path/my_test.dart'));
          expect(scripts.single, isNot(contains('other_test.dart')));
          expect(scripts.single, isNot(contains('--no-optimize')));
          expect(scripts.single, isNot(contains('.test_optimizer')));
        },
        fileSystem: () => fs,
        bindings: () => bindings,
        args: () => args = Args.parse(argv),
      );
    }

    test('flags after the path', [
      'test',
      'test/path/my_test.dart',
      '--no-optimize',
      '--update-goldens',
    ]);

    test('flags before the path', [
      'test',
      '--no-optimize',
      '--update-goldens',
      'test/path/my_test.dart',
    ]);
  });
}

class _MockBindings extends Mock implements Bindings {}
