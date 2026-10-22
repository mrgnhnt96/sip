import 'package:file/file.dart';
import 'package:file/memory.dart';
import 'package:mason_logger/mason_logger.dart';
import 'package:meta/meta.dart';
import 'package:mocktail/mocktail.dart';
import 'package:sip_cli/src/commands/test_command/test_command.dart';
import 'package:sip_cli/src/domain/args.dart';
import 'package:sip_cli/src/domain/bindings.dart';
import 'package:sip_cli/src/domain/command_result.dart';
import 'package:sip_cli/src/domain/message.dart';
import 'package:sip_cli/src/domain/message_action.dart';
import 'package:test/test.dart';

import '../../utils/test_scoped.dart';

void main() {
  // https://github.com/mrgnhnt96/sip/issues/1
  group('sip test with a file path', () {
    late FileSystem fs;
    late Bindings bindings;

    setUp(() {
      bindings = _MockBindings();
      fs = MemoryFileSystem.test();

      when(
        () => bindings.runScriptWithOutput(
          any(),
          onOutput: any(named: 'onOutput'),
          bail: any(named: 'bail'),
        ),
      ).thenAnswer(
        (_) async => const CommandResult(exitCode: 0, output: '', error: ''),
      );

      fs.file('/pkg/pubspec.yaml')
        ..createSync(recursive: true)
        ..writeAsStringSync('''
name: pkg

environment:
  sdk: ">=3.6.0 <4.0.0"
''');
      for (final name in ['my_test.dart', 'other_test.dart']) {
        fs.file('/pkg/test/path/$name')
          ..createSync(recursive: true)
          ..writeAsStringSync('void main() {}');
      }
      fs.currentDirectory = fs.directory('/pkg');
    });

    // Mirrors the real dispatch: Args.parse of the whole command line, then
    // the `test` path segment handed to TestCommand.
    @isTest
    void test(String description, List<String> argv) {
      late Args args;

      testScoped(
        description,
        () async {
          final result = await const TestCommand().run(
            args.path.skip(1).toList(),
          );

          expect(result.code, ExitCode.success.code);

          final scripts = verify(
            () => bindings.runScriptWithOutput(
              captureAny(),
              onOutput: any(named: 'onOutput'),
              bail: any(named: 'bail'),
            ),
          ).captured.cast<String>();

          expect(scripts, hasLength(1));
          expect(scripts.single, contains('/pkg/test/path/my_test.dart'));
          expect(scripts.single, isNot(contains('other_test.dart')));
          expect(scripts.single, isNot(contains('--no-optimize')));
          expect(scripts.single, isNot(contains('.test_optimizer')));
        },
        fileSystem: () => fs,
        bindings: () => bindings,
        args: () => args = Args.parse(argv),
      );
    }

    test('flags after the path', [
      'test',
      'test/path/my_test.dart',
      '--no-optimize',
      '--update-goldens',
    ]);

    test('flags before the path', [
      'test',
      '--no-optimize',
      '--update-goldens',
      'test/path/my_test.dart',
    ]);
  });

  // https://github.com/mrgnhnt96/sip/issues/18
  group('sip test --experimental-bucket with given paths', () {
    late FileSystem fs;
    late Bindings bindings;
    late List<String> scripts;
    late Map<String, String> wrappers;

    const widgetTest = """
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('renders', (tester) async {});
}
""";

    const testFiles = [
      'test/a_test.dart',
      'test/b_test.dart',
      'test/other/c_test.dart',
    ];

    setUp(() {
      bindings = _MockBindings();
      fs = MemoryFileSystem.test();
      scripts = [];
      wrappers = {};

      fs.file('/pkg/pubspec.yaml')
        ..createSync(recursive: true)
        ..writeAsStringSync('''
name: pkg

dependencies:
  flutter:
    sdk: flutter
''');
      for (final file in testFiles) {
        fs.file('/pkg/$file')
          ..createSync(recursive: true)
          ..writeAsStringSync(widgetTest);
      }
      fs.currentDirectory = fs.directory('/pkg');
    });

    @isTest
    void test(
      String description,
      List<String> argv,
      void Function(ExitCode result) body, {
      CommandResult Function(String script, void Function(String) output)?
      answer,
    }) {
      late Args args;

      testScoped(
        description,
        () async {
          when(
            () => bindings.runScriptWithOutput(
              any(),
              onOutput: any(named: 'onOutput'),
              bail: any(named: 'bail'),
            ),
          ).thenAnswer((invocation) async {
            final script = invocation.positionalArguments.first as String;
            final onOutput =
                invocation.namedArguments[#onOutput]
                    as MessageAction? Function(Message);
            scripts.add(script);

            // The wrappers are deleted once the run ends.
            for (final file in fs.directory('/pkg/test').listSync()) {
              if (file is File && file.basename.startsWith('.test_optimizer')) {
                wrappers[file.basename] = file.readAsStringSync();
              }
            }

            void output(String line) => onOutput(Message(line));

            if (answer != null) return answer(script, output);

            // Report a pass for every file in the run, or the fallback
            // re-runs the files whose results never arrived.
            for (final file in testFiles) {
              if (script.contains(file) ||
                  wrappers.values.any((w) => w.contains("'$file'"))) {
                output('✅ $file renders');
              }
            }

            return const CommandResult(exitCode: 0, output: '', error: '');
          });

          final result = await const TestCommand().run(
            args.path.skip(1).toList(),
          );

          body(result);
        },
        fileSystem: () => fs,
        bindings: () => bindings,
        args: () => args = Args.parse(argv),
      );
    }

    const bucket = 'test/.test_optimizer_bucket_0.dart';

    test(
      'combines the given files into one bucket',
      [
        'test',
        '--experimental-bucket',
        '--bucket-count',
        '1',
        'test/a_test.dart',
        'test/b_test.dart',
      ],
      (result) {
        expect(result.code, ExitCode.success.code);
        expect(scripts, hasLength(1));
        expect(scripts.single, contains(bucket));
        expect(scripts.single, isNot(contains('a_test.dart')));
        expect(scripts.single, isNot(contains('b_test.dart')));

        expect(wrappers.keys, ['.test_optimizer_bucket_0.dart']);
        final wrapper = wrappers['.test_optimizer_bucket_0.dart']!;
        expect(wrapper, contains("group('test/a_test.dart'"));
        expect(wrapper, contains("group('test/b_test.dart'"));
        expect(wrapper, isNot(contains('c_test.dart')));
      },
    );

    test(
      'buckets the test files inside a given directory',
      ['test', '--experimental-bucket', '--bucket-count', '1', 'test/other'],
      (result) {
        expect(result.code, ExitCode.success.code);
        expect(scripts, hasLength(1));
        expect(scripts.single, contains(bucket));

        final wrapper = wrappers['.test_optimizer_bucket_0.dart']!;
        expect(wrapper, contains("group('test/other/c_test.dart'"));
        expect(wrapper, isNot(contains('a_test.dart')));
      },
    );

    test(
      'keeps given files matching --bucket-solo out of the bucket',
      [
        'test',
        '--experimental-bucket',
        '--bucket-count',
        '1',
        '--bucket-solo',
        'test/b_test.dart',
        'test/a_test.dart',
        'test/b_test.dart',
        'test/other/c_test.dart',
      ],
      (result) {
        expect(result.code, ExitCode.success.code);
        expect(scripts, hasLength(1));
        expect(scripts.single, contains(bucket));
        expect(scripts.single, contains('test/.test_optimizer_solo_0.dart'));

        final combined = wrappers['.test_optimizer_bucket_0.dart']!;
        expect(combined, contains("group('test/a_test.dart'"));
        expect(combined, contains("group('test/other/c_test.dart'"));
        expect(combined, isNot(contains('b_test.dart')));
        expect(
          wrappers['.test_optimizer_solo_0.dart'],
          contains("group('test/b_test.dart'"),
        );
      },
    );

    test(
      're-runs the given files alone when their bucket never reports',
      [
        'test',
        '--experimental-bucket',
        '--bucket-count',
        '1',
        'test/a_test.dart',
        'test/b_test.dart',
      ],
      answer: (script, output) {
        if (script.contains(bucket)) {
          return const CommandResult(exitCode: 1, output: '', error: '');
        }

        output('✅ test/a_test.dart renders');
        output('✅ test/b_test.dart renders');
        return const CommandResult(exitCode: 0, output: '', error: '');
      },
      (result) {
        expect(result.code, ExitCode.success.code);
        expect(scripts, hasLength(2));
        expect(scripts.last, contains('test/a_test.dart'));
        expect(scripts.last, contains('test/b_test.dart'));
        expect(scripts.last, isNot(contains('.test_optimizer')));
      },
    );

    test(
      'passes the given files straight through without the flag',
      ['test', 'test/a_test.dart', 'test/b_test.dart'],
      (result) {
        expect(result.code, ExitCode.success.code);
        expect(scripts, hasLength(1));
        expect(scripts.single, isNot(contains('.test_optimizer')));
        expect(wrappers, isEmpty);
      },
    );

    test(
      'deletes the generated wrappers after the run',
      ['test', '--experimental-bucket', 'test/a_test.dart'],
      (result) {
        expect(result.code, ExitCode.success.code);
        expect(wrappers, isNotEmpty);
        expect(
          fs
              .directory('/pkg/test')
              .listSync()
              .where((e) => e.basename.startsWith('.test_optimizer')),
          isEmpty,
        );
      },
    );
  });
}

class _MockBindings extends Mock implements Bindings {}
