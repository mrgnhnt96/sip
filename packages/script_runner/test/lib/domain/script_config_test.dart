import 'package:sip_script_runner/sip_script_runner.dart';
import 'package:sip_script_runner/utils/constants.dart';
import 'package:test/test.dart';

void main() {
  group('$ScriptsConfig', () {
    group('#listOut', () {
      test('lists out the scripts', () {
        final scriptsConfig = ScriptsConfig(
          scripts: {
            'legend-of-zelda': Script.defaults(
              name: 'legend-of-zelda',
              aliases: {'loz', 'legend', 'zelda'},
              description: 'The Legend of Zelda Games',
              commands: ['echo "Pick a game..."'],
              scripts: ScriptsConfig(
                scripts: {
                  'ocarina-of-time': Script.defaults(
                    name: 'ocarina-of-time',
                    description: 'Ocarina of Time',
                    aliases: {'oot'},
                    commands: ['echo "Now loading Ocarina of Time..."'],
                  ),
                  'majoras-mask': Script.defaults(
                    name: 'majoras-mask',
                    aliases: {'mm'},
                    description: "Majora's Mask",
                    commands: ['echo "Now loading Majora\'s Mask..."'],
                  ),
                },
              ),
            ),
            'mario': Script.defaults(
              name: 'mario',
              aliases: {'super-mario', 'super-mario-bros'},
              description: 'The Super Mario Bros Games',
              commands: ['echo "Pick a game..."'],
              scripts: ScriptsConfig(
                scripts: {
                  'super-mario-bros': Script.defaults(
                    name: 'super-mario-bros',
                    description: 'Super Mario Bros',
                    aliases: {'smb'},
                    commands: ['echo "Now loading Super Mario Bros..."'],
                  ),
                  'super-mario-world': Script.defaults(
                    name: 'super-mario-world',
                    description: 'Super Mario World',
                    aliases: {'smw'},
                    commands: ['echo "Now loading Super Mario World..."'],
                  ),
                },
              ),
            ),
          },
        );

        const expected = '''
scripts.yaml:
   ├──legend-of-zelda
   │  (description): The Legend of Zelda Games
   │  (aliases): loz, legend, zelda
   │    ├──ocarina-of-time
   │    │  (description): Ocarina of Time
   │    │  (aliases): oot
   │    └──majoras-mask
   │       (description): Majora's Mask
   │       (aliases): mm
   └──mario
      (description): The Super Mario Bros Games
      (aliases): super-mario, super-mario-bros
        ├──super-mario-bros
        │  (description): Super Mario Bros
        │  (aliases): smb
        └──super-mario-world
           (description): Super Mario World
           (aliases): smw
''';

        expect(
          scriptsConfig.listOut(),
          expected.trimLeft(),
        );
      });
    });

    group('serialization', () {
      group('can parse', () {
        test('can parse empty config', () {
          final config = ScriptsConfig.fromJson({});
          expect(config.scripts, isEmpty);
        });

        test('can parse string command', () {
          final config = ScriptsConfig.fromJson({
            'test': 'echo "test"',
          });

          expect(
            config.scripts,
            {
              'test': const Script.defaults(
                commands: ['echo "test"'],
                name: 'test',
              ),
            },
          );
        });

        test('can parse list string command', () {
          final config = ScriptsConfig.fromJson({
            'test': [
              'echo "test"',
              'echo "test2"',
            ],
          });

          expect(
            config.scripts,
            {
              'test': const Script.defaults(
                commands: [
                  'echo "test"',
                  'echo "test2"',
                ],
                name: 'test',
              ),
            },
          );
        });

        group('nested', () {
          test('can parse string', () {
            final config = ScriptsConfig.fromJson({
              'test': {
                'nested': 'echo "test"',
              },
            });

            expect(
              config.scripts,
              {
                'test': Script.defaults(
                  name: 'test',
                  scripts: ScriptsConfig(
                    scripts: {
                      'nested': const Script.defaults(
                        commands: ['echo "test"'],
                        name: 'nested',
                      ),
                    },
                  ),
                ),
              },
            );
          });

          test('can parse string with other entries', () {
            final config = ScriptsConfig.fromJson({
              'test': {
                Keys.command: 'echo "test"',
                Keys.description: 'this is a test',
                Keys.aliases: ['test'],
                'test2': 'echo "test2"',
              },
            });

            expect(config.scripts, hasLength(1));
            expect(config.scripts.keys, ['test']);

            final first = config.scripts.values.first;
            expect(
              first,
              Script.defaults(
                name: 'test',
                aliases: {'test'},
                description: 'this is a test',
                commands: ['echo "test"'],
                scripts: ScriptsConfig(
                  scripts: {
                    'test2': const Script.defaults(
                      name: 'test2',
                      commands: ['echo "test2"'],
                    ),
                  },
                ),
              ),
            );
          });
        });

        group('using alternate key', () {
          test('can parse empty script', () {
            final config = ScriptsConfig.fromJson({
              'test': {
                Keys.command: null,
              },
            });

            expect(
              config.scripts,
              {
                'test': const Script.defaults(
                  name: 'test',
                  commands: [],
                ),
              },
            );
          });

          test('can parse string script', () {
            final config = ScriptsConfig.fromJson({
              'test': {
                Keys.command: 'echo "test"',
              },
            });

            expect(
              config.scripts,
              {
                'test': const Script.defaults(
                  commands: ['echo "test"'],
                  name: 'test',
                ),
              },
            );
          });

          test('can parse list string script', () {
            final config = ScriptsConfig.fromJson({
              'test': {
                Keys.command: [
                  'echo "test"',
                  'echo "test2"',
                ],
              },
            });

            expect(
              config.scripts,
              {
                'test': const Script.defaults(
                  name: 'test',
                  commands: [
                    'echo "test"',
                    'echo "test2"',
                  ],
                ),
              },
            );
          });
        });
      });

      group('skips entry when', () {
        test('key contains spaces', () {
          final config = ScriptsConfig.fromJson({
            'test test': 'echo "test"',
          });

          expect(config.scripts, isEmpty);
        });

        test('key that use parenthesis', () {
          final config = ScriptsConfig.fromJson({
            '(test)': 'echo "test"',
            'test)': 'echo "test"',
            '(test': 'echo "test"',
          });

          expect(config.scripts, isEmpty);
        });

        test('keys that use forbidden characters', () {
          final config = ScriptsConfig.fromJson({
            'test!': 'echo "test"',
            'test@': 'echo "test"',
            'test#': 'echo "test"',
            'test\$': 'echo "test"',
            'test%': 'echo "test"',
            'test^': 'echo "test"',
            'test&': 'echo "test"',
            'test*': 'echo "test"',
            'test(': 'echo "test"',
            'test)': 'echo "test"',
          });

          expect(config.scripts, isEmpty);
        });
      });
    });

    group('#find', () {
      test('can find script by name or alias', () {
        final commands = ['echo "banana"'];
        final config = ScriptsConfig(scripts: {
          'banana': Script.defaults(
            aliases: {'b', 'ban'},
            name: 'banana',
            commands: commands,
          ),
        });

        final b = config.find(['b']);
        expect(b, isNotNull);
        expect(b!.commands, commands);

        final ban = config.find(['ban']);
        expect(ban, isNotNull);
        expect(ban!.commands, commands);

        final banana = config.find(['banana']);
        expect(banana, isNotNull);
        expect(banana!.commands, commands);

        final other = config.find(['other']);
        expect(other, isNull);
      });

      test('finds nested script', () {
        const commands = ['echo "patrick"'];
        final config = ScriptsConfig(scripts: {
          'bikini': Script.defaults(
            name: 'bikini',
            scripts: ScriptsConfig(
              scripts: {
                'bottom': const Script.defaults(
                  name: 'bottom',
                  commands: commands,
                ),
              },
            ),
          ),
        });

        final script = config.find(['bikini', 'bottom']);

        expect(script, isNotNull);
        expect(script!.commands, commands);
      });

      test('finds script when nested scripts exist', () {
        const commands = ['echo "patrick"'];

        final config = ScriptsConfig(scripts: {
          'bikini': Script.defaults(
            name: 'bikini',
            commands: commands,
            scripts: ScriptsConfig(
              scripts: {
                'bottom': const Script.defaults(
                  name: 'bottom',
                  commands: ['echo "bottom"'],
                ),
              },
            ),
          ),
        });

        final script = config.find(['bikini']);

        expect(script, isNotNull);
        expect(script!.commands, commands);
      });
    });
  });
}
