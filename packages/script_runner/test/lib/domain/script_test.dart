import 'package:sip_script_runner/domain/script_env.dart';
import 'package:sip_script_runner/sip_script_runner.dart';
import 'package:test/test.dart';

void main() {
  group(Script, () {
    group('#listOut', () {
      test('should list out the description', () {
        const script = Script.defaults(
          name: 'script',
          description: 'This is a description',
        );

        expect(
          script.listOut(),
          equals(
            '''
(description): This is a description
''',
          ),
        );
      });

      test('should list out the aliases', () {
        const script = Script.defaults(
          name: 'script',
          aliases: {'alias1', 'alias2'},
        );

        expect(
          script.listOut(),
          equals(
            '''
(aliases): alias1, alias2
''',
          ),
        );
      });

      test('should list out the scripts', () {
        final script = Script.defaults(
          name: 'script',
          scripts: ScriptsConfig(
            scripts: const {
              'script1': Script.defaults(
                name: 'script1',
              ),
            },
          ),
        );

        expect(
          script.listOut(),
          startsWith('  └──script1'),
        );
      });

      test('should not list out the private script', () {
        final script = Script.defaults(
          name: '_',
          scripts: ScriptsConfig(
            scripts: const {
              'script1': Script.defaults(
                name: 'script1',
              ),
            },
          ),
        );

        expect(
          script.listOut(),
          equals(''),
        );
      });
    });

    group('serialization', () {
      group('parents', () {
        test('passes parents to children', () {
          final script = Script.fromJson(
            'script',
            const {
              'foo': {'bar': 'baz'},
            },
          );

          expect(script.parents, null);
          expect(script.scripts?.parents, ['script']);
          expect(script.scripts?.scripts['foo']?.parents, ['script']);
          expect(
            script.scripts?.scripts['foo']?.scripts?.parents,
            ['script', 'foo'],
          );
          expect(
            script.scripts?.scripts['foo']?.scripts?.scripts['bar']?.parents,
            ['script', 'foo'],
          );
        });
      });

      group('bail', () {
        test('can parse truthy', () {
          final scripts = [
            Script.fromJson(
              'script',
              const {Keys.bail: true},
            ),
            Script.fromJson(
              'script',
              const {Keys.bail: 'true'},
            ),
            Script.fromJson(
              'script',
              const {Keys.bail: 'yes'},
            ),
            Script.fromJson(
              'script',
              const {Keys.bail: 'y'},
            ),
            Script.fromJson(
              'script',
              const {Keys.bail: null},
            ),
          ];

          for (final script in scripts) {
            expect(script.bail, isTrue);
          }
        });

        test('can parse falsy', () {
          final scripts = [
            Script.fromJson(
              'script',
              const {Keys.bail: false},
            ),
            Script.fromJson(
              'script',
              const {Keys.bail: 'false'},
            ),
            Script.fromJson(
              'script',
              const {Keys.bail: 'anything else'},
            ),
            Script.fromJson(
              'script',
              const <String, dynamic>{},
            ),
          ];

          for (final script in scripts) {
            expect(script.bail, isFalse);
          }
        });
      });

      group('env', () {
        test('can parse null', () {
          final script = Script.fromJson(
            'script',
            const {
              Keys.env: null,
            },
          );

          expect(script.env, isNull);
        });

        test('can parse string', () {
          final script = Script.fromJson(
            'script',
            const {
              Keys.env: '.env',
            },
          );

          expect(script.env, isNotNull);
          expect(script.env, const ScriptEnv(file: '.env'));
        });

        group('can parse map', () {
          test('can parse normal input', () {
            final script = Script.fromJson(
              'script',
              const {
                Keys.env: {
                  'file': '.env',
                  'command': 'command',
                },
              },
            );

            expect(script.env, isNotNull);
            expect(
              script.env,
              const ScriptEnv(file: '.env', command: ['command']),
            );
          });

          test('can parse when command is not present', () {
            final script = Script.fromJson(
              'script',
              const {
                Keys.env: {
                  'file': '.env',
                },
              },
            );

            expect(script.env, isNotNull);
            expect(
              script.env,
              const ScriptEnv(file: '.env'),
            );
          });

          test('can parse when command is null', () {
            final script = Script.fromJson(
              'script',
              const {
                Keys.env: {
                  'file': '.env',
                  'command': null,
                },
              },
            );

            expect(script.env, isNotNull);
            expect(
              script.env,
              const ScriptEnv(file: '.env'),
            );
          });

          test('can parse when command list', () {
            final script = Script.fromJson(
              'script',
              const {
                Keys.env: {
                  'file': '.env',
                  'command': ['command'],
                },
              },
            );

            expect(script.env, isNotNull);
            expect(
              script.env,
              const ScriptEnv(file: '.env', command: ['command']),
            );
          });
        });
      });

      group('aliases', () {
        test('can parse string', () {
          final script = Script.fromJson(
            'script',
            const {
              Keys.aliases: 'alias1',
            },
          );

          expect(script.aliases, equals({'alias1'}));
        });

        test('can parse list', () {
          final script = Script.fromJson(
            'script',
            const {
              Keys.aliases: ['alias1', 'alias2'],
            },
          );

          expect(script.aliases, equals({'alias1', 'alias2'}));
        });

        test('can parse null', () {
          final script = Script.fromJson(
            'script',
            const {
              Keys.aliases: null,
            },
          );

          expect(script.aliases, equals([]));
        });

        test('can parse non-strings', () {
          final script = Script.fromJson(
            'script',
            const {
              Keys.aliases: [1, true],
            },
          );

          expect(script.aliases, equals(['1', 'true']));
        });

        test('does not parse maps', () {
          final script = Script.fromJson(
            'script',
            const {
              Keys.aliases: [
                {'key': 'value'},
              ],
            },
          );

          expect(script.aliases, equals([]));
        });
      });
    });
  });
}
