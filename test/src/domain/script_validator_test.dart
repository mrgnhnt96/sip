import 'package:sip_cli/src/domain/diagnostic.dart';
import 'package:sip_cli/src/domain/script.dart';
import 'package:sip_cli/src/domain/script_validator.dart';
import 'package:sip_cli/src/domain/scripts_config.dart';
import 'package:test/test.dart';

void main() {
  group('validateScripts', () {
    /// Builds the config the way `ScriptsConfig.load` does, minus the
    /// providers -- these tests are about the checks, not about file lookup.
    ScriptsConfig configFor(Map<String, dynamic> scripts) => ScriptsConfig({
      for (final MapEntry(:key, :value) in scripts.entries)
        key: Script.fromJson(key, value),
    });

    ValidationResult validate(
      String content, {
      Map<String, dynamic> scripts = const {},
      Set<String> variables = const {'projectRoot', 'dart', 'flutter'},
    }) => validateScripts(
      content: content,
      file: 'scripts.yaml',
      config: configFor(scripts),
      knownVariables: variables,
    );

    List<String> codes(ValidationResult result) =>
        result.diagnostics.map((e) => e.code).toList();

    Diagnostic only(ValidationResult result, String code) =>
        result.diagnostics.firstWhere(
          (e) => e.code == code,
          orElse: () => fail('no $code in ${codes(result)}'),
        );

    test('a correct file produces nothing', () {
      final result = validate(
        '''
format: dart format .
build:
  (command): echo build
  ui: echo ui
''',
        scripts: {
          'format': 'dart format .',
          'build': {'(command)': 'echo build', 'ui': 'echo ui'},
        },
      );

      expect(result.diagnostics, isEmpty);
      expect(result.hasErrors, isFalse);
      expect(result.isClean, isTrue);
    });

    test('flags a reference to a script that does not exist', () {
      final result = validate(
        r'a: echo ${{ nope }}',
        scripts: {'a': r'echo ${{ nope }}'},
      );

      final diagnostic = only(result, 'unknown-reference');
      expect(diagnostic.severity, Severity.error);
      expect(diagnostic.location?.line, 1);
      expect(diagnostic.script, 'a');
      expect(diagnostic.message, contains('nope'));
    });

    test('flags a colon reference, which is never substituted', () {
      // The documented footgun: `${{ a:b }}` does not match sip's pattern at
      // all, so it reaches the shell verbatim and fails with `bad
      // substitution`.
      final result = validate(
        r'a: echo ${{ b:c }}',
        scripts: {'a': r'echo ${{ b:c }}'},
      );

      final diagnostic = only(result, 'malformed-substitution');
      expect(diagnostic.severity, Severity.error);
      expect(diagnostic.help, contains(r'${{ b.c }}'));
    });

    test('flags a reference to a script with no command', () {
      final result = validate(
        r'''
a: echo ${{ group }}
group:
  child: echo child
''',
        scripts: {
          'a': r'echo ${{ group }}',
          'group': {'child': 'echo child'},
        },
      );

      expect(codes(result), contains('reference-has-no-command'));
    });

    test('accepts built-in variables, user variables and flags', () {
      final result = validate(
        r'a: echo ${{ projectRoot }} ${{ out }} ${{ --flag }}',
        scripts: {'a': r'echo ${{ projectRoot }} ${{ out }} ${{ --flag }}'},
        variables: {'projectRoot', 'out'},
      );

      expect(result.diagnostics, isEmpty);
    });

    test('flags an empty (bail), which sip reads as false', () {
      final result = validate(
        '''
a:
  (bail):
  (command): echo hi
''',
        scripts: {
          'a': {'(bail)': null, '(command)': 'echo hi'},
        },
      );

      final diagnostic = only(result, 'empty-bail');
      expect(diagnostic.severity, Severity.warning);
      expect(diagnostic.location?.line, 2);
      expect(diagnostic.help, contains('(bail): true'));
    });

    test('accepts an explicit (bail): true', () {
      final result = validate(
        '''
a:
  (bail): true
  (command): echo hi
''',
        scripts: {
          'a': {'(bail)': true, '(command)': 'echo hi'},
        },
      );

      expect(result.diagnostics, isEmpty);
    });

    test('flags a key that looks reserved but is not', () {
      final result = validate(
        '''
a:
  (descriptions): oops
  (command): echo hi
''',
        scripts: {
          'a': {'(command)': 'echo hi'},
        },
      );

      final diagnostic = only(result, 'unknown-reserved-key');
      expect(diagnostic.severity, Severity.warning);
      expect(diagnostic.location?.line, 2);
    });

    test('flags a script with nothing to run', () {
      final result = validate(
        '''
a:
  (aliases): [x]
''',
        scripts: {
          'a': {
            '(aliases)': <String>['x'],
          },
        },
      );

      expect(codes(result), contains('empty-script'));
    });

    test('flags an alias claimed by two scripts', () {
      final result = validate(
        '''
a:
  (aliases): [d]
  (command): echo a
b:
  (aliases): [d]
  (command): echo b
''',
        scripts: {
          'a': {
            '(aliases)': <String>['d'],
            '(command)': 'echo a',
          },
          'b': {
            '(aliases)': <String>['d'],
            '(command)': 'echo b',
          },
        },
      );

      final diagnostic = only(result, 'duplicate-alias');
      expect(diagnostic.severity, Severity.warning);
      expect(diagnostic.message, contains('"d"'));
    });

    test('flags a direct cycle', () {
      final result = validate(
        r'''
a: echo ${{ b }}
b: echo ${{ a }}
''',
        scripts: {'a': r'echo ${{ b }}', 'b': r'echo ${{ a }}'},
      );

      final diagnostic = only(result, 'circular-reference');
      expect(diagnostic.severity, Severity.error);
      expect(diagnostic.message, contains('->'));
    });

    test('flags an indirect cycle', () {
      final result = validate(
        r'''
a: echo ${{ b }}
b: echo ${{ c }}
c: echo ${{ a }}
''',
        scripts: {
          'a': r'echo ${{ b }}',
          'b': r'echo ${{ c }}',
          'c': r'echo ${{ a }}',
        },
      );

      expect(codes(result), contains('circular-reference'));
    });

    test('does not invent a cycle for a diamond', () {
      // Two scripts referencing the same third one is not a loop. Script's
      // `==` compares command lists, so an identity slip here would report
      // one.
      final result = validate(
        r'''
shared: echo shared
a: echo ${{ shared }}
b: echo ${{ shared }}
both: echo ${{ a }} ${{ b }}
''',
        scripts: {
          'shared': 'echo shared',
          'a': r'echo ${{ shared }}',
          'b': r'echo ${{ shared }}',
          'both': r'echo ${{ a }} ${{ b }}',
        },
      );

      expect(codes(result), isNot(contains('circular-reference')));
    });

    test('does not invent a cycle between two empty groups', () {
      final result = validate(
        '''
a:
  child: echo a
b:
  child: echo b
''',
        scripts: {
          'a': {'child': 'echo a'},
          'b': {'child': 'echo b'},
        },
      );

      expect(codes(result), isNot(contains('circular-reference')));
    });

    test('flags an invalid script name', () {
      final result = validate('bad name: echo hi', scripts: {});

      final diagnostic = only(result, 'invalid-key');
      expect(diagnostic.severity, Severity.error);
      expect(diagnostic.message, contains('spaces'));
    });

    test('reports a YAML syntax error against its line', () {
      final result = validate('a: [1, 2\n');

      final diagnostic = only(result, 'invalid-yaml');
      expect(diagnostic.severity, Severity.error);
      expect(diagnostic.location, isNotNull);
    });

    test('checks commands nested in a list', () {
      final result = validate(
        r'''
a:
  (command):
    - echo one
    - echo ${{ nope }}
''',
        scripts: {
          'a': {
            '(command)': ['echo one', r'echo ${{ nope }}'],
          },
        },
      );

      final diagnostic = only(result, 'unknown-reference');
      // Pointed at the offending list item, not at the script.
      expect(diagnostic.location?.line, 4);
    });

    test('reports diagnostics in file order', () {
      final result = validate(
        r'''
a: echo ${{ nope1 }}
b: echo ${{ nope2 }}
c: echo ${{ nope3 }}
''',
        scripts: {
          'a': r'echo ${{ nope1 }}',
          'b': r'echo ${{ nope2 }}',
          'c': r'echo ${{ nope3 }}',
        },
      );

      expect(result.diagnostics.map((e) => e.location?.line).toList(), [
        1,
        2,
        3,
      ]);
    });

    test('formats a diagnostic the way a compiler would', () {
      final result = validate(
        r'a: echo ${{ nope }}',
        scripts: {'a': r'echo ${{ nope }}'},
      );

      expect(
        result.diagnostics.single.format(),
        startsWith('scripts.yaml:1:1: error: '),
      );
    });
  });
}
