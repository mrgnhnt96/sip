import 'package:sip_script_runner/domain/script.dart';
import 'package:sip_script_runner/domain/scripts_config.dart';
import 'package:sip_script_runner/utils/constants.dart';
import 'package:test/test.dart';

void main() {
  group('$ScriptsConfig', () {
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
                scripts: ScriptsConfig(
                  scripts: {
                    'nested': const Script.defaults(
                      commands: ['echo "test"'],
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
              Keys.scripts: 'echo "test"',
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
              aliases: {'test'},
              description: 'this is a test',
              commands: ['echo "test"'],
              scripts: ScriptsConfig(
                scripts: {
                  'test2': const Script.defaults(
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
              Keys.scripts: null,
            },
          });

          expect(
            config.scripts,
            {
              'test': const Script.defaults(
                commands: [],
              ),
            },
          );
        });

        test('can parse string script', () {
          final config = ScriptsConfig.fromJson({
            'test': {
              Keys.scripts: 'echo "test"',
            },
          });

          expect(
            config.scripts,
            {
              'test': const Script.defaults(
                commands: ['echo "test"'],
              ),
            },
          );
        });

        test('can parse list string script', () {
          final config = ScriptsConfig.fromJson({
            'test': {
              Keys.scripts: [
                'echo "test"',
                'echo "test2"',
              ],
            },
          });

          expect(
            config.scripts,
            {
              'test': const Script.defaults(
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
    });
  });

  group('#find', () {
    test('can find script by name or alias', () {
      final commands = ['echo "banana"'];
      final config = ScriptsConfig(scripts: {
        'banana': Script.defaults(
          aliases: {'b', 'ban'},
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
          scripts: ScriptsConfig(
            scripts: {
              'bottom': const Script.defaults(
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
          commands: commands,
          scripts: ScriptsConfig(
            scripts: {
              'bottom': const Script.defaults(
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
}
