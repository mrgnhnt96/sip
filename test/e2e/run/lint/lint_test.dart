import 'dart:io' as io;

import 'package:file/file.dart';
import 'package:file/memory.dart';
import 'package:mason_logger/mason_logger.dart';
import 'package:meta/meta.dart';
import 'package:mocktail/mocktail.dart';
import 'package:path/path.dart' as path;
import 'package:sip_cli/sip_runner.dart';
import 'package:sip_cli/src/commands/script_run_command.dart';
import 'package:sip_cli/src/domain/bindings.dart';
import 'package:sip_cli/src/domain/command_result.dart';
import 'package:sip_cli/src/domain/pubspec_yaml.dart';
import 'package:sip_cli/src/domain/scripts_yaml.dart';
import 'package:test/test.dart';

import '../../../utils/fake_args.dart';
import '../../../utils/test_scoped.dart';

void main() {
  group('lint e2e', () {
    late FileSystem fs;
    late Bindings bindings;
    late SipRunner runner;
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
      ).thenAnswer(
        (_) async => const CommandResult(exitCode: 0, output: '', error: ''),
      );

      when(() => logger.progress(any())).thenAnswer((_) => _MockProgress());

      when(
        () => bindings.runScript(
          any(),
          showOutput: any(named: 'showOutput'),
          bail: any(named: 'bail'),
        ),
      ).thenAnswer(
        (_) async => const CommandResult(exitCode: 0, output: '', error: ''),
      );

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
          path.join('test', 'e2e', 'run', 'lint', 'inputs', 'scripts.yaml'),
        ).readAsStringSync();

        fs.file(ScriptsYaml.fileName)
          ..createSync(recursive: true)
          ..writeAsStringSync(input);
        fs.file(PubspecYaml.fileName)
          ..createSync(recursive: true)
          ..writeAsStringSync('');

        const command = ScriptRunCommand();
        runner = const SipRunner();

        return command;
      }

      setUp(() {
        command = prep();
      });

      test('command: lint --package application', () async {
        args['package'] = 'application';
        await command.run(['lint']);

        final [script] = verify(
          () => bindings.runScript(
            captureAny(),
            showOutput: any(named: 'showOutput'),
            bail: any(named: 'bail'),
          ),
        ).captured;

        expect(
          (script as String).split('\n'),
          r'''
cd "/packages/sip" || exit 1

PKG_PATH="--package application"
PKG_PATH=$(echo "$PKG_PATH" | sed 's/^--package[ =]*//')
if [ -n "$PKG_PATH" ]; then
  dart analyze ./packages/$PKG_PATH --fatal-infos --fatal-warnings 
else
  dart analyze . --fatal-infos --fatal-warnings 
fi'''
              .split('\n'),
        );
      });

      test('command: lint --package application --print', () async {
        args['package'] = 'application';
        args.path = ['run', 'lint'];
        args['print'] = true;

        await runner.run();

        final [message, ...] = verify(
          () => logger.write(captureAny()),
        ).captured;

        expect(
          (message as String).split('\n'),
          r'''
PKG_PATH="--package application"
PKG_PATH=$(echo "$PKG_PATH" | sed 's/^--package[ =]*//')
if [ -n "$PKG_PATH" ]; then
  dart analyze ./packages/$PKG_PATH --fatal-infos --fatal-warnings 
else
  dart analyze . --fatal-infos --fatal-warnings 
fi'''
              .split('\n'),
        );
      });
    });
  });
}

class _MockBindings extends Mock implements Bindings {}

class _MockLogger extends Mock implements Logger {}

class _MockProgress extends Mock implements Progress {}
