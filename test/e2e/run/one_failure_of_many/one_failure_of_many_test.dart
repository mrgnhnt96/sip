import 'dart:io' as io;

import 'package:file/file.dart';
import 'package:file/memory.dart';
import 'package:mason_logger/mason_logger.dart';
import 'package:meta/meta.dart';
import 'package:mocktail/mocktail.dart';
import 'package:path/path.dart' as path;
import 'package:sip_cli/src/commands/script_run_command.dart';
import 'package:sip_cli/src/domain/bindings.dart';
import 'package:sip_cli/src/domain/command_result.dart';
import 'package:sip_cli/src/domain/pubspec_yaml.dart';
import 'package:sip_cli/src/domain/scripts_yaml.dart';
import 'package:test/test.dart';

import '../../../utils/fake_args.dart';
import '../../../utils/test_scoped.dart';

void main() {
  group('one failure of many e2e', () {
    late FileSystem fs;
    late Bindings bindings;
    late FakeArgs args;
    late Logger logger;

    setUp(() {
      bindings = _MockBindings();
      fs = MemoryFileSystem.test();
      args = FakeArgs();
      logger = _MockLogger();

      when(
        () => bindings.runScript(
          any(),
          showOutput: any(named: 'showOutput'),
          bail: any(named: 'bail'),
        ),
      ).thenAnswer((invo) async {
        final [String script, ...] = invo.positionalArguments;

        if (script.contains('fail')) {
          return const CommandResult(exitCode: 1, output: '', error: '');
        }

        return const CommandResult(exitCode: 0, output: '', error: '');
      });

      when(() => logger.progress(any())).thenAnswer((_) => _MockProgress());

      final cwd = fs.directory(path.join('packages', 'sip'))
        ..createSync(recursive: true);
      fs.currentDirectory = cwd;
    });

    @isTest
    void test(String description, Future<void> Function() fn) {
      testScoped(
        description,
        fn,
        fileSystem: () => fs,
        bindings: () => bindings,
        args: () => args,
        logger: () => logger,
      );
    }

    group('runs gracefully', () {
      late ScriptRunCommand command;

      ScriptRunCommand prep() {
        final input = io.File(
          path.join(
            'test',
            'e2e',
            'run',
            'one_failure_of_many',
            'inputs',
            'scripts.yaml',
          ),
        ).readAsStringSync();

        fs.file(ScriptsYaml.fileName)
          ..createSync(recursive: true)
          ..writeAsStringSync(input);
        fs.file(PubspecYaml.fileName)
          ..createSync(recursive: true)
          ..writeAsStringSync('');

        const command = ScriptRunCommand();

        return command;
      }

      setUp(() {
        command = prep();
      });

      test(
        'should exit with failure code when a command fails in the middle',
        () async {
          final exitCode = await command.run(['cmd']);

          final scripts = verify(
            () => bindings.runScript(
              captureAny(),
              showOutput: any(named: 'showOutput'),
              bail: any(named: 'bail'),
            ),
          ).captured;

          expect(scripts, hasLength(3));

          expect(exitCode, isNot(ExitCode.success));
        },
      );
    });
  });
}

class _MockBindings extends Mock implements Bindings {}

class _MockLogger extends Mock implements Logger {}

class _MockProgress extends Mock implements Progress {}
