import 'package:sip_cli/utils/stopwatch_extensions.dart';
import 'package:test/test.dart';

void main() {
  group('StopWatchX', () {
    group('#format', () {
      test('should format elapsed time', () {
        final stopwatch = Stopwatch();

        expect(stopwatch.format(), '0s');
      });
    });
  });

  group('$TimeX', () {
    group('#format', () {
      test('should format milliseconds to time', () {
        final times = {
          0: '0s',
          500: '0.5s',
          1000: '1s',
          58300: '58.3s',
          60000: '1m 0s',
          61000: '1m 1s',
          61500: '1m 1.5s',
          3600000: '1h 0m 0s',
        };

        for (final entry in times.entries) {
          expect(TimeX.format(entry.key), entry.value);
        }
      });
    });
  });
}
