import 'dart:async';

import 'package:file/file.dart';
import 'package:file/memory.dart';
import 'package:meta/meta.dart';
import 'package:sip_cli/src/domain/pubspec_yaml.dart';
import 'package:sip_cli/src/domain/script.dart';
import 'package:sip_cli/src/domain/script_to_run.dart';
import 'package:sip_cli/src/domain/scripts_yaml.dart';
import 'package:test/test.dart';

import '../../utils/test_scoped.dart';

void main() {
  group(Script, () {
    late FileSystem fs;

    setUp(() {
      fs = MemoryFileSystem.test();
    });

    @isTest
    void test(String description, FutureOr<void> Function() fn) {
      testScoped(description, fn, fileSystem: () => fs);
    }

    test('should resolve variables', () {
      fs.file(PubspecYaml.fileName)
        ..createSync(recursive: true)
        ..writeAsStringSync('''
name: test
version: 1.0.0
''');

      fs.file(ScriptsYaml.fileName)
        ..createSync(recursive: true)
        ..writeAsStringSync(r'''
(variables):
  a-variable: "a value"
test:
    - echo "whats up"
    - ${{ format }}

format:
  - echo "format"
  - ${{ some.other }} ${{ --flag}}

some:
  other:
    - ${{a-variable}}
    - ${{ --flag}}
    - echo "sup"
    - ${{ something.else }}

something:
  else:
    - echo "else"
''');
      final script = Script(
        name: 'test',
        commands: ['echo "whats up"', r'${{ format }}'],
      );

      final (resolved, code) = script.resolve();

      expect(code, isNull);

      expect(resolved!.commands, hasLength(5));

      for (final command in resolved.commands) {
        switch (command) {
          case ScriptToRun(exe: 'echo "whats up"'):
          case ScriptToRun(exe: 'echo "format"'):
          case ScriptToRun(exe: 'a value'):
          case ScriptToRun(exe: 'echo "sup"'):
          case ScriptToRun(exe: 'echo "else"'):
            continue;
          default:
            fail('Unexpected command: $command');
        }
      }
    });

    test('should throw when circular reference is detected', () {
      fs.file(ScriptsYaml.fileName)
        ..createSync(recursive: true)
        ..writeAsStringSync(r'''
(version): 1
(variables):
  a-variable: "a value"
test:
    - echo "whats up"
    - ${{ format }}

format:
  - echo "format"
  - ${{ test }} ${{ --flag}}
''');
      final script = Script(
        name: 'test',
        commands: ['echo "whats up"', r'${{ format }}'],
      );

      expect(script.resolve, throwsA(isA<Exception>()));
    });
  });
}
