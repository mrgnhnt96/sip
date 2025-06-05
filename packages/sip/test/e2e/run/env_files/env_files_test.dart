import 'dart:io' as io;

import 'package:file/file.dart';
import 'package:file/memory.dart';
import 'package:mason_logger/mason_logger.dart';
import 'package:mocktail/mocktail.dart';
import 'package:path/path.dart' as path;
import 'package:sip_cli/commands/script_run_command.dart';
import 'package:sip_cli/domain/domain.dart';
import 'package:test/test.dart';

void main() {
  group('env files e2e', () {
    late FileSystem fs;
    late _TestBindings bindings;
    late Logger logger;

    setUp(() {
      bindings = _TestBindings();
      logger = _MockLogger();

      when(() => logger.level).thenReturn(Level.quiet);
      when(() => logger.progress(any())).thenReturn(_MockProgress());

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

        final runOneScript = RunOneScript(
          bindings: bindings,
          logger: logger,
        );

        final command = ScriptRunCommand(
          bindings: bindings,
          cwd: CWDImpl(fs: fs),
          logger: logger,
          scriptsYaml: ScriptsYamlImpl(fs: fs),
          variables: Variables(
            cwd: CWDImpl(fs: fs),
            pubspecYaml: PubspecYamlImpl(fs: fs),
            scriptsYaml: ScriptsYamlImpl(fs: fs),
          ),
          runManyScripts: RunManyScripts(
            bindings: bindings,
            logger: logger,
            runOneScript: runOneScript,
          ),
          runOneScript: runOneScript,
        );

        return command;
      }

      setUp(() {
        command = prep();
      });

      test('command: be reset', () async {
        await command.run(['be', 'reset']);

        await Future<void>.delayed(Duration.zero);

        expect(
          bindings.scripts.join('\n'),
          r'''
cd /packages/sip || exit 1

cd infra || exit 1; pnv generate-env -i public/be.local.yaml -o private/ -f ~/.cant-run/local.key

cd /packages/sip || exit 1

cd infra || exit 1; pnv generate-env -i public/app.run-time.local.yaml -o private/ -f ~/.cant-run/local.key

cd /packages/sip || exit 1

if [ -f infra/private/be.local.env ]; then
  builtin source infra/private/be.local.env
  while IFS='=' read -r key _; do
    if [[ $key =~ ^[A-Za-z_][A-Za-z0-9_]*$ ]]; then
      export "$key"
    fi
  done < <(grep -vE '^\s*#' infra/private/be.local.env | grep -E '^[A-Za-z_][A-Za-z0-9_]*=')
else
  echo "ENV File infra/private/be.local.env not found"
  exit 1
fi

export BE_ENV=local
export APP_ENV=local

cd backend || exit 1;
dart run scripts/reset.dart
''',
        );
      });

      test('should override env variables when re-defined', () async {
        await command.run(['override']);

        await Future<void>.delayed(Duration.zero);

        expect(bindings.scripts.join('\n'), r'''
cd /packages/sip || exit 1

cd infra || exit 1; pnv generate-env -i public/be.local.yaml -o private/ -f ~/.cant-run/local.key

cd /packages/sip || exit 1

cd infra || exit 1; pnv generate-env -i public/app.run-time.local.yaml -o private/ -f ~/.cant-run/local.key

cd /packages/sip || exit 1

if [ -f infra/private/be.local.env ]; then
  builtin source infra/private/be.local.env
  while IFS='=' read -r key _; do
    if [[ $key =~ ^[A-Za-z_][A-Za-z0-9_]*$ ]]; then
      export "$key"
    fi
  done < <(grep -vE '^\s*#' infra/private/be.local.env | grep -E '^[A-Za-z_][A-Za-z0-9_]*=')
else
  echo "ENV File infra/private/be.local.env not found"
  exit 1
fi

export BE_ENV=override
export APP_ENV=local

cd backend || exit 1;
dart run scripts/reset.dart
''');
      });
    });
  });
}

class _TestBindings implements Bindings {
  final List<String> scripts = [];

  @override
  Future<CommandResult> runScript(
    String script, {
    bool showOutput = false,
    FilterType? filterType,
    bool bail = false,
  }) async {
    scripts.addAll(script.split('\n'));

    return const CommandResult(
      exitCode: 0,
      output: '',
      error: '',
    );
  }
}

class _MockLogger extends Mock implements Logger {}

class _MockProgress extends Mock implements Progress {}
