import 'dart:io' as io;

import 'package:file/file.dart';
import 'package:file/memory.dart';
import 'package:meta/meta.dart';
import 'package:mocktail/mocktail.dart';
import 'package:path/path.dart' as path;
import 'package:sip_cli/src/commands/script_run_command.dart';
import 'package:sip_cli/src/domain/bindings.dart';
import 'package:sip_cli/src/domain/command_result.dart';
import 'package:sip_cli/src/domain/filter_type.dart';
import 'package:sip_cli/src/domain/pubspec_yaml.dart';
import 'package:sip_cli/src/domain/script_to_run.dart';
import 'package:sip_cli/src/domain/scripts_yaml.dart';
import 'package:test/test.dart';

import '../../../utils/test_scoped.dart';

void main() {
  group('build runner e2e', () {
    late FileSystem fs;
    late _TestBindings bindings;

    setUpAll(() {
      registerFallbackValue(const ConcurrentBreak() as Runnable);
    });

    setUp(() {
      bindings = _TestBindings();
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

    test('runs gracefully', () async {
      final input = io.File(
        path.join(
          'test',
          'e2e',
          'run',
          'build_runner',
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

      await const ScriptRunCommand().run(['build_runner', 'b']);

      expect(bindings.scripts, [
        'cd "/packages/sip" || exit 1',
        '',
        'dart run build_runner clean;',
        'dart run build_runner build --delete-conflicting-outputs',
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
  }) {
    scripts.addAll(script.split('\n'));
    return Future.value(
      const CommandResult(exitCode: 0, output: '', error: ''),
    );
  }
}
