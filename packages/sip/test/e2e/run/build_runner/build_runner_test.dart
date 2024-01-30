import 'dart:io' as io;

import 'package:file/file.dart';
import 'package:path/path.dart' as path;
import 'package:sip/commands/script_run_command.dart';
import 'package:sip/setup/setup.dart';
import 'package:sip_script_runner/sip_script_runner.dart';
import 'package:test/test.dart';

import '../../../utils/setup_testing_dependency_injection.dart';

void main() {
  group('build runner e2e', () {
    late FileSystem fs;
    late MockBindings mockBindings;

    setUp(() {
      setupTestingDependencyInjection();

      mockBindings = MockBindings();

      fs = getIt<FileSystem>();

      final cwd = fs.directory(path.join('packages', 'sip'))
        ..createSync(recursive: true);
      fs.currentDirectory = cwd;
    });

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

      final command = ScriptRunCommand(
        bindings: mockBindings,
      );

      await command.run(['build_runner', 'b']);

      expect(
        mockBindings.scripts,
        [
          'cd /packages/sip && dart run build_runner clean;\n'
              'dart run build_runner build --delete-conflicting-outputs',
        ],
      );
    });
  });
}

class MockBindings implements Bindings {
  final List<String> scripts = [];

  @override
  Future<int> runScript(String script, {bool showOutput = false}) {
    scripts.add(script);
    return Future.value(0);
  }
}
