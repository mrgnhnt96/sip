import 'dart:async';

import 'package:file/file.dart';
import 'package:file/memory.dart';
import 'package:meta/meta.dart';
import 'package:mocktail/mocktail.dart';
import 'package:platform/platform.dart';
import 'package:sip_cli/src/domain/args.dart';
import 'package:sip_cli/src/domain/find_file.dart';
import 'package:sip_cli/src/domain/pubspec_lock.dart';
import 'package:sip_cli/src/domain/scripts_yaml.dart';
import 'package:sip_cli/src/utils/package.dart';
import 'package:test/test.dart';

import '../../utils/test_scoped.dart';

void main() {
  late Package pkg;
  late FindFile findFile;
  late PubspecLock pubspecLock;
  late ScriptsYaml scriptsYaml;

  setUp(() {
    findFile = _MockFindFile();
    pubspecLock = _MockPubspecLock();
    scriptsYaml = _MockScriptsYaml();

    pkg = Package('path/to/pubspec.yaml');

    when(() => findFile.retrieveContent(any())).thenReturn(null);
    when(() => pubspecLock.findIn(any())).thenReturn(null);
    when(() => scriptsYaml.executables()).thenReturn(null);
  });

  @isTest
  void test(String description, FutureOr<void> Function() fn) {
    testScoped(
      description,
      fn,
      findFile: () => findFile,
      pubspecLock: () => pubspecLock,
      scriptsYaml: () => scriptsYaml,
    );
  }

  group(Package, () {
    test('should return dart as the default tool', () {
      final tool = pkg.tool;

      expect(tool, 'dart');
      expect(pkg.isDart, isTrue);
      expect(pkg.isFlutter, isFalse);
    });

    test(
      'should return flutter as the tool if flutter is found in contents',
      () {
        when(() => findFile.retrieveContent(any())).thenReturn('flutter:');

        final tool = pkg.tool;

        expect(tool, 'flutter');
        expect(pkg.isDart, isFalse);
        expect(pkg.isFlutter, isTrue);
      },
    );

    test('should return custom dart executable if provided', () {
      when(() => scriptsYaml.executables()).thenReturn({'dart': 'custom_dart'});

      final tool = pkg.tool;

      expect(tool, 'custom_dart');
      expect(pkg.isDart, isTrue);
      expect(pkg.isFlutter, isFalse);
    });

    test('should return custom flutter executable if provided', () {
      when(() => findFile.retrieveContent(any())).thenReturn('flutter:');
      when(
        () => scriptsYaml.executables(),
      ).thenReturn({'flutter': 'custom_flutter'});

      final tool = pkg.tool;

      expect(tool, 'custom_flutter');
      expect(pkg.isDart, isFalse);
      expect(pkg.isFlutter, isTrue);
    });

    test('should return correct directory', () {
      final directory = pkg.path;

      expect(directory, 'path/to');
    });
  });

  group('$Package.bucketPlan', () {
    late FileSystem bucketFs;

    @isTest
    void bucketTest(
      String description,
      FutureOr<void> Function() fn, {
      Map<String, dynamic> args = const {},
      Platform? platform,
    }) {
      testScoped(
        description,
        fn,
        findFile: () => findFile,
        pubspecLock: () => pubspecLock,
        scriptsYaml: () => scriptsYaml,
        fileSystem: () => bucketFs,
        args: () => Args(args: args),
        platform: platform == null ? null : () => platform,
      );
    }

    Package flutterPackage() {
      bucketFs.file('/project/pubspec.yaml')
        ..createSync(recursive: true)
        ..writeAsStringSync('name: project\ndependencies:\n  flutter:\n');

      when(
        () => findFile.retrieveContent('/project/pubspec.yaml'),
      ).thenReturn('flutter:');

      return Package('/project/pubspec.yaml');
    }

    void writeTestFile(String relativePath, String content) {
      bucketFs.file('/project/$relativePath')
        ..createSync(recursive: true)
        ..writeAsStringSync(content);
    }

    const safeContent = '''
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('renders', (tester) async {});
}
''';

    const unsafeBindingContent = '''
void main() {
  LiveTestWidgetsFlutterBinding.ensureInitialized();
}
''';

    const unsafeSurfaceContent = '''
void main() {
  tester.view.physicalSize = const Size(100, 100);
}
''';

    setUp(() {
      bucketFs = MemoryFileSystem.test();
    });

    bucketTest('is null when the flag is not set', () {
      final pkg = flutterPackage();
      writeTestFile('test/foo_test.dart', safeContent);

      expect(pkg.bucketPlan, isNull);
    });

    bucketTest(
      'is null for dart packages even when the flag is set',
      () {
        bucketFs.file('/project/pubspec.yaml')
          ..createSync(recursive: true)
          ..writeAsStringSync('name: project');
        when(
          () => findFile.retrieveContent('/project/pubspec.yaml'),
        ).thenReturn(null);
        final pkg = Package('/project/pubspec.yaml');
        writeTestFile('test/foo_test.dart', safeContent);

        expect(pkg.experimentalBucketEnabled, isFalse);
        expect(pkg.bucketPlan, isNull);
      },
      args: {'experimental-bucket': true},
    );

    bucketTest('is null when there are no test files', () {
      final pkg = flutterPackage();

      expect(pkg.bucketPlan, isNull);
    }, args: {'experimental-bucket': true});

    bucketTest(
      'round-robins combinable files across bucket-count buckets',
      () {
        final pkg = flutterPackage();
        writeTestFile('test/a_test.dart', safeContent);
        writeTestFile('test/b_test.dart', safeContent);
        writeTestFile('test/c_test.dart', safeContent);
        writeTestFile('test/d_test.dart', safeContent);

        final plan = pkg.bucketPlan!;

        expect(plan.buckets, hasLength(2));
        expect(plan.buckets[0].originalFiles, [
          'test/a_test.dart',
          'test/c_test.dart',
        ]);
        expect(plan.buckets[1].originalFiles, [
          'test/b_test.dart',
          'test/d_test.dart',
        ]);
        expect(plan.soloFiles, isEmpty);
      },
      args: {'experimental-bucket': true, 'bucket-count': 2},
    );

    bucketTest(
      'clamps bucket count down to the number of combinable files',
      () {
        final pkg = flutterPackage();
        writeTestFile('test/a_test.dart', safeContent);
        writeTestFile('test/b_test.dart', safeContent);

        final plan = pkg.bucketPlan!;

        expect(plan.buckets, hasLength(2));
      },
      args: {'experimental-bucket': true, 'bucket-count': 10},
    );

    bucketTest(
      'defaults bucket count to the number of processors',
      () {
        final pkg = flutterPackage();
        writeTestFile('test/a_test.dart', safeContent);
        writeTestFile('test/b_test.dart', safeContent);
        writeTestFile('test/c_test.dart', safeContent);

        final plan = pkg.bucketPlan!;

        expect(plan.buckets, hasLength(2));
      },
      args: {'experimental-bucket': true},
      platform: FakePlatform(numberOfProcessors: 2),
    );

    bucketTest('routes an unsafe binding file to solo with a reason, '
        'safe files stay combinable', () {
      final pkg = flutterPackage();
      writeTestFile('test/a_test.dart', safeContent);
      writeTestFile('test/bad_test.dart', unsafeBindingContent);

      final plan = pkg.bucketPlan!;

      expect(plan.soloFiles, ['test/bad_test.dart']);
      expect(
        plan.soloReasons['test/bad_test.dart'],
        'uses LiveTestWidgetsFlutterBinding',
      );
      // The solo file still gets its own generated single-file wrapper
      // (never sharing an isolate with anything else) alongside the real
      // combined bucket, so every dispatched unit is uniformly
      // identifiable regardless of invocation shape.
      expect(plan.buckets, hasLength(2));
      expect(
        plan.buckets.map((b) => b.originalFiles),
        containsAll([
          ['test/a_test.dart'],
          ['test/bad_test.dart'],
        ]),
      );
    }, args: {'experimental-bucket': true, 'bucket-count': 1});

    bucketTest(
      'routes an unreset surface-mutating file to solo',
      () {
        final pkg = flutterPackage();
        writeTestFile('test/a_test.dart', safeContent);
        writeTestFile('test/bad_test.dart', unsafeSurfaceContent);

        final plan = pkg.bucketPlan!;

        expect(plan.soloFiles, ['test/bad_test.dart']);
        expect(
          plan.buckets.map((b) => b.originalFiles),
          containsAll([
            ['test/a_test.dart'],
            ['test/bad_test.dart'],
          ]),
        );
      },
      args: {'experimental-bucket': true, 'bucket-count': 1},
    );

    bucketTest(
      'writes a generated bucket file with correct imports and groups',
      () {
        final pkg = flutterPackage();
        writeTestFile('test/a_test.dart', safeContent);
        writeTestFile('test/sub/b_test.dart', safeContent);

        final plan = pkg.bucketPlan!;
        final bucket = plan.buckets.single;

        final generated = bucketFs
            .file('/project/${bucket.file}')
            .readAsStringSync();

        expect(generated, contains("import 'a_test.dart' as _i0;"));
        expect(generated, contains("import 'sub/b_test.dart' as _i1;"));
        expect(
          generated,
          contains("group('test/a_test.dart', () { _i0.main(); });"),
        );
        expect(
          generated,
          contains("group('test/sub/b_test.dart', () { _i1.main(); });"),
        );
      },
      args: {'experimental-bucket': true, 'bucket-count': 1},
    );

    bucketTest(
      'testGroups combines every bucket and solo file into one invocation',
      () {
        final pkg = flutterPackage();
        writeTestFile('test/a_test.dart', safeContent);
        writeTestFile('test/b_test.dart', safeContent);
        writeTestFile('test/bad_test.dart', unsafeBindingContent);

        final groups = pkg.testGroups;
        final plan = pkg.bucketPlan!;

        // ONE flutter test invocation covering every bucket/solo file --
        // never one invocation per bucket (see Package.testGroups doc for
        // why: avoids paying Flutter's per-invocation bootstrap cost N
        // times and avoids multiple flutter test processes racing on the
        // same package's build/native_assets directory).
        expect(groups, hasLength(1));
        expect(groups.single, unorderedEquals(plan.buckets.map((b) => b.file)));
      },
      args: {'experimental-bucket': true, 'bucket-count': 1},
    );

    bucketTest(
      'testGroups applies shard selection when both shard flags are set',
      () {
        final pkg = flutterPackage();
        writeTestFile('test/a_test.dart', safeContent);
        writeTestFile('test/b_test.dart', safeContent);
        writeTestFile('test/c_test.dart', safeContent);
        writeTestFile('test/d_test.dart', safeContent);

        final groups = pkg.testGroups;

        expect(groups, [
          [
            'test/.test_optimizer_bucket_1.dart',
            'test/.test_optimizer_bucket_3.dart',
          ],
        ]);
      },
      args: {
        'experimental-bucket': true,
        'bucket-count': 4,
        'bucket-shard-index': 1,
        'bucket-shard-count': 2,
      },
    );

    bucketTest(
      'bucketOriginalFilesFor returns null for unknown files',
      () {
        final pkg = flutterPackage();
        writeTestFile('test/a_test.dart', safeContent);

        expect(pkg.bucketPlan, isNotNull);
        expect(pkg.bucketOriginalFilesFor('test/not_a_bucket.dart'), isNull);
      },
      args: {'experimental-bucket': true, 'bucket-count': 1},
    );

    bucketTest(
      'bucketOriginalFilesFor resolves a generated bucket to its files',
      () {
        final pkg = flutterPackage();
        writeTestFile('test/a_test.dart', safeContent);
        writeTestFile('test/b_test.dart', safeContent);

        final bucketFile = pkg.bucketPlan!.buckets.single.file;

        expect(pkg.bucketOriginalFilesFor(bucketFile), [
          'test/a_test.dart',
          'test/b_test.dart',
        ]);
      },
      args: {'experimental-bucket': true, 'bucket-count': 1},
    );

    bucketTest('generates a trivial single-file wrapper for a solo file, '
        'not its raw path', () {
      final pkg = flutterPackage();
      writeTestFile('test/bad_test.dart', unsafeBindingContent);

      final plan = pkg.bucketPlan!;
      final solo = plan.buckets.single;

      expect(solo.originalFiles, ['test/bad_test.dart']);
      expect(solo.file, isNot('test/bad_test.dart'));

      final generated = bucketFs
          .file('/project/${solo.file}')
          .readAsStringSync();

      expect(generated, contains("import 'bad_test.dart' as _i0;"));
      expect(
        generated,
        contains("group('test/bad_test.dart', () { _i0.main(); });"),
      );
    }, args: {'experimental-bucket': true, 'bucket-count': 1});

    bucketTest('bucketFileGroupsFor maps each unit to its original files, '
        'for both buckets and solo wrappers', () {
      final pkg = flutterPackage();
      writeTestFile('test/a_test.dart', safeContent);
      writeTestFile('test/b_test.dart', safeContent);
      writeTestFile('test/bad_test.dart', unsafeBindingContent);

      final units = pkg.testGroups.single;
      final groups = pkg.bucketFileGroupsFor(units);

      expect(
        groups,
        containsAll([
          ['test/a_test.dart', 'test/b_test.dart'],
          ['test/bad_test.dart'],
        ]),
      );
    }, args: {'experimental-bucket': true, 'bucket-count': 1});

    bucketTest(
      'deleteOptimizedTestFile removes generated bucket files',
      () {
        final pkg = flutterPackage();
        writeTestFile('test/a_test.dart', safeContent);
        writeTestFile('test/b_test.dart', safeContent);

        final bucket = pkg.bucketPlan!.buckets.single;
        expect(bucketFs.file('/project/${bucket.file}').existsSync(), isTrue);

        pkg.deleteOptimizedTestFile();

        expect(bucketFs.file('/project/${bucket.file}').existsSync(), isFalse);
        expect(bucketFs.file('/project/test/a_test.dart').existsSync(), isTrue);
      },
      args: {'experimental-bucket': true, 'bucket-count': 1},
    );
  });
}

class _MockFindFile extends Mock implements FindFile {}

class _MockPubspecLock extends Mock implements PubspecLock {}

class _MockScriptsYaml extends Mock implements ScriptsYaml {}
