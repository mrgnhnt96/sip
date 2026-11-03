import 'package:path/path.dart' as p;
import 'package:sip_cli/src/domain/test_reports.dart';
import 'package:test/test.dart';

void main() {
  group(TestReports, () {
    final posix = p.Context(style: p.Style.posix);

    String? next(TestReports reports, String? option, {String cwd = '/repo'}) =>
        reports.nextArgument(option, cwd: cwd, context: posix);

    test('passes nothing when the option is not set', () {
      expect(next(TestReports(), null), isNull);
    });

    test('resolves a relative path against where sip was started', () {
      expect(
        next(TestReports(), 'json:out/results.json'),
        '--file-reporter json:/repo/out/results.json',
      );
    });

    test('keeps an absolute path', () {
      expect(
        next(TestReports(), 'json:/tmp/results.json'),
        '--file-reporter json:/tmp/results.json',
      );
    });

    test('gives every later run its own numbered file', () {
      final reports = TestReports();

      expect(
        [for (var i = 0; i < 3; i++) next(reports, 'json:results.json')],
        [
          '--file-reporter json:/repo/results.json',
          '--file-reporter json:/repo/results.1.json',
          '--file-reporter json:/repo/results.2.json',
        ],
      );
    });

    test('numbers a path that has no extension', () {
      final reports = TestReports();
      next(reports, 'expanded:log');

      expect(
        next(reports, 'expanded:log'),
        '--file-reporter expanded:/repo/log.1',
      );
    });

    test('quotes a path with spaces', () {
      expect(
        next(TestReports(), 'json:my results.json', cwd: '/my repo'),
        '--file-reporter "json:/my repo/my results.json"',
      );
    });

    test('passes a value without a reporter through for the runner to '
        'reject', () {
      expect(
        next(TestReports(), 'results.json'),
        '--file-reporter results.json',
      );
    });
  });
}
