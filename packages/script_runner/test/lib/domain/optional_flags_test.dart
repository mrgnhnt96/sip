import 'package:sip_script_runner/domain/optional_flags.dart';
import 'package:test/test.dart';

import '../../utils/setup_testing_dependency_injection.dart';

void main() {
  setUp(setupTestingDependencyInjection);

  group('$OptionalFlags', () {
    test('can parse single flag without values', () {
      final flags = OptionalFlags(const ['-f']);

      expect(flags['-f'], '-f');
    });

    test('can parse single flag with value', () {
      final flags = OptionalFlags(const ['-f', 'value']);

      expect(flags['-f'], '-f value');
    });

    test('can parse multiple flags without values', () {
      final flags = OptionalFlags(const ['-f', '-v']);

      expect(flags['-f'], '-f');
      expect(flags['-v'], '-v');
    });

    test('can parse multiple flags with values', () {
      final flags = OptionalFlags(const ['-f', 'one', '-v', 'two']);

      expect(flags['-f'], '-f one');
      expect(flags['-v'], '-v two');
    });

    test('flag when value is provided immediately', () {
      final flags = OptionalFlags(const ['--coverage=coverage']);

      expect(flags['--coverage'], '--coverage=coverage');
    });

    test('ignores = in other flags', () {
      final flags = OptionalFlags(const ['--coverage', 'coverage=coverage']);

      expect(flags['--coverage'], '--coverage coverage=coverage');
    });
  });
}
