import 'package:sip_cli/src/utils/flutter_test_safety.dart';
import 'package:test/test.dart';

void main() {
  group(FlutterTestSafety, () {
    group('#isCombinable', () {
      test('is true for a plain widget test with no binding overrides', () {
        const content = '''
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('renders', (tester) async {});
}
''';

        expect(FlutterTestSafety.isCombinable(content), isTrue);
      });

      test(
        'is true when TestWidgetsFlutterBinding.ensureInitialized is used',
        () {
          const content = '''
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
}
''';

          expect(FlutterTestSafety.isCombinable(content), isTrue);
        },
      );

      test('is true when AutomatedTestWidgetsFlutterBinding is referenced', () {
        const content = '''
void main() {
  AutomatedTestWidgetsFlutterBinding.ensureInitialized();
}
''';

        expect(FlutterTestSafety.isCombinable(content), isTrue);
      });

      test('is true when a surface mutation has a matching reset', () {
        const content = '''
void main() {
  tester.view.physicalSize = const Size(100, 100);
  addTearDown(tester.view.resetPhysicalSize);
}
''';

        expect(FlutterTestSafety.isCombinable(content), isTrue);
      });

      test('is false when LiveTestWidgetsFlutterBinding is used', () {
        const content = '''
void main() {
  LiveTestWidgetsFlutterBinding.ensureInitialized();
}
''';

        expect(FlutterTestSafety.isCombinable(content), isFalse);
      });

      test('is false when IntegrationTestWidgetsFlutterBinding is used', () {
        const content = '''
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
}
''';

        expect(FlutterTestSafety.isCombinable(content), isFalse);
      });

      test('is false for any other explicit binding subtype', () {
        const content = '''
void main() {
  CustomTestWidgetsFlutterBinding.ensureInitialized();
}
''';

        expect(FlutterTestSafety.isCombinable(content), isFalse);
      });

      test('is false when physicalSize is set without a reset', () {
        const content = '''
void main() {
  tester.view.physicalSize = const Size(100, 100);
}
''';

        expect(FlutterTestSafety.isCombinable(content), isFalse);
      });

      test('is false when devicePixelRatio is set without a reset', () {
        const content = '''
void main() {
  tester.view.devicePixelRatio = 2.0;
}
''';

        expect(FlutterTestSafety.isCombinable(content), isFalse);
      });

      test('is false when setSurfaceSize is called without a null reset', () {
        const content = '''
void main() {
  binding.setSurfaceSize(const Size(100, 100));
}
''';

        expect(FlutterTestSafety.isCombinable(content), isFalse);
      });

      test('is true when setSurfaceSize is reset to null', () {
        const content = '''
void main() {
  binding.setSurfaceSize(const Size(100, 100));
  addTearDown(() => binding.setSurfaceSize(null));
}
''';

        expect(FlutterTestSafety.isCombinable(content), isTrue);
      });
    });

    group('#soloReason', () {
      test('names the unsafe binding pattern', () {
        const content = '''
void main() {
  LiveTestWidgetsFlutterBinding.ensureInitialized();
}
''';

        expect(
          FlutterTestSafety.soloReason(content),
          'uses LiveTestWidgetsFlutterBinding',
        );
      });

      test('names an unrecognized explicit binding subtype', () {
        const content = '''
void main() {
  CustomTestWidgetsFlutterBinding.ensureInitialized();
}
''';

        expect(
          FlutterTestSafety.soloReason(content),
          'uses CustomTestWidgetsFlutterBinding',
        );
      });

      test('describes an unreset surface mutation', () {
        const content = '''
void main() {
  tester.view.physicalSize = const Size(100, 100);
}
''';

        expect(
          FlutterTestSafety.soloReason(content),
          contains('mutates the test surface'),
        );
      });

      test('falls back to unknown for combinable content', () {
        const content = '''
void main() {}
''';

        expect(FlutterTestSafety.soloReason(content), 'unknown');
      });
    });
  });
}
