import 'dart:async';

import 'package:file/file.dart';
import 'package:file/memory.dart';
import 'package:meta/meta.dart';
import 'package:sip_cli/src/deps/scripts_yaml.dart';
import 'package:sip_cli/src/domain/scripts_yaml.dart';
import 'package:sip_cli/src/domain/test_config.dart';
import 'package:test/test.dart';

import '../../utils/test_scoped.dart';

void main() {
  group(TestConfig, () {
    group('globList', () {
      test('reads a single glob', () {
        expect(TestConfig.globList('test/a_test.dart'), ['test/a_test.dart']);
      });

      test('reads a list of globs, dropping anything that is not a string', () {
        expect(TestConfig.globList(['test/a/**', 1, null, 'b_test.dart']), [
          'test/a/**',
          'b_test.dart',
        ]);
      });

      test('strips a leading ./, which a glob would never match', () {
        expect(TestConfig.globList('./test/a_test.dart'), ['test/a_test.dart']);
      });

      test('is empty for nothing', () {
        expect(TestConfig.globList(null), isEmpty);
        expect(TestConfig.globList({'a': 'b'}), isEmpty);
      });
    });

    test('fromJson reads bucket-solo', () {
      final config = TestConfig.fromJson({
        'bucket-solo': ['test/golden/**'],
      });

      expect(config.bucketSolo, ['test/golden/**']);
    });

    group('load', () {
      late FileSystem fs;

      setUp(() {
        fs = MemoryFileSystem.test();
      });

      @isTest
      void test(String description, FutureOr<void> Function() fn) {
        testScoped(
          description,
          fn,
          fileSystem: () => fs,
          scriptsYaml: () => const ScriptsYaml(),
        );
      }

      test('reads (test) from scripts.yaml and keeps it out of scripts', () {
        fs.file('scripts.yaml').writeAsStringSync('''
(test):
  bucket-solo:
    - test/golden/**
format: dart format .
''');

        expect(TestConfig.load().bucketSolo, ['test/golden/**']);
        expect(scriptsYaml.scripts(), {'format': 'dart format .'});
      });

      test('is empty when (test) is missing or not a map', () {
        fs.file('scripts.yaml').writeAsStringSync('(test): oops\n');
        expect(TestConfig.load().bucketSolo, isEmpty);

        fs.file('scripts.yaml').writeAsStringSync('format: dart format .\n');
        expect(TestConfig.load().bucketSolo, isEmpty);
      });
    });
  });
}
