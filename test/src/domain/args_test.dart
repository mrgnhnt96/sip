import 'package:sip_cli/src/domain/args.dart';
import 'package:test/test.dart';

void main() {
  group(Args, () {
    group('#parse', () {
      test('should parse values', () {
        final args = Args.parse(['--flag']);

        expect(args.values, {'flag': true});
      });

      test('should parse negated values', () {
        final args = Args.parse(['--no-flag']);

        expect(args.values, {'flag': false});
      });

      test('should parse options using =', () {
        final args = Args.parse(['--key=value']);

        expect(args.values, {'key': 'value'});
      });

      test('should parse options as separate arguments', () {
        final args = Args.parse(['--key', 'value']);

        expect(args.values, {'key': 'value'});
      });

      test('should parse multi options with values', () {
        final args = Args.parse(['--key=value1', '--key', 'value2']);

        expect(args.values, {
          'key': ['value1', 'value2'],
        });
      });

      test('should promote types', () {
        final args = Args.parse([
          '--one=1',
          '--two',
          'false',
          '--three',
          'true',
          '--four',
          'null',
          '--five',
          '1.0',
        ]);

        expect(args.values, {
          'one': 1,
          'two': false,
          'three': true,
          'four': null,
          'five': 1.0,
        });
      });

      test('should parse rest', () {
        final args = Args.parse(['--key=value', 'rest1', 'rest2']);

        expect(args.rest, ['rest1', 'rest2']);
      });

      test('should remove double quotes from values', () {
        final args = Args.parse(['--key="value"']);

        expect(args.values, {'key': 'value'});
      });

      test('should remove single quotes from values', () {
        final args = Args.parse(["--key='value'"]);

        expect(args.values, {'key': 'value'});
      });

      test('should parse path', () {
        final args = Args.parse([
          'some',
          'command',
          '--flag',
          '--option=value',
          'rest1',
          'rest2',
        ]);

        expect(args.path, ['some', 'command']);
        expect(args.flags, {'flag': true});
        expect(args.values, {'flag': true, 'option': 'value'});
        expect(args.rest, ['rest1', 'rest2']);
      });

      group('abbr', () {
        test('should parse abbrs', () {
          final args = Args.parse(['-abc']);

          expect(args.abbrs, {'a': true, 'b': true, 'c': true});
        });

        test('abbr can be followed by a value', () {
          final args = Args.parse(['-a', 'value']);

          expect(args.abbrs, {'a': 'value'});
        });

        test('multi abbrs can be followed by a value', () {
          final args = Args.parse(['-abc', 'value']);

          expect(args.abbrs, {'a': true, 'b': true, 'c': 'value'});
        });

        test('abbr can be followed with a =', () {
          final args = Args.parse(['-a=value']);

          expect(args.abbrs, {'a': 'value'});
        });

        test('abbr can be followed by a flag', () {
          final args = Args.parse(['-a', '--flag']);

          expect(args.flags, {'flag': true});
          expect(args.abbrs, {'a': true});
        });
      });
    });

    group('#getOrNull', () {
      test('should return null if the key was not parsed', () {
        final args = Args.parse(['--flag']);

        expect(args.getOrNull('key'), isNull);
      });

      test('should return the value if the key was parsed', () {
        final args = Args.parse(['--flag']);

        expect(args.getOrNull('flag'), isTrue);
      });

      test('should return the value if the key was parsed with an abbr', () {
        final args = Args.parse(['-f']);

        expect(args.getOrNull('flag', abbr: 'f'), isTrue);
      });

      test('should return the value if the key was parsed with an alias', () {
        final args = Args.parse(['--fg']);

        expect(args.getOrNull('flag', aliases: ['fg']), isTrue);
      });
    });

    group('#wasParsed', () {
      test('should return false if the key was not parsed', () {
        final args = Args.parse(['--flag']);

        expect(args.wasParsed('key'), isFalse);
      });

      test('should return the value if the key was parsed', () {
        final args = Args.parse(['--flag']);

        expect(args.wasParsed('flag'), isTrue);
      });

      test('should return the value if the key was parsed with an abbr', () {
        final args = Args.parse(['-f']);

        expect(args.wasParsed('flag', abbr: 'f'), isTrue);
      });

      test('should return the value if the key was parsed with an alias', () {
        final args = Args.parse(['--fg']);

        expect(args.wasParsed('flag', aliases: ['fg']), isTrue);
      });
    });
  });
}
