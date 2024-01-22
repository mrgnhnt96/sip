import 'package:sip_script_runner/domain/optional_flags.dart';
import 'package:test/test.dart';

void main() {
  group('$OptionalFlags', () {
    test('can parse single flag without values', () {
      final flags = OptionalFlags(['-f']);

      expect(flags['-f'], '-f');
    });

    test('can parse single flag with value', () {
      final flags = OptionalFlags(['-f', 'value']);

      expect(flags['-f'], '-f value');
    });

    test('can parse multiple flags without values', () {
      final flags = OptionalFlags(['-f', '-v']);

      expect(flags['-f'], '-f');
      expect(flags['-v'], '-v');
    });

    test('can parse multiple flags with values', () {
      final flags = OptionalFlags(['-f', 'one', '-v', 'two']);

      expect(flags['-f'], '-f one');
      expect(flags['-v'], '-v two');
    });
  });
}
