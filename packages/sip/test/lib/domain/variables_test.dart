import 'package:file/file.dart';
import 'package:file/memory.dart';
import 'package:path/path.dart' as path;
import 'package:sip_cli/domain/cwd_impl.dart';
import 'package:sip_cli/domain/pubspec_yaml_impl.dart';
import 'package:sip_cli/domain/scripts_yaml_impl.dart';
import 'package:sip_script_runner/sip_script_runner.dart';
import 'package:test/test.dart';

void main() {
  group('$Variables', () {
    late Variables variables;
    late FileSystem fs;

    setUp(() {
      fs = MemoryFileSystem.test();
    });

    void createPubspecAndScripts() {
      fs.file(PubspecYaml.fileName).createSync(recursive: true);
      fs.file(ScriptsYaml.fileName).createSync(recursive: true);

      variables = Variables(
        pubspecYaml: PubspecYamlImpl(fs: fs),
        scriptsYaml: ScriptsYamlImpl(fs: fs),
        cwd: CWDImpl(fs: fs),
      );
    }

    group('#populate', () {
      group('directory variables', () {
        test('should populate', () {
          createPubspecAndScripts();

          final populated = variables.populate();

          expect(populated['projectRoot'], isNotNull);
          expect(populated['scriptsRoot'], isNotNull);
          expect(populated['cwd'], isNotNull);

          expect(populated['projectRoot'], path.separator);
          expect(populated['scriptsRoot'], path.separator);
          expect(populated['cwd'], path.separator);
        });
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
