import 'package:file/file.dart';
import 'package:file/memory.dart';
import 'package:path/path.dart' as path;
import 'package:sip_cli/domain/find_file.dart';
import 'package:test/test.dart';

void main() {
  group(FindFile, () {
    late FindFile findFile;
    late FileSystem fs;

    setUp(() {
      fs = MemoryFileSystem.test();

      findFile = FindFile(fs: fs);
    });

    group('#nearest', () {
      test('finds file in current directory', () {
        fs.file('pubspec.yaml').createSync(recursive: true);

        final nearest = findFile.nearest('pubspec.yaml');

        expect(nearest, isNotNull);
        expect(nearest, '${path.separator}pubspec.yaml');
      });

      test('finds file in parent directory', () {
        fs.file('pubspec.yaml').createSync(recursive: true);
        fs.directory('bin').createSync(recursive: true);

        fs.currentDirectory = fs.directory('bin');

        final nearest = findFile.nearest('pubspec.yaml');

        expect(nearest, isNotNull);
        expect(nearest, '${path.separator}pubspec.yaml');
      });

      test('returns null when file not found', () {
        final nearest = findFile.nearest('pubspec.yaml');

        expect(nearest, isNull);
      });

      test('returns first file found', () {
        fs.file('pubspec.yaml').createSync(recursive: true);
        final sipPubspec = fs.file(path.join('packages', 'sip', 'pubspec.yaml'))
          ..createSync(recursive: true);

        final nested = fs.directory(path.join('packages', 'sip', 'nested'))
          ..createSync(recursive: true);
        fs.currentDirectory = nested;

        final nearest = findFile.nearest('pubspec.yaml');

        expect(nearest, isNotNull);
        expect(nearest, path.separator + sipPubspec.path);
      });
    });

    group('#childrenOf', () {
      test('find all scripts.yaml of nested dirs', () async {
        final nested = fs.directory(path.join('packages', 'sip', 'nested'))
          ..createSync(recursive: true);

        final nestedScripts = nested.childFile('scripts.yaml')
          ..createSync(recursive: true);

        final scripts = fs.directory('scripts')..createSync(recursive: true);

        final scriptsScripts = scripts.childFile('scripts.yaml')
          ..createSync(recursive: true);

        final children = await findFile.childrenOf('scripts.yaml');

        expect(children, isNotNull);
        expect(children, hasLength(2));
        expect(children, contains(nestedScripts.path));
        expect(children, contains(scriptsScripts.path));
      });
    });
  });
}
