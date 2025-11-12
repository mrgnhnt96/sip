// ignore_for_file: avoid_redundant_argument_values

import 'dart:io' as io;

import 'package:file/file.dart';
import 'package:file/memory.dart';
import 'package:meta/meta.dart';
import 'package:mocktail/mocktail.dart';
import 'package:path/path.dart' as path;
import 'package:sip_cli/src/commands/script_run_command.dart';
import 'package:sip_cli/src/domain/bindings.dart';
import 'package:sip_cli/src/domain/command_result.dart';
import 'package:sip_cli/src/domain/pubspec_yaml.dart';
import 'package:sip_cli/src/domain/script_to_run.dart';
import 'package:sip_cli/src/domain/scripts_yaml.dart';
import 'package:test/test.dart';

import '../../../utils/test_scoped.dart';

void main() {
  group('concurrency groups test', () {
    late FileSystem fs;
    late Bindings bindings;

    setUpAll(() {
      registerFallbackValue(const ConcurrentBreak() as Runnable);
    });

    setUp(() {
      bindings = _MockBindings();

      when(
        () => bindings.runScriptWithOutput(
          any(),
          bail: any(named: 'bail'),
          onOutput: any(named: 'onOutput'),
        ),
      ).thenAnswer(
        (_) async => const CommandResult(exitCode: 0, output: '', error: ''),
      );

      fs = MemoryFileSystem.test();

      final cwd = fs.directory(path.join('packages', 'sip'))
        ..createSync(recursive: true);
      fs.currentDirectory = cwd;
    });

    ScriptRunCommand setupScripts() {
      final input = io.File(
        path.joinAll([
          'test',
          'e2e',
          'run',
          'complex_concurrency',
          'inputs',
          'scripts.yaml',
        ]),
      ).readAsStringSync();

      fs.file(ScriptsYaml.fileName)
        ..createSync(recursive: true)
        ..writeAsStringSync(input);
      fs.file(PubspecYaml.fileName)
        ..createSync(recursive: true)
        ..writeAsStringSync('');

      return const ScriptRunCommand();
    }

    @isTest
    void test(String description, Future<void> Function() fn) {
      testScoped(
        description,
        fn,
        fileSystem: () => fs,
        bindings: () => bindings,
      );
    }

    test('should run complex concurrency', () async {
      final command = setupScripts();

      await command.run(['test-suite']);
      final commands = verify(
        () => bindings.runScriptWithOutput(
          captureAny(),
          onOutput: any(named: 'onOutput'),
        ),
      ).captured;

      final dirs = [
        ('revali_server', 'methods'),
        ('revali_server', 'custom_return_types'),
        ('revali_server', 'primitive_return_types'),
        ('revali_server', 'null_primitive_return_types'),
        ('revali_server', 'middleware'),
        ('revali_server', 'params'),
        ('revali_server', 'custom_params'),
        ('revali_server', 'sse'),
        ('revali_server', 'sse_custom'),
        ('revali_client', 'primitive_return_types'),
        ('revali_client', 'null_primitive_return_types'),
        ('revali_client', 'custom_return_types'),
        ('revali_client', 'methods'),
        ('revali_client', 'params'),
        ('revali_client', 'sse'),
        ('revali_client', 'sse_custom'),
        ('revali_client', 'websockets/custom_return_types'),
        ('revali_client', 'websockets/primitive_return_types'),
        ('revali_client', 'websockets/params'),
        ('revali_client', 'websockets/null_primitive_return_types'),
        ('revali_client', 'websockets/two_way'),
      ];

      expect(commands, hasLength(dirs.length + 2));

      for (final (index, command) in commands.sublist(0, dirs.length).indexed) {
        final (testType, dir) = dirs[index];
        final expected =
            '''
cd "/packages/sip" || exit 1

DIR=$dir
TEST_DIR=test_suite/constructs/$testType/\$DIR
echo \$TEST_DIR
cd \$TEST_DIR || exit 1
# get the line number of the first line that contains 'path: .revali/*'
LINE_NUMBER=\$(grep -n "path: .revali/*" pubspec.yaml | cut -d: -f1)

if [ -n "\$LINE_NUMBER" ]; then
  # comment out the line and the preceding line
  sed -i '' "\$((LINE_NUMBER))s/^/#/" pubspec.yaml
  sed -i '' "\$((LINE_NUMBER - 1))s/^/#/" pubspec.yaml
fi

if [ -z "" ]; then
  dart run revali dev --generate-only --recompile
fi

# get the line number of the first line that contains 'path: .revali/*'
LINE_NUMBER=\$(grep -n "path: .revali/*" pubspec.yaml | cut -d: -f1)

if [ -n "\$LINE_NUMBER" ]; then
  # uncomment the line and the preceding line
  sed -i '' "\$((LINE_NUMBER))s/^#//" pubspec.yaml
  sed -i '' "\$((LINE_NUMBER - 1))s/^#//" pubspec.yaml
fi

if [ ! \$? = 0 ]; then
  echo "failed to generate revali code"
  exit 1
fi''';

        expect((command as String).split('\n'), expected.split('\n'));
      }

      final [..., testScript, echo] = commands;

      expect(testScript, r'''
cd "/packages/sip" || exit 1

# if [ -n "" ]; then
#   exit 0
# fi
echo "doing this"

cd test_suite || exit 1

sip test --test-randomize-ordering-seed random --bail --recursive --concurrent

if [ $? -ne 0 ]; then
  exit 1
fi''');

      expect(echo, '''
cd "/packages/sip" || exit 1

echo "hi"''');
    });
  });
}

class _MockBindings extends Mock implements Bindings {}
