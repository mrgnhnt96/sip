import 'package:file/file.dart';
import 'package:path/path.dart' as path;
import 'package:sip_cli/domain/cwd_impl.dart';
import 'package:sip_cli/domain/pubspec_yaml_impl.dart';
import 'package:sip_cli/domain/scripts_yaml_impl.dart';
import 'package:sip_cli/setup/setup.dart';
import 'package:sip_script_runner/sip_script_runner.dart';
import 'package:test/test.dart';

import '../../utils/setup_testing_dependency_injection.dart';

void main() {
  group('$Variables', () {
    late Variables variables;
    late FileSystem fs;

    setUp(() {
      setupTestingDependencyInjection();
      fs = getIt<FileSystem>();
    });

    void createPubspecAndScripts() {
      fs.file(PubspecYaml.fileName).createSync(recursive: true);
      fs.file(ScriptsYaml.fileName).createSync(recursive: true);

      variables = Variables(
        pubspecYaml: PubspecYamlImpl(),
        scriptsYaml: ScriptsYamlImpl(),
        cwd: CWDImpl(),
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
  });
}
