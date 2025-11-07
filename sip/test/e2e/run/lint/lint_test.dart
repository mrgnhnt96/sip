import 'dart:io' as io;

import 'package:file/file.dart';
import 'package:file/memory.dart';
import 'package:mason_logger/mason_logger.dart';
import 'package:mocktail/mocktail.dart';
import 'package:path/path.dart' as path;
import 'package:pub_updater/pub_updater.dart';
import 'package:sip_cli/commands/script_run_command.dart';
import 'package:sip_cli/domain/domain.dart';
import 'package:sip_cli/sip_runner.dart';
import 'package:sip_cli/utils/key_press_listener.dart';
import 'package:test/test.dart';

import '../../../utils/stub_logger.dart';

void main() {
  group('lint e2e', () {
    late FileSystem fs;
    late _TestBindings bindings;
    late Logger logger;

    setUp(() {
      bindings = _TestBindings();
      logger = _MockLogger()..stub();

      fs = MemoryFileSystem.test();

      final cwd = fs.directory(path.join('packages', 'sip'))
        ..createSync(recursive: true);
      fs.currentDirectory = cwd;
    });

    group('runs gracefully', () {
      late ScriptRunCommand command;
      late SipRunner runner;

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

        final runOneScript = RunOneScript(bindings: bindings, logger: logger);

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

        runner = SipRunner(
          bindings: bindings,
          cwd: CWDImpl(fs: fs),
          logger: logger,
          scriptsYaml: ScriptsYamlImpl(fs: fs),
          variables: Variables(
            cwd: CWDImpl(fs: fs),
            pubspecYaml: PubspecYamlImpl(fs: fs),
            scriptsYaml: ScriptsYamlImpl(fs: fs),
          ),
          runOneScript: runOneScript,
          runManyScripts: RunManyScripts(
            bindings: bindings,
            logger: logger,
            runOneScript: runOneScript,
          ),
          pubspecLock: PubspecLockImpl(fs: fs),
          pubspecYaml: PubspecYamlImpl(fs: fs),
          pubUpdater: PubUpdater(),
          keyPressListener: KeyPressListener(logger: logger),
          findFile: FindFile(fs: fs),
          ogArgs: [],
          fs: fs,
        );

        return command;
      }

      setUp(() {
        command = prep();
      });

      test('command: lint --package application', () async {
        await command.run(['lint', '--package', 'application']);

        await Future<void>.delayed(Duration.zero);

        expect(bindings.scripts.join('\n'), r'''
cd /packages/sip || exit 1

PKG_PATH="--package application"
PKG_PATH=$(echo "$PKG_PATH" | sed 's/^--package[ =]*//')
if [ -n "$PKG_PATH" ]; then
  dart analyze ./packages/$PKG_PATH --fatal-infos --fatal-warnings 
else
  dart analyze . --fatal-infos --fatal-warnings 
fi
''');
      });

      test('command: lint --package application --print', () async {
        await runner.run([
          'run',
          'lint',
          '--package',
          'application',
          '--print',
        ]);

        await Future<void>.delayed(Duration.zero);

        expect(bindings.scripts, isEmpty);
        verify(
          () => logger.write(r'''
PKG_PATH="--package application"
PKG_PATH=$(echo "$PKG_PATH" | sed 's/^--package[ =]*//')
if [ -n "$PKG_PATH" ]; then
  dart analyze ./packages/$PKG_PATH --fatal-infos --fatal-warnings 
else
  dart analyze . --fatal-infos --fatal-warnings 
fi'''),
        ).called(1);
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

    return const CommandResult(exitCode: 0, output: '', error: '');
  }
}

class _MockLogger extends Mock implements Logger {}
