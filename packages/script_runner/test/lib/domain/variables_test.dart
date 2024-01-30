import 'package:mocktail/mocktail.dart';
import 'package:sip_script_runner/domain/cwd.dart';
import 'package:sip_script_runner/domain/optional_flags.dart';
import 'package:sip_script_runner/domain/pubspec_yaml.dart';
import 'package:sip_script_runner/domain/script.dart';
import 'package:sip_script_runner/domain/scripts_config.dart';
import 'package:sip_script_runner/domain/scripts_yaml.dart';
import 'package:sip_script_runner/domain/variables.dart';
import 'package:test/test.dart';

class _FakePubspecYaml extends Fake implements PubspecYaml {
  _FakePubspecYaml(this._path);

  final String _path;

  @override
  String? nearest() => _path;
}

class _FakeScriptsYaml extends Fake implements ScriptsYaml {
  _FakeScriptsYaml(this._path);
  final String _path;

  @override
  String? nearest() => _path;
}

class _FakeCWD extends Fake implements CWD {
  _FakeCWD(this.path);

  @override
  final String path;
}

void main() {
  group('$Variables', () {
    group('#populate', () {
      test('should populate nested dir', () {
        final variables = Variables(
          pubspecYaml: _FakePubspecYaml('/some/dir/pubspec.yaml'),
          scriptsYaml: _FakeScriptsYaml('/some/dir/scripts.yaml'),
          cwd: _FakeCWD('/some/dir'),
        );

        final populated = variables.populate();

        expect(populated['projectRoot'], isNotNull);
        expect(populated['scriptsRoot'], isNotNull);
        expect(populated['cwd'], isNotNull);

        expect(populated['projectRoot'], '/some/dir');
        expect(populated['scriptsRoot'], '/some/dir');
        expect(populated['cwd'], '/some/dir');
      });

      test('should populate from nested dir', () {
        final variables = Variables(
          pubspecYaml: _FakePubspecYaml('/some/dir/pubspec.yaml'),
          scriptsYaml: _FakeScriptsYaml('/some/dir/scripts.yaml'),
          cwd: _FakeCWD('/some/dir/lib'),
        );

        final populated = variables.populate();

        expect(populated['projectRoot'], isNotNull);
        expect(populated['scriptsRoot'], isNotNull);
        expect(populated['cwd'], isNotNull);

        expect(populated['projectRoot'], '/some/dir');
        expect(populated['scriptsRoot'], '/some/dir');
        expect(populated['cwd'], '/some/dir/lib');
      });

      test('should populate from root', () {
        final variables = Variables(
          pubspecYaml: _FakePubspecYaml('/pubspec.yaml'),
          scriptsYaml: _FakeScriptsYaml('/scripts.yaml'),
          cwd: _FakeCWD('/'),
        );

        final populated = variables.populate();

        expect(populated['projectRoot'], isNotNull);
        expect(populated['scriptsRoot'], isNotNull);
        expect(populated['cwd'], isNotNull);

        expect(populated['projectRoot'], '/');
        expect(populated['scriptsRoot'], '/');
        expect(populated['cwd'], '/');
      });
    });

    group('#replace', () {
      group('directory variables', () {
        late Variables variables;

        setUp(() {
          variables = Variables(
            pubspecYaml: _FakePubspecYaml('/some/dir/pubspec.yaml'),
            scriptsYaml: _FakeScriptsYaml('/some/dir/scripts.yaml'),
            cwd: _FakeCWD('/some/dir'),
          );
        });

        test('should be replaced', () {
          final script = Script.defaults(
            name: '',
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

          expect(replaced[0], 'echo /some/dir');
          expect(replaced[1], 'echo /some/dir');
          expect(replaced[2], 'echo /some/dir');
        });
      });

      group('script references', () {
        late Variables variables;

        setUp(() {
          variables = Variables(
            pubspecYaml: _FakePubspecYaml('pubspec.yaml'),
            scriptsYaml: _FakeScriptsYaml('scripts.yaml'),
            cwd: _FakeCWD('/'),
          );
        });

        group('script path variables', () {
          test('should replace when found', () {
            final script = Script.defaults(
              name: '',
              commands: [
                r'cd {projectRoot}/packages/application && {$build_runner:build}',
              ],
            );

            final config = ScriptsConfig(scripts: {
              'link': script,
              'build_runner': Script.defaults(
                name: '',
                scripts: ScriptsConfig(
                  scripts: {
                    'build': Script.defaults(
                      name: '',
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
              'cd ./packages/application && dart run build_runner build --delete-conflicting-outputs',
            );
          });

          test('should duplicate commands when script has multiple commands',
              () {
            final script = Script.defaults(
              name: '',
              commands: [
                r'cd {projectRoot}/packages/application && {$build_runner:build}',
              ],
            );

            final config = ScriptsConfig(scripts: {
              'link': script,
              'build_runner': Script.defaults(
                name: '',
                scripts: ScriptsConfig(
                  scripts: {
                    'build': Script.defaults(
                      name: '',
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
              'cd ./packages/application && dart run build_runner clean',
              'cd ./packages/application && dart run build_runner build --delete-conflicting-outputs',
            ]);
          });

          test('should resolve script that references another script', () {
            final script = Script.defaults(
              name: '',
              commands: [
                r'cd {projectRoot}/packages/application && {$build_runner:watch}',
              ],
            );

            final config = ScriptsConfig(scripts: {
              'link': script,
              'build_runner': Script.defaults(
                name: '',
                scripts: ScriptsConfig(
                  scripts: {
                    'clean': Script.defaults(
                      name: '',
                      commands: [
                        'dart run build_runner clean',
                      ],
                    ),
                    'watch': Script.defaults(
                      name: '',
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
              'cd ./packages/application && dart run build_runner clean',
              'cd ./packages/application && dart run build_runner watch --delete-conflicting-outputs',
            ]);
          });
        });
      });

      group('optional flags', () {
        late Variables variables;

        setUp(() {
          variables = Variables(
            pubspecYaml: _FakePubspecYaml('pubspec.yaml'),
            scriptsYaml: _FakeScriptsYaml('scripts.yaml'),
            cwd: _FakeCWD('/'),
          );
        });

        test('should ignore flag when not provided', () {
          final flags = OptionalFlags(['--foo']);
          final script = Script.defaults(
            name: '',
            commands: [
              'echo "hello!" {--bar}',
            ],
          );

          final commands = variables.replace(
            script,
            ScriptsConfig(
              scripts: {
                'foo': script,
              },
            ),
            flags: flags,
          );

          expect(commands, isNotNull);
          expect(commands, hasLength(1));
          expect(commands, ['echo "hello!"']);
        });

        test('should add flag when provided', () {
          final flags = OptionalFlags(['--foo']);
          final script = Script.defaults(
            name: '',
            commands: [
              'echo "hello!" {--foo}',
            ],
          );

          final commands = variables.replace(
            script,
            ScriptsConfig(
              scripts: {
                'foo': script,
              },
            ),
            flags: flags,
          );

          expect(commands, isNotNull);
          expect(commands, hasLength(1));
          expect(commands, ['echo "hello!" --foo']);
        });

        test('should add flag with values when provided', () {
          final flags = OptionalFlags(['--foo', 'bar']);
          final script = Script.defaults(
            name: '',
            commands: [
              'echo "hello!" {--foo}',
            ],
          );

          final commands = variables.replace(
            script,
            ScriptsConfig(
              scripts: {
                'foo': script,
              },
            ),
            flags: flags,
          );

          expect(commands, isNotNull);
          expect(commands, hasLength(1));
          expect(commands, ['echo "hello!" --foo bar']);
        });
      });
    });
  });
}
