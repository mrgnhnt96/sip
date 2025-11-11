import 'package:file/file.dart';
import 'package:file/memory.dart';
import 'package:mason_logger/mason_logger.dart';
import 'package:meta/meta.dart';
import 'package:mocktail/mocktail.dart';
import 'package:path/path.dart' as p;
import 'package:sip_cli/src/commands/pub_get_command.dart';
import 'package:sip_cli/src/domain/bindings.dart';
import 'package:sip_cli/src/domain/command_result.dart';
import 'package:sip_cli/src/domain/script_runner.dart';
import 'package:sip_cli/src/domain/script_to_run.dart';
import 'package:test/test.dart';

import '../../utils/fake_args.dart';
import '../../utils/test_scoped.dart';

void main() {
  group('finds test directories', () {
    late FileSystem fs;
    late Bindings bindings;
    late PubGetCommand command;
    late FakeArgs args;
    late ScriptRunner scriptRunner;

    setUp(() {
      bindings = _MockBindings();
      args = FakeArgs();
      scriptRunner = _MockScriptRunner();
      fs = MemoryFileSystem.test();

      command = const PubGetCommand();

      final cwd = fs.directory(p.join('packages', 'sip'))
        ..createSync(recursive: true);
      fs.currentDirectory = cwd;

      when(
        () => scriptRunner.groupRun(
          any(),
          bail: any(named: 'bail'),
          disableConcurrency: any(named: 'disableConcurrency'),
          showOutput: any(named: 'showOutput'),
        ),
      ).thenAnswer(
        (_) async => const CommandResult(exitCode: 0, output: '', error: ''),
      );
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
    void test(String description, Future<void> Function() fn) {
      testScoped(
        description,
        fn,
        fileSystem: () => fs,
        bindings: () => bindings,
        args: () => args,
        scriptRunner: () => scriptRunner,
      );
    }

    test('pub get with recursive flag should run all concurrently', () async {
      createDirs([
        ['packages', 'a'],
        ['packages', 'b'],
        ['packages', 'c'],
        ['packages', 'd'],
      ]);

      args['recursive'] = true;

      final result = await command.run();

      expect(result.code, ExitCode.success.code);
      final [commands] = verify(
        () =>
            scriptRunner.groupRun(captureAny(), bail: false, showOutput: false),
      ).captured;

      final [a, b, c, d] = commands as List<ScriptToRun>;

      expect(a.exe, 'dart pub get');
      expect(a.workingDirectory, '/packages/sip/packages/a');
      expect(a.label, '(dart)    ./packages/a');

      expect(b.exe, 'dart pub get');
      expect(b.workingDirectory, '/packages/sip/packages/b');
      expect(b.label, '(dart)    ./packages/b');

      expect(c.exe, 'dart pub get');
      expect(c.workingDirectory, '/packages/sip/packages/c');
      expect(c.label, '(dart)    ./packages/c');

      expect(d.exe, 'dart pub get');
      expect(d.workingDirectory, '/packages/sip/packages/d');
      expect(d.label, '(dart)    ./packages/d');
    });
  });
}

class _MockBindings extends Mock implements Bindings {}

class _MockScriptRunner extends Mock implements ScriptRunner {}
