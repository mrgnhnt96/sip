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
  group('compound env vars e2e', () {
    late FileSystem fs;
    late Bindings bindings;

    setUp(() {
      bindings = _MockBindings();

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

    group('runs gracefully', () {
      late ScriptRunCommand command;

      ScriptRunCommand prep() {
        final input = io.File(
          path.join(
            'test',
            'e2e',
            'run',
            'compound_env_vars',
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

      @isTest
      void test(String description, Future<void> Function() fn) {
        testScoped(
          description,
          fn,
          fileSystem: () => fs,
          bindings: () => bindings,
        );
      }

      test('command: bricks bundle', () async {
        await command.run(['bricks', 'bundle']);

        final commands = verify(
          () => bindings.runScriptWithOutput(
            captureAny(),
            onOutput: any(named: 'onOutput'),
          ),
        ).captured;

        const expected = [
          r'''
cd "/packages/sip" || exit 1

export RELEASE=true

cd development/generated_lints || exit 1

RELEASE_FLAG=""
if [ "$RELEASE" = true ]; then
  RELEASE_FLAG="--release"
fi

echo "RELEASE_FLAG: $RELEASE_FLAG"
echo "RELEASE: $RELEASE"

dart run revali dev --generate-only $RELEASE_FLAG --recompile''',

          '''
cd "/packages/sip" || exit 1

export RELEASE=true

cd mason || exit 1
dart run brick_oven cook analysis_server --output .''',

          '''
cd "/packages/sip" || exit 1

export RELEASE=true

cd mason/analysis_server/post_generate || exit 1
dart run lib/main.dart''',

          '''
cd "/packages/sip" || exit 1

export RELEASE=true

cd mason || exit 1
dart run mason_cli:mason bundle analysis_server --type dart --output-dir bundles''',

          '''
cd "/packages/sip" || exit 1

export RELEASE=true

mv mason/bundles/analysis_server_bundle.dart mason/bundles/release.dart''',
          r'''
cd "/packages/sip" || exit 1

export RELEASE=false

cd development/generated_lints || exit 1

RELEASE_FLAG=""
if [ "$RELEASE" = true ]; then
  RELEASE_FLAG="--release"
fi

echo "RELEASE_FLAG: $RELEASE_FLAG"
echo "RELEASE: $RELEASE"

dart run revali dev --generate-only $RELEASE_FLAG --recompile''',

          '''
cd "/packages/sip" || exit 1

export RELEASE=false

cd mason || exit 1
dart run brick_oven cook analysis_server --output .''',

          '''
cd "/packages/sip" || exit 1

export RELEASE=false

cd mason/analysis_server/post_generate || exit 1
dart run lib/main.dart''',

          '''
cd "/packages/sip" || exit 1

export RELEASE=false

cd mason || exit 1
dart run mason_cli:mason bundle analysis_server --type dart --output-dir bundles''',

          '''
cd "/packages/sip" || exit 1

export RELEASE=false

mv mason/bundles/analysis_server_bundle.dart mason/bundles/debug.dart''',
        ];

        for (final (index, command) in commands.indexed) {
          expect((command as String).split('\n'), expected[index].split('\n'));
        }
      });
    });
  });
}

class _MockBindings extends Mock implements Bindings {}
