import 'dart:io' as io;

import 'package:file/file.dart';
import 'package:path/path.dart' as path;
import 'package:sip/commands/script_run_command.dart';
import 'package:sip/setup/setup.dart';
import 'package:sip_script_runner/sip_script_runner.dart';
import 'package:test/test.dart';

import '../../../utils/setup_testing_dependency_injection.dart';

void main() {
  group('coverage e2e', () {
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
          'coverage',
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

      await command.run(['test']);

      await Future.delayed(const Duration(milliseconds: 100));

      expect(
        mockBindings.scripts,
        ['cd /packages/sip && dart test'],
      );

      mockBindings.scripts.clear();

      await command.run(['test', '--coverage']);

      expect(
        mockBindings.scripts,
        ['cd /packages/sip && dart test --coverage'],
      );

      mockBindings.scripts.clear();

      await command.run(['test', '--coverage=banana']);

      expect(
        mockBindings.scripts,
        ['cd /packages/sip && dart test --coverage=banana'],
      );

      mockBindings.scripts.clear();

      await command.run(['test', '--coverage', 'monkey']);

      expect(
        mockBindings.scripts,
        ['cd /packages/sip && dart test --coverage monkey'],
      );
    });
  });
}

class MockBindings implements Bindings {
  final List<String> scripts = [];

  @override
  Future<int> runScript(String script, {bool showOutput = false}) async {
    scripts.add(script);

    return 0;
  }
}
