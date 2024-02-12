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
  _FakeScriptsYaml(
    this._path, {
    Map<String, dynamic>? variables,
  }) : _variables = variables;
  final String _path;
  final Map<String, dynamic>? _variables;

  @override
  String? nearest() => _path;

  @override
  Map<String, dynamic>? variables() => _variables;
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

      test('should get defined variables', () {
        final variables = Variables(
          pubspecYaml: _FakePubspecYaml('/pubspec.yaml'),
          scriptsYaml: _FakeScriptsYaml('/scripts.yaml', variables: {
            'foo': 'bar',
          }),
          cwd: _FakeCWD('/'),
        );

        final populated = variables.populate();

        expect(populated['foo'], isNotNull);
        expect(populated['foo'], 'bar');
      });

      test('should not allow sip variables names', () {
        final variables = Variables(
          pubspecYaml: _FakePubspecYaml('/pubspec.yaml'),
          scriptsYaml: _FakeScriptsYaml('/scripts.yaml', variables: {
            'cwd': 'bar',
          }),
          cwd: _FakeCWD('/'),
        );

        final populated = variables.populate();

        expect(populated['cwd'], '/');
      });

      group('should resolve variable references when', () {
        test('references other variables', () {
          final variables = Variables(
            pubspecYaml: _FakePubspecYaml('/pubspec.yaml'),
            scriptsYaml: _FakeScriptsYaml('/scripts.yaml', variables: {
              'foo': '{bar}',
              'bar': 'baz',
            }),
            cwd: _FakeCWD('/'),
          );

          final populated = variables.populate();

          expect(populated['foo'], 'baz');
        });

        test('contains multi-nested references', () {
          final variables = Variables(
            pubspecYaml: _FakePubspecYaml('/pubspec.yaml'),
            scriptsYaml: _FakeScriptsYaml('/scripts.yaml', variables: {
              'foo': '{bar}',
              'bar': '{baz}',
              'baz': 'loz',
            }),
            cwd: _FakeCWD('/'),
          );

          final populated = variables.populate();

          expect(populated['foo'], 'loz');
        });
      });

      group('should ignore variables', () {
        test('that are flags or options', () {
          final variables = Variables(
            pubspecYaml: _FakePubspecYaml('/pubspec.yaml'),
            scriptsYaml: _FakeScriptsYaml('/scripts.yaml', variables: {
              'foo': 'dart test {--coverage}',
            }),
            cwd: _FakeCWD('/'),
          );

          final populated = variables.populate();

          expect(populated['foo'], 'dart test {--coverage}');
        });
      });

      group('should remove variable when', () {
        test('circular reference is found', () {
          final variables = Variables(
            pubspecYaml: _FakePubspecYaml('/pubspec.yaml'),
            scriptsYaml: _FakeScriptsYaml('/scripts.yaml', variables: {
              'foo': '{bar}',
              'bar': '{foo}',
            }),
            cwd: _FakeCWD('/'),
          );

          final populated = variables.populate();

          expect(populated['foo'], isNull);
          expect(populated['bar'], isNull);
        });

        test('circular reference is found in nested', () {
          final variables = Variables(
            pubspecYaml: _FakePubspecYaml('/pubspec.yaml'),
            scriptsYaml: _FakeScriptsYaml('/scripts.yaml', variables: {
              'foo': '{bar}',
              'bar': '{baz}',
              'baz': '{bar}',
            }),
            cwd: _FakeCWD('/'),
          );

          final populated = variables.populate();

          expect(populated['foo'], isNull);
          expect(populated['bar'], isNull);
        });

        test('reference to script is found', () {
          final variables = Variables(
            pubspecYaml: _FakePubspecYaml('/pubspec.yaml'),
            scriptsYaml: _FakeScriptsYaml('/scripts.yaml', variables: {
              'foo': r'{$bar}',
            }),
            cwd: _FakeCWD('/'),
          );

          final populated = variables.populate();

          expect(populated['foo'], isNull);
        });
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
            name: 'dirs',
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

        test('throws when not found', () {
          final script = Script.defaults(
            name: 'lint',
            commands: [
              r'{$lint:dart}',
            ],
            scripts: ScriptsConfig(scripts: {
              '_dart': Script.defaults(
                name: '_dart',
                commands: [
                  'dart analyze .',
                ],
              ),
            }),
          );

          final config = ScriptsConfig(scripts: {'lint': script});

          expect(
            () => variables.replace(script, config),
            throwsA(isA<Exception>()),
          );
        });

        test('should replace when found', () {
          final script = Script.defaults(
            name: 'link',
            commands: [
              r'cd {projectRoot}/packages/application && {$build_runner:build}',
            ],
          );

          final config = ScriptsConfig(scripts: {
            'link': script,
            'build_runner': Script.defaults(
              name: 'build_runner',
              scripts: ScriptsConfig(
                scripts: {
                  'build': Script.defaults(
                    name: 'build',
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

        test('should duplicate commands when script has multiple commands', () {
          final script = Script.defaults(
            name: 'link',
            commands: [
              r'cd {projectRoot}/packages/application && {$build_runner:build}',
            ],
          );

          final config = ScriptsConfig(scripts: {
            'link': script,
            'build_runner': Script.defaults(
              name: 'build_runner',
              scripts: ScriptsConfig(
                scripts: {
                  'build': Script.defaults(
                    name: 'build',
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
            name: 'link',
            commands: [
              r'cd {projectRoot}/packages/application && {$build_runner:watch}',
            ],
          );

          final config = ScriptsConfig(scripts: {
            'link': script,
            'build_runner': Script.defaults(
              name: 'build_runner',
              scripts: ScriptsConfig(
                scripts: {
                  'clean': Script.defaults(
                    name: 'clean',
                    commands: [
                      'dart run build_runner clean',
                    ],
                  ),
                  'watch': Script.defaults(
                    name: 'watch',
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
            name: 'foo',
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
            name: 'foo',
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
            name: 'foo',
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
