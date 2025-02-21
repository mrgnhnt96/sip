import 'package:file/file.dart';
import 'package:file/memory.dart';
import 'package:mason_logger/mason_logger.dart';
import 'package:mocktail/mocktail.dart';
import 'package:path/path.dart' as path;
import 'package:sip_cli/commands/test_run_command.dart';
import 'package:sip_cli/domain/bindings.dart';
import 'package:sip_cli/domain/command_result.dart';
import 'package:sip_cli/domain/filter_type.dart';
import 'package:sip_cli/domain/find_file.dart';
import 'package:sip_cli/domain/pubspec_lock_impl.dart';
import 'package:sip_cli/domain/pubspec_yaml_impl.dart';
import 'package:sip_cli/domain/run_many_scripts.dart';
import 'package:sip_cli/domain/run_one_script.dart';
import 'package:sip_cli/domain/scripts_yaml_impl.dart';
import 'package:test/test.dart';

void main() {
  group('finds test directories', () {
    late FileSystem fs;
    late _TestBindings bindings;
    late Logger logger;
    late TestRunCommand command;

    setUp(() {
      bindings = _TestBindings();
      logger = _MockLogger();

      when(() => logger.level).thenReturn(Level.quiet);
      when(() => logger.progress(any())).thenReturn(_MockProgress());

      fs = MemoryFileSystem.test();

      final runOneScript = RunOneScript(bindings: bindings, logger: logger);

      command = TestRunCommand(
        pubspecYaml: PubspecYamlImpl(fs: fs),
        fs: fs,
        logger: logger,
        bindings: bindings,
        pubspecLock: PubspecLockImpl(fs: fs),
        findFile: FindFile(fs: fs),
        scriptsYaml: ScriptsYamlImpl(fs: fs),
        runManyScripts: RunManyScripts(
          bindings: bindings,
          logger: logger,
          runOneScript: runOneScript,
        ),
        runOneScript: runOneScript,
      );

      final cwd = fs.directory(path.join('packages', 'sip'))
        ..createSync(recursive: true);
      fs.currentDirectory = cwd;
    });

    void createPackage(List<String> segments) {
      final dir = fs.directory(path.joinAll(segments))
        ..createSync(recursive: true);

      fs.file(dir.childFile('pubspec.yaml'))
        ..createSync(recursive: true)
        ..writeAsStringSync('''
name: ${path.basename(dir.path)}

environment:
  sdk: ">=3.6.0 <4.0.0"
''');

      dir.childDirectory('test').childFile('main_test.dart')
        ..createSync(recursive: true)
        ..writeAsStringSync('''
import 'package:test/test.dart';

void main() {
  test('test', () {
    expect(true, isTrue);
  });
}
''');
    }

    test('when directories start with test but are not test directories',
        () async {
      createPackage(['test_dir']);
      createPackage(['test_dir2']);

      final result = await command.run(['--recursive']);

      expect(result.code, ExitCode.success.code);
      expect(bindings.scripts, [
        'cd /packages/sip/test_dir || exit 1',
        '',
        'dart test test/.test_optimizer.dart',
        '',
        'cd /packages/sip/test_dir2 || exit 1',
        '',
        'dart test test/.test_optimizer.dart',
        '',
      ]);
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
