import 'dart:io' as io;

import 'package:file/file.dart';
import 'package:file/memory.dart';
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
  group('env files e2e', () {
    late FileSystem fs;
    late Bindings bindings;
    late FakeArgs args;

    setUp(() {
      bindings = _MockBindings();
      fs = MemoryFileSystem.test();
      args = FakeArgs();

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
      );
    }

    group('runs gracefully', () {
      late ScriptRunCommand command;

      ScriptRunCommand prep() {
        final input = io.File(
          path.join('test', 'e2e', 'run', 'coverage', 'inputs', 'scripts.yaml'),
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

      test('command: test', () async {
        await command.run(['test']);

        final [script] = verify(
          () => bindings.runScript(
            captureAny(),
            showOutput: any(named: 'showOutput'),
            bail: any(named: 'bail'),
          ),
        ).captured;

        expect(
          (script as String).split('\n'),
          '''
cd "/packages/sip" || exit 1

dart test'''
              .split('\n'),
        );
      });

      test('command: test --coverage', () async {
        args['coverage'] = true;
        await command.run(['test']);

        final [script] = verify(
          () => bindings.runScript(
            captureAny(),
            showOutput: any(named: 'showOutput'),
            bail: any(named: 'bail'),
          ),
        ).captured;

        expect(
          (script as String).split('\n'),
          '''
cd "/packages/sip" || exit 1

dart test --coverage'''
              .split('\n'),
        );
      });

      test('command: test --coverage=banana', () async {
        args['coverage'] = 'banana';
        await command.run(['test']);

        final [script] = verify(
          () => bindings.runScript(
            captureAny(),
            showOutput: any(named: 'showOutput'),
            bail: any(named: 'bail'),
          ),
        ).captured;

        expect(
          (script as String).split('\n'),
          '''
cd "/packages/sip" || exit 1

dart test --coverage banana'''
              .split('\n'),
        );
      });

      test('command: test --coverage monkey', () async {
        args['coverage'] = 'monkey';
        await command.run(['test']);

        final [script] = verify(
          () => bindings.runScript(
            captureAny(),
            showOutput: any(named: 'showOutput'),
            bail: any(named: 'bail'),
          ),
        ).captured;

        expect(
          (script as String).split('\n'),
          '''
cd "/packages/sip" || exit 1

dart test --coverage monkey'''
              .split('\n'),
        );
      });
    });
  });
}

class _MockBindings extends Mock implements Bindings {}
