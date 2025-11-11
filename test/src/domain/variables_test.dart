import 'dart:async';

import 'package:file/file.dart';
import 'package:file/memory.dart';
import 'package:meta/meta.dart';
import 'package:path/path.dart' as path;
import 'package:sip_cli/src/deps/variables.dart';
import 'package:sip_cli/src/domain/pubspec_yaml.dart';
import 'package:sip_cli/src/domain/scripts_yaml.dart';
import 'package:sip_cli/src/domain/variables.dart';
import 'package:test/test.dart';

import '../../utils/test_scoped.dart';

void main() {
  group(Variables, () {
    late FileSystem fs;
    late File pubspec;
    late File scripts;

    setUp(() {
      fs = MemoryFileSystem.test();

      pubspec = fs.file(PubspecYaml.fileName);
      scripts = fs.file(ScriptsYaml.fileName);
    });

    void createPubspecAndScripts() {
      pubspec.createSync(recursive: true);
      scripts.createSync(recursive: true);
    }

    @isTest
    void test(String description, FutureOr<void> Function() fn) {
      testScoped(description, fn, fileSystem: () => fs);
    }

    group('#populate', () {
      setUp(createPubspecAndScripts);

      test('should add projectRoot, scriptsRoot, and cwd', () {
        final populated = variables.retrieve();

        expect(populated['projectRoot'], isNotNull);
        expect(populated['scriptsRoot'], isNotNull);
        expect(populated['cwd'], isNotNull);

        expect(populated['projectRoot'], path.separator);
        expect(populated['scriptsRoot'], path.separator);
        expect(populated['cwd'], path.separator);
      });

      test('should add executables', () {
        scripts.writeAsStringSync('''
(executables):
  flutter: fvm flutter
  dart: fvm dart
''');

        final populated = variables.retrieve();

        expect(populated['flutter'], 'fvm flutter');
        expect(populated['dart'], 'fvm dart');
      });
    });

    group('#variablePattern', () {
      test('matches', () {
        const matches = <String>[
          r'{$help}',
          r'{$help:me}',
          r'{$help:me:please}',
        ];

        for (final match in matches) {
          expect(Variables.oldVariablePattern.hasMatch(match), isTrue);
        }
      });
    });
  });
}
