import 'package:sip_cli/src/domain/test_scope.dart';
import 'package:test/test.dart';

void main() {
  group(TestScope, () {
    group('#toggle', () {
      test('should toggle to the next value', () {
        expect(TestScope.toggle(TestScope.active), TestScope.file);
        expect(TestScope.toggle(TestScope.file), TestScope.all);
        expect(TestScope.toggle(TestScope.all), TestScope.active);
      });
    });
  });
}
