import 'package:file/file.dart';
import 'package:sip_cli/domain/find_file.dart';
import 'package:sip_cli/setup/setup.dart';
import 'package:test/test.dart';
import 'package:path/path.dart' as path;

import '../../utils/setup_testing_dependency_injection.dart';

void main() {
  group('$FindFile', () {
    late FindFile findFile;
    late FileSystem fs;

    setUp(() {
      setupTestingDependencyInjection();

      fs = getIt<FileSystem>();

      findFile = FindFile();
    });

    group('#nearest', () {
      test('finds file in current directory', () {
        fs.file('pubspec.yaml').createSync(recursive: true);

        final nearest = findFile.nearest('pubspec.yaml');

        expect(nearest, isNotNull);
        expect(nearest, path.separator + 'pubspec.yaml');
      });

      test('finds file in parent directory', () {
        fs.file('pubspec.yaml').createSync(recursive: true);
        fs.directory('bin').createSync(recursive: true);

        fs.currentDirectory = fs.directory('bin');

        final nearest = findFile.nearest('pubspec.yaml');

        expect(nearest, isNotNull);
        expect(nearest, path.separator + 'pubspec.yaml');
      });

      test('returns null when file not found', () {
        final nearest = findFile.nearest('pubspec.yaml');

        expect(nearest, isNull);
      });

      test('returns first file found', () {
        fs.file('pubspec.yaml').createSync(recursive: true);
        final sipPubspec =
            fs.file(path.join('packages', 'sip', 'pubspec.yaml'));

        sipPubspec.createSync(recursive: true);

        final nested = fs.directory(path.join('packages', 'sip', 'nested'));
        nested.createSync(recursive: true);
        fs.currentDirectory = nested;

        final nearest = findFile.nearest('pubspec.yaml');

        expect(nearest, isNotNull);
        expect(nearest, path.separator + sipPubspec.path);
      });
    });
  });
}
