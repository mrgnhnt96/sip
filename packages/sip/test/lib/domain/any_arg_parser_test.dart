import 'package:sip_cli/domain/any_arg_parser.dart';
import 'package:test/test.dart';

void main() {
  group('$AnyArgParser', () {
    test('should add flag', () {
      final argParser = AnyArgParser();
      argParser.addFlag('flag');
      expect(argParser.options, contains('flag'));
    });

    test('should parse flag', () {
      final argParser = AnyArgParser();
      argParser.addFlag('flag');
      final result = argParser.parse(['--flag']);
      expect(result['flag'], isTrue);
    });

    test('should parse no flag', () {
      final argParser = AnyArgParser();
      final result = argParser.parse(['flag']);

      expect(result.rest, ['flag']);
    });

    test('should parse any flag', () {
      final argParser = AnyArgParser();
      final result = argParser.parse(['--flag', '-c']);
      expect(
        () => result['flag'],
        throwsA(isA<ArgumentError>()),
      );

      expect(result.rest, ['--flag', '-c']);
    });

    group('should parse any flag with value', () {
      test('when separated by space', () {
        final argParser = AnyArgParser();
        final result = argParser.parse(['--flag']);
        expect(
          () => result['flag'],
          throwsA(isA<ArgumentError>()),
        );

        expect(result.rest, contains('--flag'));
      });

      test('when separated by equal sign', () {
        final argParser = AnyArgParser();
        final result = argParser.parse(['--flag=value']);
        expect(
          () => result['flag'],
          throwsA(isA<ArgumentError>()),
        );

        expect(result.rest, contains('--flag=value'));
      });
    });

    group('should parse actual flag after any flag', () {
      test('(1)', () {
        final argParser = AnyArgParser();
        argParser.addFlag('flag');
        final result = argParser.parse(['--something', 'banana', '--flag']);

        expect(result['flag'], isTrue);

        expect(result.rest, ['--something', 'banana']);
      });

      test('(2)', () {
        final argParser = AnyArgParser();
        argParser.addFlag('list');
        argParser.addFlag('bail');
        final result =
            argParser.parse(['try', '--platform', 'banana', '--bail']);

        expect(result['bail'], isTrue);

        expect(result.rest, ['try', '--platform', 'banana']);
      });
    });
  });
}
