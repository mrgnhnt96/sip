import 'package:sip_cli/domain/run_tests.dart';
import 'package:test/test.dart';

void main() {
  group('$RunTests', () {
    group('#toggle', () {
      test('should toggle to the next value', () {
        expect(RunTests.toggle(RunTests.package), RunTests.modified);
        expect(RunTests.toggle(RunTests.modified), RunTests.all);
        expect(RunTests.toggle(RunTests.all), RunTests.package);
      });
    });
  });
}
