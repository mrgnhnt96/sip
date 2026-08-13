import 'package:sip_cli/src/domain/script_locations.dart';
import 'package:test/test.dart';

void main() {
  group(ScriptLocations, () {
    const yaml = '''
format: dart format .

build_runner:
  (aliases):
    - b
  build: dart run build_runner build

prep:
  (command):
    - echo one
    - echo two
''';

    final locations = ScriptLocations.parse(yaml, file: 'scripts.yaml');

    test('points at the line and column a key was written on', () {
      // Lines and columns are 1-based, matching every other tool that emits
      // `file:line:column`.
      expect(
        locations.forPath(['format']),
        isA<ScriptLocation>()
            .having((e) => e.line, 'line', 1)
            .having((e) => e.column, 'column', 1)
            .having((e) => e.file, 'file', 'scripts.yaml'),
      );

      expect(
        locations.forPath(['build_runner']),
        isA<ScriptLocation>().having((e) => e.line, 'line', 3),
      );
    });

    test('indexes nested keys under their parent', () {
      expect(
        locations.forPath(['build_runner', 'build']),
        isA<ScriptLocation>()
            .having((e) => e.line, 'line', 6)
            .having((e) => e.column, 'column', 3),
      );
    });

    test('indexes reserved keys too', () {
      expect(
        locations.forPath(['build_runner', '(aliases)']),
        isA<ScriptLocation>().having((e) => e.line, 'line', 4),
      );
    });

    test('indexes list items by position', () {
      expect(
        locations.forPath(['prep', '(command)', ScriptLocations.indexKey(0)]),
        isA<ScriptLocation>().having((e) => e.line, 'line', 10),
      );

      expect(
        locations.forPath(['prep', '(command)', ScriptLocations.indexKey(1)]),
        isA<ScriptLocation>().having((e) => e.line, 'line', 11),
      );
    });

    test('returns null for a path that was never written', () {
      expect(locations.forPath(['nope']), isNull);
      expect(locations.forPath(['format', 'nope']), isNull);
    });

    test('nearest falls back to the closest declared ancestor', () {
      expect(
        locations.nearest(['build_runner', 'build', 'deeper', 'still']),
        isA<ScriptLocation>().having((e) => e.line, 'line', 6),
      );

      expect(locations.nearest(['nope', 'nope']), isNull);
    });

    test('a file that does not parse yields an empty index', () {
      final broken = ScriptLocations.parse('a: [1, 2\n', file: 'scripts.yaml');

      expect(broken.isEmpty, isTrue);
      expect(broken.forPath(['a']), isNull);
    });

    test('keys containing dots do not collide', () {
      final dotted = ScriptLocations.parse('''
a:
  b.c: echo one
a.b:
  c: echo two
''', file: 'scripts.yaml');

      expect(
        dotted.forPath(['a', 'b.c']),
        isA<ScriptLocation>().having((e) => e.line, 'line', 2),
      );
      expect(
        dotted.forPath(['a.b', 'c']),
        isA<ScriptLocation>().having((e) => e.line, 'line', 4),
      );
    });
  });
}
