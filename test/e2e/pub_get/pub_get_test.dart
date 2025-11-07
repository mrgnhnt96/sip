import 'package:file/file.dart';
import 'package:file/memory.dart';
import 'package:mason_logger/mason_logger.dart';
import 'package:meta/meta.dart';
import 'package:mocktail/mocktail.dart';
import 'package:path/path.dart' as p;
import 'package:sip_cli/src/commands/pub_get_command.dart';
import 'package:sip_cli/src/domain/bindings.dart';
import 'package:sip_cli/src/domain/command_result.dart';
import 'package:sip_cli/src/domain/filter_type.dart';
import 'package:sip_cli/src/domain/run_many_scripts.dart';
import 'package:test/test.dart';

import '../../utils/fake_args.dart';
import '../../utils/test_scoped.dart';

void main() {
  group('finds test directories', () {
    late FileSystem fs;
    late _TestBindings bindings;
    late PubGetCommand command;
    late _MockRunManyScripts runManyScripts;
    late FakeArgs args;

    setUp(() {
      bindings = _TestBindings();
      runManyScripts = _MockRunManyScripts();
      args = FakeArgs();
      fs = MemoryFileSystem.test();

      command = const PubGetCommand();

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

    @isTest
    void test(String description, void Function() fn) {
      testScoped(
        description,
        fn,
        fileSystem: () => fs,
        bindings: () => bindings,
        runManyScripts: () => runManyScripts,
        args: () => args,
      );
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

      args['recursive'] = true;

      final result = await command.run();

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

class _MockRunManyScripts extends Mock implements RunManyScripts {}
