import 'package:sip_cli/src/domain/script.dart';
import 'package:sip_cli/src/domain/scripts_config.dart';
import 'package:test/test.dart';

void main() {
  group(ScriptsConfig, () {
    group('#search', () {
      test('returns a script by name', () {
        final script = Script(name: 'foo', commands: ['echo foo']);

        final config = ScriptsConfig({script.name: script});

        final result = config.search('foo');

        expect(result, hasLength(1));
        expect(result.single, script);
      });

      test('can find nested script', () {
        final script = Script(name: 'foo', commands: ['echo foo']);

        final config = ScriptsConfig({
          'bar': Script(name: 'bar', scripts: {script.name: script}),
        });

        final result = config.search('foo');

        expect(result, hasLength(1));
        expect(result.single, script);
      });

      test('can find multiple scripts', () {
        final script1 = Script(name: 'foo-bar-baz', commands: ['echo foo']);
        final script2 = Script(name: 'bar-foo-baz', commands: ['echo foo']);

        final config = ScriptsConfig({
          script1.name: script1,
          'bar': Script(name: 'bar', scripts: {script2.name: script2}),
        });

        final result = config.search('foo').toList();

        expect(result, hasLength(2));
        expect(result, [script1, script2]);
      });

      test('stops search when parent is found', () {
        final script = Script(
          name: 'foo-bar-baz',
          commands: const ['echo foo'],
          scripts: {
            'foo': Script(name: '2', commands: ['echo foo']),
          },
        );

        final config = ScriptsConfig({script.name: script});

        final result = config.search('foo').toList();

        expect(result, hasLength(1));
        expect(result, [script]);
      });

      test('returns nothing when alias is not exact', () {
        final config = ScriptsConfig({
          'foo': Script(
            name: 'name',
            commands: ['echo foo'],
            aliases: {'loz-mm'},
          ),
        });

        final result = config.search('loz');

        expect(result, isEmpty);
      });

      test('returns nothing when no scripts are found', () {
        final script = Script(name: 'foo', commands: ['echo foo']);
        final config = ScriptsConfig({script.name: script});

        final result = config.search('bar');

        expect(result, isEmpty);
      });

      test('returns when alias matches', () {
        final script = Script(
          name: 'name',
          commands: ['echo foo'],
          aliases: {'loz-mm'},
        );

        final config = ScriptsConfig({script.name: script});

        final result = config.search('loz-mm');

        expect(result, hasLength(1));
        expect(result.single, script);
      });
    });
  });
}
