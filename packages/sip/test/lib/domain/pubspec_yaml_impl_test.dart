// ignore_for_file: avoid_redundant_argument_values

import 'package:file/file.dart';
import 'package:file/memory.dart';
import 'package:sip_cli/domain/pubspec_yaml_impl.dart';
import 'package:test/test.dart';

void main() {
  group('$PubspecYamlImpl', () {
    late FileSystem fs;
    late PubspecYamlImpl tester;

    setUp(() {
      fs = MemoryFileSystem.test();

      tester = PubspecYamlImpl(fs: fs);
    });

    group('when not recursive', () {
      test('should return the root pubspec.yaml', () async {
        fs.file('pubspec.yaml').createSync();

        final all = await tester.all(recursive: false);

        expect(all, isNotNull);
        expect(all.length, 1);
      });

      test('should return not return sub pubspec.yamls', () async {
        fs.file('pubspec.yaml').createSync();
        fs.file('sub/pubspec.yaml').createSync(recursive: true);

        final all = await tester.all(recursive: false);

        expect(all, isNotNull);
        expect(all.length, 1);
      });
    });

    group('when recursive', () {
      test('should return the root pubspec.yaml', () async {
        fs.file('pubspec.yaml').createSync();

        final all = await tester.all(recursive: true);

        expect(all, isNotNull);
        expect(all.length, 1);
      });

      test('should return all pubspec.yamls and root', () async {
        fs.file('pubspec.yaml').createSync();
        fs.file('sub/pubspec.yaml').createSync(recursive: true);

        final all = await tester.all(recursive: true);

        expect(all, isNotNull);
        expect(all.length, 2);
      });

      test('should return all pubspec.yamls even when root does not exist',
          () async {
        fs.file('sub/pubspec.yaml').createSync(recursive: true);

        final all = await tester.all(recursive: true);

        expect(all.length, 1);
      });

      test('should come back sorted by length', () async {
        fs.file('pubspec.yaml').createSync();
        fs.file('sub/pubspec.yaml').createSync(recursive: true);

        final all = await tester.all(recursive: true);

        expect(all, isNotNull);
        expect(all.length, 2);
        expect(all.first, endsWith('sub/pubspec.yaml'));
        expect(all.last, endsWith('pubspec.yaml'));
      });
    });
  });
}
