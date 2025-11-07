import 'package:args/args.dart';
import 'package:sip_cli/domain/any_arg_parser.dart';
import 'package:test/test.dart';

void main() {
  group(AnyArgParser, () {
    test('should add flag', () {
      final argParser = AnyArgParser()..addFlag('flag');
      expect(argParser.options, contains('flag'));
    });

    test('should parse flag', () {
      final argParser = AnyArgParser()..addFlag('flag');
      final result = argParser.parse(['--flag']);
      expect(result['flag'], isTrue);
    });

    test('should parse no flag', () {
      final argParser = AnyArgParser();
      final result = argParser.parse(['flag']);

      expect(result.rest, ['flag']);
    });

    test('should parse extra flags', () {
      final argParser = AnyArgParser();
      final result = argParser.parse(['--flag', '-c']);
      expect(() => result['flag'], throwsA(isA<ArgumentError>()));

      expect(result.rest, ['--flag', '-c']);
    });

    test('should parse extra short flags', () {
      final argParser = AnyArgParser();
      final result = argParser.parse(['-f', '-c', '-de']);
      expect(() => result['f'], throwsA(isA<ArgumentError>()));

      expect(result.rest, ['-f', '-c', '-d', '-e']);
    });

    test('should parse extra short flags with values', () {
      final argParser = AnyArgParser();
      final result = argParser.parse(['-f', '-c', '-de', 'hello']);
      expect(() => result['f'], throwsA(isA<ArgumentError>()));

      expect(result.rest, ['-f', '-c', '-d', '-e', 'hello']);
    });

    group('should parse any flag with value', () {
      test('when separated by space', () {
        final argParser = AnyArgParser();
        final result = argParser.parse(['--flag']);
        expect(() => result['flag'], throwsA(isA<ArgumentError>()));

        expect(result.rest, contains('--flag'));
      });

      test('when separated by equal sign', () {
        final argParser = AnyArgParser();
        final result = argParser.parse(['--flag=value']);
        expect(() => result['flag'], throwsA(isA<ArgumentError>()));

        expect(result.rest, contains('--flag=value'));
      });
    });

    group('should parse actual flag after any flag', () {
      test('(1)', () {
        final argParser = AnyArgParser()..addFlag('flag');
        final result = argParser.parse(['--something', 'banana', '--flag']);

        expect(result['flag'], isTrue);

        expect(result.rest, ['--something', 'banana']);
      });

      test('(2)', () {
        final argParser = AnyArgParser()
          ..addFlag('list')
          ..addFlag('bail');
        final result = argParser.parse([
          'try',
          '--platform',
          'banana',
          '--bail',
        ]);

        expect(result['bail'], isTrue);

        expect(result.rest, ['try', '--platform', 'banana']);
      });
    });

    group('#inject', () {
      test('should inject flag', () {
        final argParser = ArgParser()..addFlag('flag');
        final flag = argParser.findByNameOrAlias('flag');

        expect(flag, isNotNull);

        final anyArgParser = AnyArgParser()..inject(flag!);

        expect(anyArgParser.options, contains('flag'));
      });

      test('should copy all the options', () {
        final argParser = ArgParser()
          ..addFlag('flag')
          ..addOption('option', abbr: 'o', defaultsTo: 'default')
          ..addMultiOption('multi-option', abbr: 'm', defaultsTo: ['default']);
        final flag = argParser.findByNameOrAlias('flag');
        final option = argParser.findByNameOrAlias('option');
        final multiOption = argParser.findByNameOrAlias('multi-option');

        expect(flag, isNotNull);
        expect(option, isNotNull);
        expect(multiOption, isNotNull);

        final anyArgParser = AnyArgParser()
          ..inject(flag!)
          ..inject(option!)
          ..inject(multiOption!);

        expect(anyArgParser.options, contains('flag'));
        expect(anyArgParser.options, contains('option'));
        expect(anyArgParser.options, contains('multi-option'));
      });

      test('should copy all the options values', () {
        final argParser = ArgParser()
          ..addFlag(
            'flag',
            abbr: 'f',
            defaultsTo: true,
            aliases: ['1'],
            help: 'help',
            hide: true,
            negatable: false,
          )
          ..addOption(
            'option',
            abbr: 'o',
            defaultsTo: 'default',
            allowed: ['default', 'other'],
            help: 'help',
            hide: true,
            valueHelp: 'valueHelp',
            aliases: ['2'],
            allowedHelp: {'default': 'defaultHelp', 'other': 'otherHelp'},
          )
          ..addMultiOption(
            'multi-option',
            abbr: 'm',
            defaultsTo: ['default'],
            allowed: ['default', 'other'],
            help: 'help',
            hide: true,
            aliases: ['3'],
            allowedHelp: {'default': 'defaultHelp', 'other': 'otherHelp'},
            splitCommas: false,
            valueHelp: 'valueHelp',
          );
        final flag = argParser.findByNameOrAlias('flag');
        final option = argParser.findByNameOrAlias('option');
        final multiOption = argParser.findByNameOrAlias('multi-option');

        expect(flag, isNotNull);
        expect(option, isNotNull);
        expect(multiOption, isNotNull);

        final anyArgParser = AnyArgParser()
          ..inject(flag!)
          ..inject(option!)
          ..inject(multiOption!);

        final anyFlag = anyArgParser.findByNameOrAlias('flag');
        final anyOption = anyArgParser.findByNameOrAlias('option');
        final anyMultiOption = anyArgParser.findByNameOrAlias('multi-option');

        expect(anyFlag, isNotNull);
        expect(anyOption, isNotNull);
        expect(anyMultiOption, isNotNull);

        expect(anyFlag!.defaultsTo, true);
        expect(anyOption!.defaultsTo, 'default');
        expect(anyMultiOption!.defaultsTo, ['default']);

        expect(anyFlag.abbr, 'f');
        expect(anyOption.abbr, 'o');
        expect(anyMultiOption.abbr, 'm');

        expect(anyFlag.aliases, ['1']);
        expect(anyOption.aliases, ['2']);
        expect(anyMultiOption.aliases, ['3']);

        expect(anyFlag.help, 'help');
        expect(anyOption.help, 'help');
        expect(anyMultiOption.help, 'help');

        expect(anyFlag.hide, isTrue);
        expect(anyOption.hide, isTrue);
        expect(anyMultiOption.hide, isTrue);

        expect(anyFlag.negatable, isFalse);
        expect(anyOption.negatable, isFalse);
        expect(anyMultiOption.negatable, isFalse);

        expect(anyFlag.valueHelp, isNull);
        expect(anyOption.valueHelp, 'valueHelp');
        expect(anyMultiOption.valueHelp, 'valueHelp');

        expect(anyOption.allowed, ['default', 'other']);
        expect(anyMultiOption.allowed, ['default', 'other']);

        expect(anyOption.allowedHelp, {
          'default': 'defaultHelp',
          'other': 'otherHelp',
        });
        expect(anyMultiOption.allowedHelp, {
          'default': 'defaultHelp',
          'other': 'otherHelp',
        });

        expect(anyMultiOption.splitCommas, isFalse);
      });
    });
  });
}
