import 'package:args/args.dart';
import 'package:sip_cli/commands/test_command/tester_mixin.dart';
import 'package:test/test.dart';

void main() {
  group('#parseArguments', () {
    late ArgParser argParser;

    setUp(() {
      argParser = ArgParser();
    });

    ArgResults argResults([List<String> args = const []]) {
      return argParser.parse(args);
    }

    test('should include initial arguments', () {
      final result = parseArguments(
        argParser,
        argResults(),
        {},
        flagReplacements: {},
        initialArgs: {'--hi'},
      );

      expect(result, ['--hi']);
    });

    test('should remove empty arguments', () {
      final result = parseArguments(
        argParser,
        argResults(['', '']),
        {},
        flagReplacements: {},
        initialArgs: {},
      );

      expect(result, isEmpty);
    });

    group('when flag is provided in list', () {
      test('should add flag when arg is parsed', () {
        argParser.addFlag('hi');

        final result = parseArguments(
          argParser,
          argResults(['--hi']),
          {'hi'},
          flagReplacements: {},
          initialArgs: {},
        );

        expect(result, ['--hi']);
      });

      test('should add no-flag when arg is parsed', () {
        argParser.addFlag('hi');

        final result = parseArguments(
          argParser,
          argResults(['--no-hi']),
          {'hi'},
          flagReplacements: {},
          initialArgs: {},
        );

        expect(result, ['--no-hi']);
      });
    });

    group('when flag is not provided in list', () {
      test('should not add flag when arg is parsed', () {
        argParser.addFlag('hi');

        final result = parseArguments(
          argParser,
          argResults(['--hi']),
          {},
          flagReplacements: {},
          initialArgs: {},
        );

        expect(result, isEmpty);
      });

      test('should not add no-flag when arg is parsed', () {
        argParser.addFlag('hi');

        final result = parseArguments(
          argParser,
          argResults(['--no-hi']),
          {},
          flagReplacements: {},
          initialArgs: {},
        );

        expect(result, isEmpty);
      });
    });

    group('should forward values', () {
      test('when a single value is passed', () {
        argParser.addOption('hi');

        final result = parseArguments(
          argParser,
          argResults(['--hi', 'hello']),
          {'hi'},
          flagReplacements: {},
          initialArgs: {},
        );

        expect(result, ['--hi', 'hello']);
      });

      test('when a multiple values are passed', () {
        argParser.addMultiOption('hi');

        final result = parseArguments(
          argParser,
          argResults(['--hi', 'hello', '--hi', 'world']),
          {'hi'},
          flagReplacements: {},
          initialArgs: {},
        );

        expect(result, ['--hi', 'hello', 'world']);
      });
    });

    group('flagReplacements', () {
      test('should replace option with new option', () {
        argParser.addFlag('hi');

        final result = parseArguments(
          argParser,
          argResults(['--hi']),
          {'hi'},
          flagReplacements: {'hi': 'hello'},
          initialArgs: {},
        );

        expect(result, ['--hello']);
      });

      test('should ignore option if not in flagReplacements', () {
        argParser.addFlag('hi');

        final result = parseArguments(
          argParser,
          argResults(['--hi']),
          {'hi'},
          flagReplacements: {'hello': 'hi'},
          initialArgs: {},
        );

        expect(result, ['--hi']);
      });
    });
  });
}
