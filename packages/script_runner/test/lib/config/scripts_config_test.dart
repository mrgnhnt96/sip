import 'package:sip_script_runner/config/script.dart';
import 'package:sip_script_runner/config/scripts_config.dart';
import 'package:sip_script_runner/utils/constants.dart';
import 'package:test/test.dart';

void main() {
  group('$ScriptsConfig', () {
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
            'test': const Script.defaults(
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

      test('can parse string and ignores other entries', () {
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
        expect(first.commands, ['echo "test"']);
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
}
