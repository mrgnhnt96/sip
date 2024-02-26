import 'package:sip_script_runner/sip_script_runner.dart';
import 'package:sip_script_runner/utils/constants.dart';
import 'package:test/test.dart';

void main() {
  group('$Script', () {
    group('#listOut', () {
      test('should list out the description', () {
        final script = Script.defaults(
          name: 'script',
          description: 'This is a description',
        );

        expect(
          script.listOut(),
          equals(
            '''(description): This is a description
''',
          ),
        );
      });

      test('should list out the aliases', () {
        final script = Script.defaults(
          name: 'script',
          aliases: {'alias1', 'alias2'},
        );

        expect(
          script.listOut(),
          equals(
            '''(aliases): alias1, alias2
''',
          ),
        );
      });

      test('should list out the scripts', () {
        final script = Script.defaults(
          name: 'script',
          scripts: ScriptsConfig(
            scripts: {
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
            scripts: {
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
      group('concurrent', () {
        test('when script is string', () {
          final _ = Script.fromJson(
            'script',
            {
              'foo': {Keys.concurrent: 'echo "hello"'},
            },
          );

          // we will need to update the type for the command to be a list
          // of Commands which will contain a string (the command) and a
          // boolean (whether it is concurrent or not)
          expect(true, isFalse);
        });

        test('when script is list', () {
          final _ = Script.fromJson(
            'script',
            {
              'foo': {
                Keys.concurrent: ['echo "hello"']
              },
            },
          );

          expect(true, isFalse);
        });

        test('when found in list of scripts', () {
          final _ = Script.fromJson(
            'script',
            {
              'foo': [
                'echo "hello"',
                {Keys.concurrent: 'echo "world"'},
                'echo "goodbye"'
              ]
            },
          );

          expect(true, isFalse);
        });
      });

      group('parents', () {
        test('passes parents to children', () {
          final script = Script.fromJson(
            'script',
            {
              'foo': {'bar': 'baz'}
            },
          );

          expect(script.parents, null);
          expect(script.scripts?.parents, ['script']);
          expect(script.scripts?.scripts['foo']?.parents, ['script']);
          expect(script.scripts?.scripts['foo']?.scripts?.parents,
              ['script', 'foo']);
          expect(
              script.scripts?.scripts['foo']?.scripts?.scripts['bar']?.parents,
              ['script', 'foo']);
        });
      });

      group('bail', () {
        test('can parse truthy', () {
          final scripts = [
            Script.fromJson(
              'script',
              {Keys.bail: true},
            ),
            Script.fromJson(
              'script',
              {Keys.bail: 'true'},
            ),
            Script.fromJson(
              'script',
              {Keys.bail: 'yes'},
            ),
            Script.fromJson(
              'script',
              {Keys.bail: 'y'},
            ),
            Script.fromJson(
              'script',
              {Keys.bail: null},
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
              {Keys.bail: false},
            ),
            Script.fromJson(
              'script',
              {Keys.bail: 'false'},
            ),
            Script.fromJson(
              'script',
              {Keys.bail: 'anything else'},
            ),
            Script.fromJson(
              'script',
              {},
            ),
          ];

          for (final script in scripts) {
            expect(script.bail, isFalse);
          }
        });
      });

      group('aliases', () {
        test('can parse string', () {
          final script = Script.fromJson(
            'script',
            {
              Keys.aliases: 'alias1',
            },
          );

          expect(script.aliases, equals({'alias1'}));
        });

        test('can parse list', () {
          final script = Script.fromJson(
            'script',
            {
              Keys.aliases: ['alias1', 'alias2'],
            },
          );

          expect(script.aliases, equals({'alias1', 'alias2'}));
        });

        test('can parse null', () {
          final script = Script.fromJson(
            'script',
            {
              Keys.aliases: null,
            },
          );

          expect(script.aliases, equals([]));
        });
      });
    });
  });
}
