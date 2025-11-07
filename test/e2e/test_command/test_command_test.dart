import 'package:file/file.dart';
import 'package:file/memory.dart';
import 'package:mason_logger/mason_logger.dart';
import 'package:meta/meta.dart';
import 'package:path/path.dart' as path;
import 'package:sip_cli/src/commands/test_run_command.dart';
import 'package:sip_cli/src/domain/bindings.dart';
import 'package:sip_cli/src/domain/command_result.dart';
import 'package:sip_cli/src/domain/filter_type.dart';
import 'package:test/test.dart';

import '../../utils/test_scoped.dart';

void main() {
  group('finds test directories', () {
    late FileSystem fs;
    late _TestBindings bindings;
    late TestRunCommand command;

    setUp(() {
      bindings = _TestBindings();
      fs = MemoryFileSystem.test();

      command = TestRunCommand();

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

    @isTest
    void test(String description, void Function() fn) {
      testScoped(
        description,
        fn,
        fileSystem: () => fs,
        bindings: () => bindings,
      );
    }

    test(
      'when directories start with test but are not test directories',
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
      },
    );
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
