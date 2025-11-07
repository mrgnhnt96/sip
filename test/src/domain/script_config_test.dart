import 'package:sip_cli/src/domain/script.dart';
import 'package:sip_cli/src/domain/scripts_config.dart';
import 'package:test/test.dart';

void main() {
  group(ScriptsConfig, () {
    group('#search', () {
      test('returns a script by name', () {
        const script = Script.defaults(name: 'foo', commands: ['echo foo']);

        final config = ScriptsConfig(scripts: {script.name: script});

        final result = config.search('foo');

        expect(result, hasLength(1));
        expect(result.single, script);
      });

      test('can find nested script', () {
        const script = Script.defaults(name: 'foo', commands: ['echo foo']);

        final config = ScriptsConfig(
          scripts: {
            'bar': Script.defaults(
              name: 'bar',
              scripts: ScriptsConfig(scripts: {script.name: script}),
            ),
          },
        );

        final result = config.search('foo');

        expect(result, hasLength(1));
        expect(result.single, script);
      });

      test('can find multiple scripts', () {
        const script1 = Script.defaults(
          name: 'foo-bar-baz',
          commands: ['echo foo'],
        );
        const script2 = Script.defaults(
          name: 'bar-foo-baz',
          commands: ['echo foo'],
        );

        final config = ScriptsConfig(
          scripts: {
            script1.name: script1,
            'bar': Script.defaults(
              name: 'bar',
              scripts: ScriptsConfig(scripts: {script2.name: script2}),
            ),
          },
        );

        final result = config.search('foo').toList();

        expect(result, hasLength(2));
        expect(result, [script1, script2]);
      });

      test('stops search when parent is found', () {
        final script = Script.defaults(
          name: 'foo-bar-baz',
          commands: const ['echo foo'],
          scripts: ScriptsConfig(
            scripts: const {
              'foo': Script.defaults(name: '2', commands: ['echo foo']),
            },
          ),
        );

        final config = ScriptsConfig(scripts: {script.name: script});

        final result = config.search('foo').toList();

        expect(result, hasLength(1));
        expect(result, [script]);
      });

      test('returns nothing when alias is not exact', () {
        final config = ScriptsConfig(
          scripts: const {
            'foo': Script.defaults(
              name: 'name',
              commands: ['echo foo'],
              aliases: {'loz-mm'},
            ),
          },
        );

        final result = config.search('loz');

        expect(result, isEmpty);
      });

      test('returns nothing when no scripts are found', () {
        const script = Script.defaults(name: 'foo', commands: ['echo foo']);
        final config = ScriptsConfig(scripts: {script.name: script});

        final result = config.search('bar');

        expect(result, isEmpty);
      });

      test('returns when alias matches', () {
        const script = Script.defaults(
          name: 'name',
          commands: ['echo foo'],
          aliases: {'loz-mm'},
        );

        final config = ScriptsConfig(scripts: {script.name: script});

        final result = config.search('loz-mm');

        expect(result, hasLength(1));
        expect(result.single, script);
      });
    });
  });
}
