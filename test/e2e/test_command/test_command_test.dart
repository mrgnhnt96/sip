import 'package:file/file.dart';
import 'package:file/memory.dart';
import 'package:mason_logger/mason_logger.dart';
import 'package:meta/meta.dart';
import 'package:mocktail/mocktail.dart';
import 'package:path/path.dart' as path;
import 'package:sip_cli/src/commands/test_run_command.dart';
import 'package:sip_cli/src/domain/args.dart';
import 'package:sip_cli/src/domain/bindings.dart';
import 'package:sip_cli/src/domain/command_result.dart';
import 'package:test/test.dart';

import '../../utils/test_scoped.dart';

void main() {
  group('finds test directories', () {
    late FileSystem fs;
    late Bindings bindings;
    late TestRunCommand command;
    late Args args;

    setUp(() {
      bindings = _MockBindings();
      fs = MemoryFileSystem.test();
      args = const Args(args: {'recursive': true});

      when(
        () => bindings.runScriptWithOutput(
          any(),
          onOutput: any(named: 'onOutput'),
          bail: any(named: 'bail'),
        ),
      ).thenAnswer(
        (_) async => const CommandResult(exitCode: 0, output: '', error: ''),
      );

      command = const TestRunCommand();

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
    void test(String description, Future<void> Function() fn) {
      testScoped(
        description,
        fn,
        fileSystem: () => fs,
        args: () => args,
        bindings: () => bindings,
      );
    }

    test(
      'when directories start with test but are not test directories',
      () async {
        createPackage(['test_dir']);
        createPackage(['test_dir2']);

        final result = await command.run([]);

        expect(result.code, ExitCode.success.code);
        final scripts = verify(
          () => bindings.runScriptWithOutput(
            captureAny(),
            onOutput: any(named: 'onOutput'),
            bail: any(named: 'bail'),
          ),
        ).captured;

        const expected = [
          '''
cd "/packages/sip/test_dir" || exit 1

dart test test/.test_optimizer.dart''',
          '''
cd "/packages/sip/test_dir2" || exit 1

dart test test/.test_optimizer.dart''',
        ];

        expect(scripts, expected);
      },
    );
  });
}

class _MockBindings extends Mock implements Bindings {}
