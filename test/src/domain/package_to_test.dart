import 'package:mocktail/mocktail.dart';
import 'package:sip_cli/src/domain/package_to_test.dart';
import 'package:sip_cli/src/utils/package.dart';
import 'package:test/test.dart';

void main() {
  group(PackageToTest, () {
    group('constructor', () {
      test('should remove test directory from package path', () {
        final packageToTest = PackageToTest(
          pkg: _MockDetermineFlutterOrDart(),
          packagePath: 'package/test',
        );

        expect(packageToTest.packagePath, 'package');
      });

      test('should remove lib directory from package path', () {
        final packageToTest = PackageToTest(
          pkg: _MockDetermineFlutterOrDart(),
          packagePath: 'package/lib',
        );

        expect(packageToTest.packagePath, 'package');
      });

      test('should not remove any directory from package path', () {
        final packageToTest = PackageToTest(
          pkg: _MockDetermineFlutterOrDart(),
          packagePath: 'package',
        );

        expect(packageToTest.packagePath, 'package');
      });
    });
  });
}

class _MockDetermineFlutterOrDart extends Mock implements Package {}
