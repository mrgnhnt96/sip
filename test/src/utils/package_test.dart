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
    when(() => scriptsYaml.test()).thenReturn(null);
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

    const plainContent = '''
import 'dart:io';

void main() {
  test('talks to a local server', () async {
    await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
  });
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

    bucketTest('is null for dart packages even when the flag is set', () {
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
    }, args: {'experimental-bucket': true});

    bucketTest('is null when there are no test files', () {
      final pkg = flutterPackage();

      expect(pkg.bucketPlan, isNull);
    }, args: {'experimental-bucket': true});

    bucketTest('round-robins combinable files across bucket-count buckets', () {
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
    }, args: {'experimental-bucket': true, 'bucket-count': 2});

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
      'routes a file matching --bucket-solo to solo, even when it is safe',
      () {
        final pkg = flutterPackage();
        writeTestFile('test/a_test.dart', safeContent);
        writeTestFile('test/golden_test.dart', safeContent);

        final plan = pkg.bucketPlan!;

        expect(plan.soloFiles, ['test/golden_test.dart']);
        expect(
          plan.soloReasons['test/golden_test.dart'],
          'matches bucket-solo "test/golden_test.dart"',
        );
        expect(
          plan.buckets.map((b) => b.originalFiles),
          containsAll([
            ['test/a_test.dart'],
            ['test/golden_test.dart'],
          ]),
        );
      },
      args: {
        'experimental-bucket': true,
        'bucket-count': 1,
        'bucket-solo': 'test/golden_test.dart',
      },
    );

    bucketTest(
      'reads every glob from a repeated --bucket-solo flag',
      () {
        final pkg = flutterPackage();
        writeTestFile('test/a_test.dart', safeContent);
        writeTestFile('test/golden/b_test.dart', safeContent);
        writeTestFile('test/c_test.dart', safeContent);

        final plan = pkg.bucketPlan!;

        expect(plan.soloFiles, ['test/c_test.dart', 'test/golden/b_test.dart']);
        expect(plan.buckets, hasLength(3));
      },
      args: Args.parse([
        '--experimental-bucket',
        '--bucket-solo',
        'test/golden/**',
        '--bucket-solo',
        './test/c_test.dart',
      ]).values,
    );

    bucketTest(
      'merges (test): bucket-solo: from scripts.yaml with the flag',
      () {
        when(() => scriptsYaml.test()).thenReturn({
          'bucket-solo': ['**/golden_test.dart'],
        });
        final pkg = flutterPackage();
        writeTestFile('test/a_test.dart', safeContent);
        writeTestFile('test/feature/golden_test.dart', safeContent);
        writeTestFile('test/flag_test.dart', safeContent);

        final plan = pkg.bucketPlan!;

        expect(plan.soloFiles, [
          'test/feature/golden_test.dart',
          'test/flag_test.dart',
        ]);
        expect(
          plan.soloReasons['test/feature/golden_test.dart'],
          'matches bucket-solo "**/golden_test.dart"',
        );
        expect(
          plan.buckets.map((b) => b.originalFiles),
          contains(equals(['test/a_test.dart'])),
        );
      },
      args: {
        'experimental-bucket': true,
        'bucket-count': 1,
        'bucket-solo': 'test/flag_test.dart',
      },
    );

    for (final (index, expected) in [
      (0, ['test/a_test.dart']),
      (1, ['test/golden_test.dart']),
    ]) {
      bucketTest(
        'keeps --bucket-solo files in sharding (shard $index of 2)',
        () {
          final pkg = flutterPackage();
          writeTestFile('test/a_test.dart', safeContent);
          writeTestFile('test/golden_test.dart', safeContent);

          final groups = [
            for (final group in pkg.testGroups)
              ...pkg.bucketFileGroupsFor(group),
          ];

          expect(groups, [expected]);
        },
        args: {
          'experimental-bucket': true,
          'bucket-count': 1,
          'bucket-shard-index': index,
          'bucket-shard-count': 2,
          'bucket-solo': '**/golden_test.dart',
        },
      );
    }

    bucketTest('routes an unreset surface-mutating file to solo', () {
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
    }, args: {'experimental-bucket': true, 'bucket-count': 1});

    bucketTest('covers only the given files when constructed with only', () {
      flutterPackage();
      writeTestFile('test/a_test.dart', safeContent);
      writeTestFile('test/b_test.dart', safeContent);
      writeTestFile('test/sub/c_test.dart', safeContent);

      final pkg = Package(
        '/project/pubspec.yaml',
        only: {'/project/test/a_test.dart', '/project/test/sub/c_test.dart'},
      );

      expect(
        pkg.bucketPlan!.buckets.single.originalFiles,
        unorderedEquals(['test/a_test.dart', 'test/sub/c_test.dart']),
      );
    }, args: {'experimental-bucket': true, 'bucket-count': 1});

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

    String generatedBucket(Package pkg) {
      final bucket = pkg.bucketPlan!.buckets.single;
      return bucketFs.file('/project/${bucket.file}').readAsStringSync();
    }

    bucketTest(
      'clears HttpOverrides around plain files bucketed with widget files',
      () {
        final pkg = flutterPackage();
        writeTestFile('test/a_test.dart', plainContent);
        writeTestFile('test/b_test.dart', safeContent);

        final generated = generatedBucket(pkg);

        expect(generated, contains("import 'dart:io' show HttpOverrides;"));
        expect(generated, contains('show group, setUpAll, tearDownAll;'));
        expect(
          generated,
          contains(
            "group('test/a_test.dart', () { "
            '_clearHttpOverrides(); _i0.main(); });',
          ),
        );
        expect(
          generated,
          contains("group('test/b_test.dart', () { _i1.main(); });"),
        );
        expect(
          generated,
          contains('''
void _clearHttpOverrides() {
  HttpOverrides? saved;
  setUpAll(() {
    saved = HttpOverrides.current;
    HttpOverrides.global = null;
  });
  tearDownAll(() => HttpOverrides.global = saved);
}
'''),
        );
      },
      args: {'experimental-bucket': true, 'bucket-count': 1},
    );

    bucketTest(
      'leaves HttpOverrides alone in a bucket of only widget files',
      () {
        final pkg = flutterPackage();
        writeTestFile('test/a_test.dart', safeContent);
        writeTestFile('test/b_test.dart', safeContent);

        final generated = generatedBucket(pkg);

        expect(generated, isNot(contains('HttpOverrides')));
        expect(
          generated,
          contains(
            "import 'package:flutter_test/flutter_test.dart' show group;",
          ),
        );
      },
      args: {'experimental-bucket': true, 'bucket-count': 1},
    );

    bucketTest(
      'leaves HttpOverrides alone in a bucket of only plain files',
      () {
        final pkg = flutterPackage();
        writeTestFile('test/a_test.dart', plainContent);
        writeTestFile('test/b_test.dart', plainContent);

        expect(generatedBucket(pkg), isNot(contains('HttpOverrides')));
      },
      args: {'experimental-bucket': true, 'bucket-count': 1},
    );

    bucketTest(
      'leaves HttpOverrides alone when the tests are compiled for the web',
      () {
        final pkg = flutterPackage();
        writeTestFile('test/a_test.dart', plainContent);
        writeTestFile('test/b_test.dart', safeContent);

        expect(generatedBucket(pkg), isNot(contains('dart:io')));
      },
      args: {
        'experimental-bucket': true,
        'bucket-count': 1,
        'platform': 'chrome',
      },
    );

    group('library annotations', () {
      const annotatedContent = """
@Tags(['slow'])
@Timeout(Duration(seconds: 45))
@OnPlatform({'windows': Skip('no symlinks')})
library;

import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('renders', (tester) async {});
}
""";

      bucketTest("passes a file's library annotations to its group", () {
        final pkg = flutterPackage();
        writeTestFile('test/a_test.dart', annotatedContent);
        writeTestFile('test/b_test.dart', safeContent);

        final generated = generatedBucket(pkg);

        expect(
          generated,
          contains(
            "_test.group('test/a_test.dart', () { _i0.main(); }, "
            "tags: ['slow'], "
            'timeout: Timeout(Duration(seconds: 45)), '
            "onPlatform: {'windows': Skip('no symlinks')});",
          ),
        );
        expect(
          generated,
          contains("group('test/b_test.dart', () { _i1.main(); });"),
        );
        expect(
          generated,
          contains(
            "import 'package:flutter_test/flutter_test.dart' "
            'show group, setUp;',
          ),
        );
        expect(
          generated,
          contains(
            "import 'package:test_api/scaffolding.dart' as _test show group;",
          ),
        );
        expect(
          generated,
          contains(
            "import 'package:test_api/scaffolding.dart' show Skip, Timeout;",
          ),
        );
        expect(
          generated,
          contains('// ignore_for_file: depend_on_referenced_packages'),
        );
        expect(generated, contains('void main() {\n  setUp(() {});\n'));
      }, args: {'experimental-bucket': true, 'bucket-count': 1});

      bucketTest(
        'passes @TestOn, @Skip and @Retry, and imports only what they use',
        () {
          final pkg = flutterPackage();
          writeTestFile('test/a_test.dart', """
@TestOn('vm')
@Skip()
@Retry(2)
library;

$safeContent""");

          final generated = generatedBucket(pkg);

          expect(
            generated,
            contains(
              "_test.group('test/a_test.dart', () { _i0.main(); }, "
              "testOn: 'vm', skip: true, retry: 2);",
            ),
          );
          expect(
            generated,
            contains(
              "import 'package:flutter_test/flutter_test.dart' show setUp;",
            ),
          );
          expect(generated, isNot(contains('show Skip')));
          expect(generated, isNot(contains('Timeout')));
        },
        args: {'experimental-bucket': true, 'bucket-count': 1},
      );

      bucketTest('passes annotations in a solo wrapper too', () {
        final pkg = flutterPackage();
        writeTestFile('test/bad_test.dart', """
@Tags(['live'])
library;

$unsafeBindingContent""");

        final solo = pkg.bucketPlan!.buckets.single;
        final generated = bucketFs
            .file('/project/${solo.file}')
            .readAsStringSync();

        expect(
          generated,
          contains(
            "_test.group('test/bad_test.dart', () { _i0.main(); }, "
            "tags: ['live']);",
          ),
        );
      }, args: {'experimental-bucket': true, 'bucket-count': 1});

      bucketTest(
        'passes annotations of a file matching --bucket-solo',
        () {
          final pkg = flutterPackage();
          writeTestFile('test/a_test.dart', annotatedContent);

          final solo = pkg.bucketPlan!.buckets.single;
          final generated = bucketFs
              .file('/project/${solo.file}')
              .readAsStringSync();

          expect(pkg.bucketPlan!.soloFiles, ['test/a_test.dart']);
          expect(generated, contains("tags: ['slow']"));
        },
        args: {
          'experimental-bucket': true,
          'bucket-count': 1,
          'bucket-solo': 'test/a_test.dart',
        },
      );

      bucketTest('keeps annotations alongside cleared HttpOverrides', () {
        final pkg = flutterPackage();
        writeTestFile('test/a_test.dart', """
@Tags(['net'])
library;

$plainContent""");
        writeTestFile('test/b_test.dart', safeContent);

        final generated = generatedBucket(pkg);

        expect(
          generated,
          contains(
            "_test.group('test/a_test.dart', () { "
            '_clearHttpOverrides(); _i0.main(); }, '
            "tags: ['net']);",
          ),
        );
        expect(
          generated,
          contains('show group, setUp, setUpAll, tearDownAll;'),
        );
      }, args: {'experimental-bucket': true, 'bucket-count': 1});

      bucketTest(
        'leaves the wrapper unchanged when no file has annotations',
        () {
          final pkg = flutterPackage();
          writeTestFile('test/a_test.dart', """
import 'package:flutter_test/flutter_test.dart';

@Tags(['not-library'])
void main() {
  testWidgets('renders', (tester) async {});
}
""");

          final generated = generatedBucket(pkg);

          expect(generated, isNot(contains('test_api')));
          expect(generated, isNot(contains('setUp')));
          expect(
            generated,
            contains(
              "import 'package:flutter_test/flutter_test.dart' show group;",
            ),
          );
        },
        args: {'experimental-bucket': true, 'bucket-count': 1},
      );
    });

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

    bucketTest('bucketOriginalFilesFor returns null for unknown files', () {
      final pkg = flutterPackage();
      writeTestFile('test/a_test.dart', safeContent);

      expect(pkg.bucketPlan, isNotNull);
      expect(pkg.bucketOriginalFilesFor('test/not_a_bucket.dart'), isNull);
    }, args: {'experimental-bucket': true, 'bucket-count': 1});

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

    bucketTest('deleteOptimizedTestFile removes generated bucket files', () {
      final pkg = flutterPackage();
      writeTestFile('test/a_test.dart', safeContent);
      writeTestFile('test/b_test.dart', safeContent);

      final bucket = pkg.bucketPlan!.buckets.single;
      expect(bucketFs.file('/project/${bucket.file}').existsSync(), isTrue);

      pkg.deleteOptimizedTestFile();

      expect(bucketFs.file('/project/${bucket.file}').existsSync(), isFalse);
      expect(bucketFs.file('/project/test/a_test.dart').existsSync(), isTrue);
    }, args: {'experimental-bucket': true, 'bucket-count': 1});

    group('with a nested flutter_test_config.dart', () {
      void writeConfig(String relativeDir) {
        writeTestFile('$relativeDir/flutter_test_config.dart', '''
Future<void> testExecutable(Future<void> Function() testMain) => testMain();
''');
      }

      bucketTest('only combines files that share the nearest config', () {
        final pkg = flutterPackage();
        writeConfig('test/feature');
        writeTestFile('test/a_test.dart', safeContent);
        writeTestFile('test/b_test.dart', safeContent);
        writeTestFile('test/feature/c_test.dart', safeContent);
        writeTestFile('test/feature/deep/d_test.dart', safeContent);

        final plan = pkg.bucketPlan!;

        expect(
          plan.buckets.map((b) => b.originalFiles),
          unorderedEquals([
            ['test/a_test.dart', 'test/b_test.dart'],
            ['test/feature/c_test.dart', 'test/feature/deep/d_test.dart'],
          ]),
        );
      }, args: {'experimental-bucket': true, 'bucket-count': 1});

      bucketTest("writes each bucket in its config's directory", () {
        final pkg = flutterPackage();
        writeConfig('test/feature');
        writeTestFile('test/a_test.dart', safeContent);
        writeTestFile('test/feature/deep/d_test.dart', safeContent);

        final plan = pkg.bucketPlan!;
        final files = {
          for (final bucket in plan.buckets)
            bucket.originalFiles.single: bucket.file,
        };

        expect(files['test/a_test.dart'], startsWith('test/.test_optimizer'));
        expect(
          files['test/feature/deep/d_test.dart'],
          startsWith('test/feature/.test_optimizer'),
        );

        final generated = bucketFs
            .file('/project/${files['test/feature/deep/d_test.dart']}')
            .readAsStringSync();

        expect(generated, contains("import 'deep/d_test.dart' as _i0;"));
        expect(
          generated,
          contains(
            "group('test/feature/deep/d_test.dart', () { _i0.main(); });",
          ),
        );
      }, args: {'experimental-bucket': true, 'bucket-count': 4});

      bucketTest("writes a solo wrapper in its config's directory", () {
        final pkg = flutterPackage();
        writeConfig('test/feature');
        writeTestFile('test/feature/bad_test.dart', unsafeBindingContent);

        final solo = pkg.bucketPlan!.buckets.single;

        expect(solo.originalFiles, ['test/feature/bad_test.dart']);
        expect(solo.file, startsWith('test/feature/.test_optimizer_solo'));
      }, args: {'experimental-bucket': true, 'bucket-count': 1});

      bucketTest(
        'keeps files outside test/ away from test/flutter_test_config.dart',
        () {
          final pkg = flutterPackage();
          writeConfig('test');
          writeTestFile('test/a_test.dart', safeContent);
          writeTestFile('integration_test/b_test.dart', safeContent);

          final plan = pkg.bucketPlan!;
          final files = {
            for (final bucket in plan.buckets)
              bucket.originalFiles.single: bucket.file,
          };

          expect(files['test/a_test.dart'], startsWith('test/.test_optimizer'));
          expect(
            files['integration_test/b_test.dart'],
            startsWith('.test_optimizer'),
          );
        },
        args: {'experimental-bucket': true, 'bucket-count': 1},
      );

      bucketTest('gives each config at least one bucket of its share', () {
        final pkg = flutterPackage();
        writeConfig('test/feature');
        for (final name in ['a', 'b', 'c', 'd', 'e', 'f']) {
          writeTestFile('test/${name}_test.dart', safeContent);
        }
        writeTestFile('test/feature/g_test.dart', safeContent);

        final plan = pkg.bucketPlan!;

        expect(
          plan.buckets.map((b) => b.originalFiles),
          unorderedEquals([
            ['test/a_test.dart', 'test/c_test.dart', 'test/e_test.dart'],
            ['test/b_test.dart', 'test/d_test.dart', 'test/f_test.dart'],
            ['test/feature/g_test.dart'],
          ]),
        );
        expect(
          plan.buckets.map((b) => b.file).toSet(),
          hasLength(plan.buckets.length),
        );
      }, args: {'experimental-bucket': true, 'bucket-count': 2});

      bucketTest(
        'deleteOptimizedTestFile removes wrappers in subdirectories',
        () {
          final pkg = flutterPackage();
          writeConfig('test/feature');
          writeConfig('test/other');
          writeTestFile('test/a_test.dart', safeContent);
          writeTestFile('test/feature/b_test.dart', safeContent);
          writeTestFile('test/other/bad_test.dart', unsafeBindingContent);

          final wrappers = [
            for (final bucket in pkg.bucketPlan!.buckets)
              bucketFs.file('/project/${bucket.file}'),
          ];
          expect(wrappers, hasLength(3));
          expect(wrappers.every((f) => f.existsSync()), isTrue);

          // A fresh Package, as `sip test clean` would use: it has no plan
          // telling it where the wrappers went.
          Package('/project/pubspec.yaml').deleteOptimizedTestFile();

          expect(wrappers.where((f) => f.existsSync()), isEmpty);
          expect(
            bucketFs.file('/project/test/feature/b_test.dart').existsSync(),
            isTrue,
          );
          expect(
            bucketFs
                .file('/project/test/feature/flutter_test_config.dart')
                .existsSync(),
            isTrue,
          );
        },
        args: {'experimental-bucket': true, 'bucket-count': 1},
      );

      bucketTest('deleteOptimizedTestFile leaves nested packages alone', () {
        final pkg = flutterPackage();
        writeTestFile('packages/inner/pubspec.yaml', 'name: inner\n');
        writeTestFile('packages/inner/test/.test_optimizer_bucket_0.dart', '');

        pkg.deleteOptimizedTestFile();

        expect(
          bucketFs
              .file(
                '/project/packages/inner/test/.test_optimizer_bucket_0.dart',
              )
              .existsSync(),
          isTrue,
        );
      });
    });
  });
}

class _MockFindFile extends Mock implements FindFile {}

class _MockPubspecLock extends Mock implements PubspecLock {}

class _MockScriptsYaml extends Mock implements ScriptsYaml {}
