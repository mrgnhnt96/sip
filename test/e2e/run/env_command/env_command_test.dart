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
  group('env command e2e', () {
    late FileSystem fs;
    late Bindings bindings;

    setUp(() {
      bindings = _MockBindings();

      when(
        () => bindings.runScript(
          any(),
          showOutput: any(named: 'showOutput'),
          bail: any(named: 'bail'),
        ),
      ).thenAnswer(
        (_) async => const CommandResult(exitCode: 0, output: '', error: ''),
      );
      when(
        () => bindings.runScriptWithOutput(
          any(),
          onOutput: any(named: 'onOutput'),
          bail: any(named: 'bail'),
        ),
      ).thenAnswer(
        (_) async => const CommandResult(exitCode: 0, output: '', error: ''),
      );

      fs = MemoryFileSystem.test();

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
            'env_command',
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

      test('command: server pocketbase migrate', () async {
        fs.file(fs.path.join('infra', 'private', 'pocketbase.local.env'))
          ..createSync(recursive: true)
          ..writeAsStringSync('''
# Comment
FOO=bar
BAR=baz
''');

        await command.run(['server', 'pocketbase', 'migrate']);

        final [env, one, two] = verify(
          () => bindings.runScript(
            captureAny(),
            showOutput: any(named: 'showOutput'),
            bail: any(named: 'bail'),
          ),
        ).captured;

        expect(
          (env as String).split('\n'),
          '''
cd "/packages/sip" || exit 1

cd infra || exit 1
dart run pnv generate env --flavor local --output private --directory public'''
              .split('\n'),
        );

        expect(
          (one as String).split('\n'),
          r'''
cd "/packages/sip" || exit 1

export FOO=bar
export BAR=baz

cd backend/pocketbase || exit 1
MIGRATIONS_COUNT=$(ls -1 pb_migrations | wc -l)
if [ "$MIGRATIONS_COUNT" -eq 0 ]; then
  echo "No migrations to apply"
  exit 0
fi

echo "y" | ./pocketbase migrate down $MIGRATIONS_COUNT'''
              .split('\n'),
        );

        expect(
          (two as String).split('\n'),
          '''
cd "/packages/sip" || exit 1

export FOO=bar
export BAR=baz

cd backend/pocketbase &&./pocketbase migrate up'''
              .split('\n'),
        );
      });
    });
  });
}

class _MockBindings extends Mock implements Bindings {}
