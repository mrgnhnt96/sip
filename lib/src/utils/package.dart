import 'dart:convert';

import 'package:file/file.dart';
import 'package:glob/glob.dart';
import 'package:path/path.dart' as p;
import 'package:sip_cli/src/deps/args.dart';
import 'package:sip_cli/src/deps/find_file.dart';
import 'package:sip_cli/src/deps/fs.dart';
import 'package:sip_cli/src/deps/platform.dart';
import 'package:sip_cli/src/deps/pubspec_lock.dart';
import 'package:sip_cli/src/deps/pubspec_yaml.dart';
import 'package:sip_cli/src/domain/executables.dart';
import 'package:sip_cli/src/domain/test_bucket_plan.dart';
import 'package:sip_cli/src/domain/test_config.dart';
import 'package:sip_cli/src/utils/flutter_test_safety.dart';
import 'package:sip_cli/src/utils/list_ext.dart';
import 'package:yaml/yaml.dart';

class Package {
  Package(this._pubspecYaml, {Set<String>? only}) : _only = only;

  factory Package.nearest() {
    final yaml = pubspecYaml.nearest();

    if (yaml == null) {
      throw Exception('No pubspec.yaml file found');
    }

    return Package(yaml);
  }

  final String _pubspecYaml;

  /// The canonical paths (`fs.path.canonicalize`) of the only test files to
  /// run, when the files were given on the command line instead of
  /// discovered under [path]. Everything built from [testFiles] -- the
  /// bucket plan included -- then covers just these.
  final Set<String>? _only;

  String get pubspec => _pubspecYaml;

  String? _tool;
  bool? _isFlutter;
  bool get isFlutter {
    if (_isFlutter case final bool isFlutter) {
      return isFlutter;
    }

    final nestedLock = pubspecLock.findIn(path);
    final contents = findFile.retrieveContent(nestedLock ?? _pubspecYaml);

    return _isFlutter = contents?.contains('flutter') ?? false;
  }

  bool get isDart => !isFlutter;

  String? _name;
  String get name {
    if (_name case final name?) {
      return name;
    }

    final content = findFile.retrieveContent(this.pubspec);
    final pubspec = switch (content) {
      null => <String, dynamic>{},
      final content => jsonDecode(jsonEncode(loadYaml(content))),
    };

    final name = switch (pubspec) {
      {'name': final String name} => name,
      _ => null,
    };

    if (name == null) {
      throw Exception('No name found in pubspec.yaml');
    }

    return _name = name;
  }

  String get path => fs.path.dirname(_pubspecYaml);
  String get relativePath =>
      fs.path.relative(path, from: fs.currentDirectory.path);

  String get tool {
    if (_tool case final tool?) {
      return tool;
    }

    final executables = Executables.load();

    return _tool = switch (isFlutter) {
      true => executables.flutter ?? 'flutter',
      false => executables.dart ?? 'dart',
    };
  }

  bool get hasTests {
    return testFiles.isNotEmpty;
  }

  bool? _isPartOfWorkspace;
  bool get isPartOfWorkspace {
    if (_isPartOfWorkspace case final isPartOfWorkspace?) {
      return isPartOfWorkspace;
    }

    final content = findFile.retrieveContent(this.pubspec);

    final pubspec = switch (content) {
      null => <String, dynamic>{},
      final content => jsonDecode(jsonEncode(loadYaml(content))),
    };

    return _isPartOfWorkspace = switch (pubspec) {
      {'resolution': 'workspace'} => true,
      _ => false,
    };
  }

  bool? _isRootOfWorkspace;
  bool get isRootOfWorkspace {
    if (_isRootOfWorkspace case final isRootOfWorkspace?) {
      return isRootOfWorkspace;
    }

    final content = findFile.retrieveContent(this.pubspec);

    final pubspec = switch (content) {
      null => <String, dynamic>{},
      final content => jsonDecode(jsonEncode(loadYaml(content))),
    };

    return _isRootOfWorkspace = switch (pubspec) {
      {'workspace': Object()} => true,
      _ => false,
    };
  }

  bool shouldInclude({required bool dartOnly, required bool flutterOnly}) {
    if (dartOnly ^ flutterOnly) {
      if (dartOnly && isFlutter) {
        return false;
      } else if (flutterOnly && isDart) {
        return false;
      }
    }
    return true;
  }

  /// The test files this package runs: the given ones when constructed with
  /// `only`, otherwise every `*_test.dart` under `test/`. Like `flutter test`
  /// and `dart test` without paths, discovery leaves out `integration_test/`,
  /// `example/` and nested packages, which do not run on the host.
  List<String> get testFiles {
    // Given files may sit anywhere in the package.
    final root = _only == null ? fs.path.join(path, 'test') : path;
    if (!fs.directory(root).existsSync()) return [];

    final glob = Glob('**_test.dart', recursive: true);
    final results = glob.listFileSystemSync(fs, followLinks: false, root: root);

    return [
      for (final file in results.whereType<File>())
        if (!file.basename.startsWith(_optimizedFilePrefix))
          if (_only?.contains(fs.path.canonicalize(file.path)) ?? true)
            file.path,
    ];
  }

  List<String> get testDirs {
    final dirs = <String>{};

    for (final file in testFiles) {
      dirs.add(fs.path.dirname(file));
    }

    return dirs.toList();
  }

  /// Splits the tests into groups of the given [args['slice']] size
  /// by separating [testDirs]
  ///
  /// In bucket mode this always returns a single group containing every
  /// bucket/solo file this invocation is responsible for (the whole plan,
  /// or just this shard's slice of it) as multiple arguments to ONE `flutter
  /// test` invocation -- never one invocation per bucket. `flutter test`
  /// already runs each file argument in its own isolate and schedules them
  /// concurrently itself; dispatching one OS process per bucket instead
  /// would pay Flutter's fixed per-invocation bootstrap/native-asset-build
  /// cost once per bucket instead of once per shard, and multiple such
  /// processes racing on the same package's `build/native_assets` directory
  /// is a confirmed real crash (see `--experimental-bucket` validation
  /// notes).
  List<List<String>> get testGroups {
    if (bucketPlan case final plan?) {
      final units = [for (final bucket in plan.buckets) bucket.file];

      final shardIndex = bucketShardIndex;
      final shardCount = bucketShardCount;

      final selected = (shardIndex != null && shardCount != null)
          ? units.shard(index: shardIndex, count: shardCount)
          : units;

      if (selected.isEmpty) return [];

      return [selected];
    }

    if (optimizedTestFile case final file?) {
      return [
        [fs.path.relative(file, from: path)],
      ];
    }

    final slice = args.getOrNull<int>('slice');

    final files = testDirs;

    if (slice != null) {
      return files.chunked(slice);
    }

    return [files];
  }

  static const _optimizedFilePrefix = '.test_optimizer';

  String get _optimizedTestFilePath =>
      fs.path.join(path, 'test', '$_optimizedFilePrefix.dart');

  String _bucketFileName(int index) =>
      '${_optimizedFilePrefix}_bucket_$index.dart';

  String _soloWrapperFileName(int index) =>
      '${_optimizedFilePrefix}_solo_$index.dart';

  /// Whether experimental Flutter test-file bucketing is enabled for this
  /// package. Only ever applies to Flutter packages -- Dart packages keep
  /// today's always-on [optimizedTestFile] behavior unchanged, flag or no
  /// flag.
  bool get experimentalBucketEnabled =>
      isFlutter && args.get<bool>('experimental-bucket', defaultValue: false);

  /// How many combined bucket files to generate from the combinable
  /// (non-solo) test files. Defaults to the number of available processors.
  int get bucketCount {
    final requested = args.getOrNull<int>('bucket-count');
    if (requested != null && requested > 0) return requested;
    return platform.numberOfProcessors;
  }

  /// Globs of test files to keep out of combined buckets, from every
  /// `--bucket-solo` flag and `(test): bucket-solo:` in `scripts.yaml`.
  /// They match paths relative to the package root, written with `/`.
  List<String> get bucketSoloGlobs => [
    ...TestConfig.globList(args.getOrNull<Object>('bucket-solo')),
    ...TestConfig.load().bucketSolo,
  ];

  int? get bucketShardIndex => args.getOrNull<int>('bucket-shard-index');
  int? get bucketShardCount => args.getOrNull<int>('bucket-shard-count');

  /// Whether the tests are compiled for the web (`--platform chrome`), where
  /// a generated wrapper cannot import `dart:io`.
  bool get _targetsWeb => switch (args.getOrNull<String>('platform')) {
    null || 'tester' || 'vm' => false,
    _ => true,
  };

  TestBucketPlan? _bucketPlan;

  /// Plans (and generates on disk) how this package's Flutter test files
  /// should be bucketed, or `null` when [experimentalBucketEnabled] is
  /// false or there are no test files.
  ///
  /// Every combinable file is round-robin distributed across [bucketCount]
  /// generated combined-bucket files. `flutter test` applies the
  /// `flutter_test_config.dart` nearest to the file it runs, so files are
  /// only combined with files that share theirs, and each wrapper is written
  /// in that config's directory (`test/` for files without one).
  ///
  /// Files that match one of [bucketSoloGlobs], or fail either
  /// [FlutterTestSafety] pre-check, are quarantined -- reported via
  /// [TestBucketPlan.soloFiles]/[TestBucketPlan.soloReasons], and placed by
  /// the same config rule -- but are
  /// still generated as their own trivial single-file wrapper (a "bucket of
  /// one") alongside the real combined buckets in [TestBucketPlan.buckets],
  /// rather than being dispatched via their raw original path. This keeps
  /// every dispatched unit uniformly identifiable by its injected
  /// `group('<original file>', ...)` name no matter how many other file
  /// arguments end up in the same `flutter test`/`dart test` invocation --
  /// confirmed empirically that `dart test`'s CI reporter only prefixes
  /// results with the *physical* file path once more than one file is
  /// passed on the command line, which would otherwise make a solo file
  /// unidentifiable (and therefore always look "missing") whenever it
  /// shares an invocation with anything else.
  TestBucketPlan? get bucketPlan {
    if (_bucketPlan case final plan?) {
      return plan;
    }

    if (!experimentalBucketEnabled) return null;

    final files = testFiles;
    if (files.isEmpty) return null;

    final combinable = <String>[];
    final solo = <String>[];
    final soloReasons = <String, String>{};
    final bindingFiles = <String>{};

    final soloGlobs = [
      for (final pattern in bucketSoloGlobs) Glob(pattern, context: p.posix),
    ];

    for (final filePath in files) {
      final relativeToPackage = fs.path.relative(filePath, from: path);
      final posixPath = relativeToPackage.replaceAll(fs.path.separator, '/');

      final soloGlob = soloGlobs.where((e) => e.matches(posixPath)).firstOrNull;

      if (soloGlob != null) {
        solo.add(relativeToPackage);
        soloReasons[relativeToPackage] =
            'matches bucket-solo "${soloGlob.pattern}"';
        continue;
      }

      final content = fs.file(filePath).readAsStringSync();

      if (FlutterTestSafety.mayInitializeTestBinding(content)) {
        bindingFiles.add(relativeToPackage);
      }

      if (FlutterTestSafety.isCombinable(content)) {
        combinable.add(relativeToPackage);
      } else {
        solo.add(relativeToPackage);
        soloReasons[relativeToPackage] = FlutterTestSafety.soloReason(content);
      }
    }

    combinable.sort();
    solo.sort();

    final k = combinable.isEmpty ? 0 : bucketCount.clamp(1, combinable.length);

    // A wrapper must sit where `flutter test` picks the same
    // flutter_test_config.dart as the files it combines, so only files
    // sharing a wrapper directory are combined. Each directory gets its
    // share of the k buckets, and at least one.
    final combinableByDir = <String, List<String>>{};
    for (final file in combinable) {
      combinableByDir.putIfAbsent(_wrapperDirFor(file), () => []).add(file);
    }

    final bucketedFiles = <(String, List<String>)>[];
    for (final dir in combinableByDir.keys.toList()..sort()) {
      final dirFiles = combinableByDir[dir]!;
      final dirK = (k * dirFiles.length / combinable.length).ceil().clamp(
        1,
        dirFiles.length,
      );

      final dirBuckets = List.generate(dirK, (_) => <String>[]);
      for (var i = 0; i < dirFiles.length; i++) {
        dirBuckets[i % dirK].add(dirFiles[i]);
      }

      bucketedFiles.addAll([for (final files in dirBuckets) (dir, files)]);
    }

    final buckets = <TestBucket>[
      for (final (b, (dir, originalFiles)) in bucketedFiles.indexed)
        _writeWrapperFile(
          wrapperDirPath: dir,
          fileName: _bucketFileName(b),
          originalFiles: originalFiles,
          bindingFiles: bindingFiles,
        ),
      for (final (s, soloFile) in solo.indexed)
        _writeWrapperFile(
          wrapperDirPath: _wrapperDirFor(soloFile),
          fileName: _soloWrapperFileName(s),
          originalFiles: [soloFile],
          bindingFiles: bindingFiles,
        ),
    ];

    return _bucketPlan = TestBucketPlan(
      buckets: buckets,
      soloFiles: solo,
      soloReasons: soloReasons,
    );
  }

  static const _testConfigFileName = 'flutter_test_config.dart';

  final _testConfigDirs = <String, String?>{};

  /// The directory of the `flutter_test_config.dart` that `flutter test`
  /// applies to a test file in [dir], or `null` when none applies.
  ///
  /// This mirrors flutter_tools: it walks up from the file's directory and
  /// stops at the first config, or at the first directory holding a
  /// `pubspec.yaml`, whichever comes first.
  String? _testConfigDirFor(String dir) {
    if (_testConfigDirs.containsKey(dir)) return _testConfigDirs[dir];

    final String? configDir;
    if (fs.file(fs.path.join(dir, _testConfigFileName)).existsSync()) {
      configDir = dir;
    } else if (fs.file(fs.path.join(dir, 'pubspec.yaml')).existsSync() ||
        fs.path.dirname(dir) == dir) {
      configDir = null;
    } else {
      configDir = _testConfigDirFor(fs.path.dirname(dir));
    }

    return _testConfigDirs[dir] = configDir;
  }

  /// The directory to write a wrapper for the package-relative test [file]
  /// in, chosen so that `flutter test` applies the same
  /// `flutter_test_config.dart` to the wrapper as it would to [file].
  ///
  /// That is the config's own directory. When no config applies, it is
  /// `test/`, or the package root if `test/` has a config of its own.
  String _wrapperDirFor(String file) {
    final fileDir = fs.path.dirname(fs.path.join(path, file));

    if (_testConfigDirFor(fileDir) case final configDir?) return configDir;

    final testDirPath = fs.path.join(path, 'test');
    if (_testConfigDirFor(testDirPath) == null) return testDirPath;

    return path;
  }

  TestBucket _writeWrapperFile({
    required String wrapperDirPath,
    required String fileName,
    required List<String> originalFiles,
    required Set<String> bindingFiles,
  }) {
    // The flutter test binding replaces HttpOverrides.global with a mock that
    // answers every request with 400 (see
    // FlutterTestSafety.mayInitializeTestBinding). When a wrapper combines a
    // file that initializes the binding with one that doesn't, the latter's
    // groups run with the override cleared, as they would alone. `dart:io`
    // doesn't compile for the web, where HttpOverrides doesn't exist anyway.
    final isolateHttpOverrides =
        !_targetsWeb &&
        originalFiles.any(bindingFiles.contains) &&
        !originalFiles.every(bindingFiles.contains);

    final wrapperFile = fs.file(fs.path.join(wrapperDirPath, fileName))
      ..createSync(recursive: true);

    String import((int index, String file) data) {
      final (index, file) = data;
      final importPath = fs.path
          .relative(fs.path.join(path, file), from: wrapperDirPath)
          .replaceAll(fs.path.separator, '/');
      return "import '$importPath' as _i$index;";
    }

    String group((int index, String file) data) {
      final (index, file) = data;
      final groupName = file.replaceAll(fs.path.separator, '/');
      if (isolateHttpOverrides && !bindingFiles.contains(file)) {
        return "group('$groupName', () { "
            '_clearHttpOverrides(); '
            '_i$index.main(); });';
      }

      return "group('$groupName', () { _i$index.main(); });";
    }

    final header = isolateHttpOverrides
        ? """
import 'dart:io' show HttpOverrides;

import 'package:flutter_test/flutter_test.dart'
    show group, setUpAll, tearDownAll;"""
        : "import 'package:flutter_test/flutter_test.dart' show group;";

    const clearHttpOverrides = '''

/// Runs the enclosing group without the flutter test binding's mock
/// HttpOverrides, which another file in this bucket may have installed.
void _clearHttpOverrides() {
  HttpOverrides? saved;
  setUpAll(() {
    saved = HttpOverrides.current;
    HttpOverrides.global = null;
  });
  tearDownAll(() => HttpOverrides.global = saved);
}
''';

    final content =
        '''
// GENERATED FILE. DO NOT COMMIT.
// Produced by sip's --experimental-bucket flutter test optimizer.
$header
${originalFiles.indexed.map(import).join('\n')}

void main() {
  ${originalFiles.indexed.map(group).join('\n  ')}
}
${isolateHttpOverrides ? clearHttpOverrides : ''}''';

    wrapperFile.writeAsStringSync(content);

    return TestBucket(
      file: fs.path.relative(wrapperFile.path, from: path),
      originalFiles: originalFiles,
    );
  }

  /// The original (package-relative) files combined into the generated
  /// bucket [file] (also package-relative), or `null` if [file] isn't a
  /// known bucket from [bucketPlan].
  List<String>? bucketOriginalFilesFor(String file) {
    for (final bucket in bucketPlan?.buckets ?? const <TestBucket>[]) {
      if (bucket.file == file) return bucket.originalFiles;
    }

    return null;
  }

  /// For a `testGroups` unit list (bucket files and/or solo files, as
  /// produced for one `flutter test` invocation), returns one original-files
  /// group per unit: a bucket's [TestBucket.originalFiles], or a
  /// single-item group for a solo file. Used by the fallback-on-failure
  /// mechanism to check coverage and discard/re-run at the right
  /// granularity -- per bucket (protecting against silent isolate-sharing
  /// corruption within that one combined file) or per solo file, never the
  /// whole shard's command at once.
  List<List<String>> bucketFileGroupsFor(List<String> units) {
    return [
      for (final unit in units) bucketOriginalFilesFor(unit) ?? [unit],
    ];
  }

  String? _optimizedFile;
  String? get optimizedTestFile {
    if (_optimizedFile case final optimizedFile?) {
      return optimizedFile;
    }

    // we only optimize dart tests
    if (!isDart) return null;

    final files = testFiles;
    if (files.isEmpty) return null;

    final file = fs.file(_optimizedTestFilePath)..createSync(recursive: true);

    String test((int index, String file) data) {
      final (index, file) = data;
      return "group('$file', () { _i$index.main(); });";
    }

    String import((int index, String file) data) {
      final (index, file) = data;
      return "import '$file' as _i$index;";
    }

    final content =
        '''
import 'dart:async';

import 'package:test/test.dart';
${files.indexed.map(import).join('\n')}

void main() {
  ${files.indexed.map(test).join('\n  ')}
}
''';

    file.writeAsStringSync(content);

    return _optimizedFile = file.path;
  }

  /// Deletes every file sip generated for this package's tests: the
  /// optimized file and the bucket wrappers, which may sit in any directory
  /// holding a `flutter_test_config.dart` (see [bucketPlan]).
  ///
  /// Directories of nested packages are left alone; their own [Package]
  /// cleans them.
  void deleteOptimizedTestFile() {
    _bucketPlan = null;

    void clean(Directory dir) {
      for (final entity in dir.listSync(followLinks: false)) {
        switch (entity) {
          case File() when entity.basename.startsWith(_optimizedFilePrefix):
            entity.deleteSync();
          case Directory()
              when !fs
                  .file(fs.path.join(entity.path, 'pubspec.yaml'))
                  .existsSync():
            clean(entity);
        }
      }
    }

    final root = fs.directory(path);
    if (!root.existsSync()) return;

    clean(root);
  }
}
