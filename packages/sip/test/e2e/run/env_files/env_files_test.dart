import 'dart:io' as io;

import 'package:file/file.dart';
import 'package:file/memory.dart';
import 'package:mason_logger/mason_logger.dart';
import 'package:mocktail/mocktail.dart';
import 'package:path/path.dart' as path;
import 'package:sip_cli/commands/script_run_command.dart';
import 'package:sip_cli/domain/bindings.dart';
import 'package:sip_cli/domain/command_result.dart';
import 'package:sip_cli/domain/domain.dart';
import 'package:sip_cli/domain/filter_type.dart';
import 'package:sip_cli/domain/pubspec_yaml.dart';
import 'package:sip_cli/domain/scripts_yaml.dart';
import 'package:sip_cli/domain/variables.dart';
import 'package:test/test.dart';

void main() {
  group('env files e2e', () {
    late FileSystem fs;
    late _MockBindings mockBindings;
    late Logger mockLogger;

    setUp(() {
      mockBindings = _MockBindings();
      mockLogger = _MockLogger();

      when(() => mockLogger.progress(any())).thenReturn(_MockProgress());

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

        final command = ScriptRunCommand(
          bindings: mockBindings,
          cwd: CWDImpl(fs: fs),
          logger: mockLogger,
          scriptsYaml: ScriptsYamlImpl(fs: fs),
          variables: Variables(
            cwd: CWDImpl(fs: fs),
            pubspecYaml: PubspecYamlImpl(fs: fs),
            scriptsYaml: ScriptsYamlImpl(fs: fs),
          ),
        );

        return command;
      }

      setUp(() {
        command = prep();
      });

      test('command: be reset', () async {
        await command.run(['be', 'reset']);

        await Future<void>.delayed(const Duration(milliseconds: 100));

        expect(
          mockBindings.scripts,
          [
            'cd /packages/sip || exit 1',
            '',
            'cd infra || exit 1; pnv generate-env -i public/be.local.yaml -o private/ -f ~/.cant-run/local.key',
            '',
            'cd /packages/sip || exit 1',
            '',
            'cd infra || exit 1; pnv generate-env -i public/app.run-time.local.yaml -o private/ -f ~/.cant-run/local.key',
            '',
            'cd /packages/sip || exit 1',
            '',
            'if [ -f infra/private/be.local.env ]; then',
            '  builtin source infra/private/be.local.env',
            'else',
            '  echo "ENV File infra/private/be.local.env not found"',
            '  exit 1',
            'fi',
            '',
            'cd backend || exit 1;',
            'dart run scripts/reset.dart',
            '',
          ],
        );
      });
    });
  });
}

class _MockBindings implements Bindings {
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

class _MockLogger extends Mock implements Logger {
  @override
  Level get level => Level.quiet;
}

class _MockProgress extends Mock implements Progress {}
