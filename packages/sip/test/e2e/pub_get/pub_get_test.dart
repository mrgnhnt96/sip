import 'package:file/file.dart';
import 'package:file/memory.dart';
import 'package:mason_logger/mason_logger.dart';
import 'package:mocktail/mocktail.dart';
import 'package:path/path.dart' as p;
import 'package:sip_cli/commands/pub_get_command.dart';
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
    late PubGetCommand command;
    late _MockRunManyScripts runManyScripts;

    setUp(() {
      bindings = _TestBindings();
      logger = _MockLogger();
      runManyScripts = _MockRunManyScripts();
      when(() => logger.level).thenReturn(Level.quiet);
      when(() => logger.progress(any())).thenReturn(_MockProgress());

      fs = MemoryFileSystem.test();

      final runOneScript = RunOneScript(bindings: bindings, logger: logger);

      command = PubGetCommand(
        pubspecYaml: PubspecYamlImpl(fs: fs),
        fs: fs,
        logger: logger,
        bindings: bindings,
        pubspecLock: PubspecLockImpl(fs: fs),
        findFile: FindFile(fs: fs),
        scriptsYaml: ScriptsYamlImpl(fs: fs),
        runManyScripts: runManyScripts,
        runOneScript: runOneScript,
      );

      final cwd = fs.directory(p.join('packages', 'sip'))
        ..createSync(recursive: true);
      fs.currentDirectory = cwd;
    });

    /// Create a directory with a pubspec.yaml file inside.
    void createDirs(List<List<String>> dirs) {
      for (final segments in dirs) {
        final path = p.joinAll(segments);
        final dir = fs.directory(path)..createSync(recursive: true);
        fs.file(p.join(dir.path, 'pubspec.yaml'))
          ..createSync()
          ..writeAsString('name: ${p.basename(path)}');
      }
    }

    test('pub get with recursive flag should run all concurrently', () async {
      createDirs([
        ['packages', 'a'],
        ['packages', 'b'],
        ['packages', 'c'],
        ['packages', 'd'],
      ]);

      when(
        () => runManyScripts.run(
          commands: any(named: 'commands'),
          bail: any(named: 'bail'),
          sequentially: any(named: 'sequentially'),
          retryAfter: any(named: 'retryAfter'),
          maxAttempts: any(named: 'maxAttempts'),
          label: any(named: 'label'),
        ),
      ).thenAnswer(
        (_) async => [const CommandResult(exitCode: 0, output: '', error: '')],
      );

      final result = await command.run(['--recursive']);

      expect(result.code, ExitCode.success.code);
      verify(
        () => runManyScripts.run(
          commands: any(named: 'commands', that: hasLength(4)),
          bail: false,
          sequentially: false,
          label: any(named: 'label'),
        ),
      );
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

class _MockProgress extends Mock implements Progress {}

class _MockRunManyScripts extends Mock implements RunManyScripts {}
