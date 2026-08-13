import 'package:sip_cli/src/domain/args.dart';
import 'package:sip_cli/src/utils/output_mode.dart';
import 'package:test/test.dart';

void main() {
  Args parse(List<String> args) => Args.parse(args);

  group('shouldUseAnsi', () {
    test('follows the terminal when nothing else says otherwise', () {
      expect(
        shouldUseAnsi(
          args: parse([]),
          environment: const {},
          hasTerminal: true,
        ),
        isTrue,
      );

      expect(
        shouldUseAnsi(
          args: parse([]),
          environment: const {},
          hasTerminal: false,
        ),
        isFalse,
      );
    });

    test('--no-color wins over a terminal', () {
      expect(
        shouldUseAnsi(
          args: parse(['--no-color']),
          environment: const {},
          hasTerminal: true,
        ),
        isFalse,
      );
    });

    test('--color wins over a pipe', () {
      expect(
        shouldUseAnsi(
          args: parse(['--color']),
          environment: const {},
          hasTerminal: false,
        ),
        isTrue,
      );
    });

    test('--color wins over NO_COLOR', () {
      expect(
        shouldUseAnsi(
          args: parse(['--color']),
          environment: const {'NO_COLOR': '1'},
          hasTerminal: false,
        ),
        isTrue,
      );
    });

    test('NO_COLOR turns colour off', () {
      expect(
        shouldUseAnsi(
          args: parse([]),
          environment: const {'NO_COLOR': '1'},
          hasTerminal: true,
        ),
        isFalse,
      );
    });

    test('an empty NO_COLOR is not set', () {
      expect(
        shouldUseAnsi(
          args: parse([]),
          environment: const {'NO_COLOR': ''},
          hasTerminal: true,
        ),
        isTrue,
      );
    });

    test('FORCE_COLOR turns colour on when piped', () {
      expect(
        shouldUseAnsi(
          args: parse([]),
          environment: const {'FORCE_COLOR': '1'},
          hasTerminal: false,
        ),
        isTrue,
      );
    });

    test('NO_COLOR beats FORCE_COLOR', () {
      expect(
        shouldUseAnsi(
          args: parse([]),
          environment: const {'NO_COLOR': '1', 'FORCE_COLOR': '1'},
          hasTerminal: true,
        ),
        isFalse,
      );
    });

    test('TERM=dumb turns colour off', () {
      expect(
        shouldUseAnsi(
          args: parse([]),
          environment: const {'TERM': 'dumb'},
          hasTerminal: true,
        ),
        isFalse,
      );
    });
  });

  group('shouldCheckVersion', () {
    test('follows the terminal when nothing else says otherwise', () {
      expect(
        shouldCheckVersion(
          args: parse([]),
          environment: const {},
          hasTerminal: true,
        ),
        isTrue,
      );

      expect(
        shouldCheckVersion(
          args: parse([]),
          environment: const {},
          hasTerminal: false,
        ),
        isFalse,
      );
    });

    test('--no-version-check wins over a terminal', () {
      expect(
        shouldCheckVersion(
          args: parse(['--no-version-check']),
          environment: const {},
          hasTerminal: true,
        ),
        isFalse,
      );
    });

    test('--version-check wins over a pipe', () {
      expect(
        shouldCheckVersion(
          args: parse(['--version-check']),
          environment: const {},
          hasTerminal: false,
        ),
        isTrue,
      );
    });

    test('SIP_NO_VERSION_CHECK turns the check off', () {
      expect(
        shouldCheckVersion(
          args: parse([]),
          environment: const {'SIP_NO_VERSION_CHECK': '1'},
          hasTerminal: true,
        ),
        isFalse,
      );
    });

    test('--version-check wins over SIP_NO_VERSION_CHECK', () {
      expect(
        shouldCheckVersion(
          args: parse(['--version-check']),
          environment: const {'SIP_NO_VERSION_CHECK': '1'},
          hasTerminal: true,
        ),
        isTrue,
      );
    });
  });
}
