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

import '../../../utils/test_scoped.dart';

void main() {
  group('env files e2e', () {
    late FileSystem fs;
    late Bindings bindings;

    setUp(() {
      bindings = _MockBindings();
      fs = MemoryFileSystem.test();

      when(
        () => bindings.runScript(
          any(),
          showOutput: any(named: 'showOutput'),
          bail: any(named: 'bail'),
        ),
      ).thenAnswer(
        (_) async => const CommandResult(exitCode: 0, output: '', error: ''),
      );

      fs.file(path.join('packages', 'sip', 'infra', 'private', 'be.local.env'))
        ..createSync(recursive: true)
        ..writeAsStringSync('BE_ENV=local');

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
            'env_files',
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

      test('command: be reset', () async {
        await command.run(['be', 'reset']);

        final scripts = verify(
          () => bindings.runScript(
            captureAny(),
            showOutput: any(named: 'showOutput'),
            bail: any(named: 'bail'),
          ),
        ).captured;

        const expected = [
          '''
cd "/packages/sip" || exit 1

cd infra || exit 1; pnv generate-env -i public/be.local.yaml -o private/ -f ~/.cant-run/local.key''',
          '''
cd "/packages/sip" || exit 1

cd infra || exit 1; pnv generate-env -i public/app.run-time.local.yaml -o private/ -f ~/.cant-run/local.key''',

          '''
cd "/packages/sip" || exit 1

export BE_ENV=local
export APP_ENV=local

cd backend || exit 1;
dart run scripts/reset.dart''',
        ];

        expect(scripts, expected);
      });

      test('should override env variables when re-defined', () async {
        await command.run(['override']);

        final scripts = verify(
          () => bindings.runScript(
            captureAny(),
            showOutput: any(named: 'showOutput'),
            bail: any(named: 'bail'),
          ),
        ).captured;

        const expected = [
          '''
cd "/packages/sip" || exit 1

cd infra || exit 1; pnv generate-env -i public/be.local.yaml -o private/ -f ~/.cant-run/local.key''',
          '''
cd "/packages/sip" || exit 1

cd infra || exit 1; pnv generate-env -i public/app.run-time.local.yaml -o private/ -f ~/.cant-run/local.key''',

          '''
cd "/packages/sip" || exit 1

export BE_ENV=local
export APP_ENV=local

cd backend || exit 1;
dart run scripts/reset.dart''',
        ];

        expect(scripts, expected);
      });
    });
  });
}

class _MockBindings extends Mock implements Bindings {}
