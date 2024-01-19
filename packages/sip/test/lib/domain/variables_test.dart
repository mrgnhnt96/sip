import 'package:file/file.dart';
import 'package:path/path.dart' as path;
import 'package:sip/domain/cwd_impl.dart';
import 'package:sip/domain/pubspec_yaml_impl.dart';
import 'package:sip/domain/scripts_yaml_impl.dart';
import 'package:sip/setup/dependency_injection.dart';
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

    group('#replace', () {
      group('directory variables', () {
        late Directory currentDir;

        setUp(() {
          currentDir = fs.directory(path.join(path.separator, 'bin', 'nested'));

          currentDir.createSync(recursive: true);

          fs.currentDirectory = currentDir;

          createPubspecAndScripts();
        });

        test('should be replaced', () {
          final script = Script.defaults(
            commands: [
              'echo {projectRoot}',
              'echo {scriptsRoot}',
              'echo {cwd}',
            ],
          );

          final config = ScriptsConfig(scripts: {'dirs': script});

          final replaced = variables.replace(script, config);

          expect(replaced, isNotNull);
          expect(replaced, isNotEmpty);
          expect(replaced.length, 3);

          expect(replaced[0], 'echo ${currentDir.path}');
          expect(replaced[1], 'echo ${currentDir.path}');
          expect(replaced[2], 'echo ${currentDir.path}');
        });
      });

      group('non directory variables', () {
        setUp(() {
          createPubspecAndScripts();
        });

        group('script path variables', () {
          test('should replace when found', () {
            final script = Script.defaults(
              commands: [
                r'cd {projectRoot}/packages/application && {$build_runner:build}',
              ],
            );

            final config = ScriptsConfig(scripts: {
              'link': script,
              'build_runner': Script.defaults(
                scripts: ScriptsConfig(
                  scripts: {
                    'build': Script.defaults(
                      commands: [
                        'dart run build_runner build --delete-conflicting-outputs',
                      ],
                    ),
                  },
                ),
              )
            });

            final replaced = variables.replace(script, config);

            expect(replaced, isNotNull);
            expect(replaced, hasLength(1));

            expect(
              replaced[0],
              'cd ${path.separator}/packages/application && dart run build_runner build --delete-conflicting-outputs',
            );
          });

          test('should duplicate commands when script has multiple commands',
              () {
            final script = Script.defaults(
              commands: [
                r'cd {projectRoot}/packages/application && {$build_runner:build}',
              ],
            );

            final config = ScriptsConfig(scripts: {
              'link': script,
              'build_runner': Script.defaults(
                scripts: ScriptsConfig(
                  scripts: {
                    'build': Script.defaults(
                      commands: [
                        'dart run build_runner clean',
                        'dart run build_runner build --delete-conflicting-outputs',
                      ],
                    ),
                  },
                ),
              )
            });

            final replaced = variables.replace(script, config);

            expect(replaced, isNotNull);
            expect(replaced, hasLength(2));

            expect(replaced, [
              'cd ${path.separator}/packages/application && dart run build_runner clean',
              'cd ${path.separator}/packages/application && dart run build_runner build --delete-conflicting-outputs',
            ]);
          });

          test('should resolve script that references another script', () {
            final script = Script.defaults(
              commands: [
                r'cd {projectRoot}/packages/application && {$build_runner:watch}',
              ],
            );

            final config = ScriptsConfig(scripts: {
              'link': script,
              'build_runner': Script.defaults(
                scripts: ScriptsConfig(
                  scripts: {
                    'clean': Script.defaults(
                      commands: [
                        'dart run build_runner clean',
                      ],
                    ),
                    'watch': Script.defaults(
                      commands: [
                        r'{$build_runner:clean}',
                        'dart run build_runner watch --delete-conflicting-outputs',
                      ],
                    ),
                  },
                ),
              )
            });

            final replaced = variables.replace(script, config);

            expect(replaced, isNotNull);
            expect(replaced, hasLength(2));

            expect(replaced, [
              'cd ${path.separator}/packages/application && dart run build_runner clean',
              'cd ${path.separator}/packages/application && dart run build_runner watch --delete-conflicting-outputs',
            ]);
          });
        });
      });
    });
  });
}
