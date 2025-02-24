import 'package:file/file.dart';
import 'package:file/memory.dart';
import 'package:path/path.dart' as path;
import 'package:sip_cli/domain/cwd_impl.dart';
import 'package:sip_cli/domain/pubspec_yaml.dart';
import 'package:sip_cli/domain/pubspec_yaml_impl.dart';
import 'package:sip_cli/domain/scripts_yaml.dart';
import 'package:sip_cli/domain/scripts_yaml_impl.dart';
import 'package:sip_cli/domain/variables.dart';
import 'package:test/test.dart';

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

    Variables variables() {
      return Variables(
        pubspecYaml: PubspecYamlImpl(fs: fs),
        scriptsYaml: ScriptsYamlImpl(fs: fs),
        cwd: CWDImpl(fs: fs),
      );
    }

    group('#populate', () {
      setUp(createPubspecAndScripts);

      test('should add projectRoot, scriptsRoot, and cwd', () {
        final populated = variables().populate();

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

        final populated = variables().populate();

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
          expect(Variables.variablePattern.hasMatch(match), isTrue);
        }
      });
    });
  });
}
