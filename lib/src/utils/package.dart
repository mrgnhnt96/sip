import 'dart:convert';

import 'package:file/file.dart';
import 'package:glob/glob.dart';
import 'package:sip_cli/src/deps/args.dart';
import 'package:sip_cli/src/deps/find_file.dart';
import 'package:sip_cli/src/deps/fs.dart';
import 'package:sip_cli/src/deps/platform.dart';
import 'package:sip_cli/src/deps/pubspec_lock.dart';
import 'package:sip_cli/src/deps/pubspec_yaml.dart';
import 'package:sip_cli/src/domain/executables.dart';
import 'package:sip_cli/src/domain/test_bucket_plan.dart';
import 'package:sip_cli/src/utils/flutter_test_safety.dart';
import 'package:sip_cli/src/utils/list_ext.dart';
import 'package:yaml/yaml.dart';

class Package {
  Package(this._pubspecYaml);

  factory Package.nearest() {
    final yaml = pubspecYaml.nearest();

    if (yaml == null) {
      throw Exception('No pubspec.yaml file found');
    }

    return Package(yaml);
  }

  final String _pubspecYaml;

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

  List<String> get testFiles {
    final glob = Glob('**/*_test.dart', recursive: true);
    final results = glob.listFileSystemSync(fs, followLinks: false, root: path);

    return [
      for (final file in results.whereType<File>())
        if (!file.basename.startsWith(_optimizedFilePrefix)) file.path,
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

  int? get bucketShardIndex => args.getOrNull<int>('bucket-shard-index');
  int? get bucketShardCount => args.getOrNull<int>('bucket-shard-count');

  TestBucketPlan? _bucketPlan;

  /// Plans (and generates on disk) how this package's Flutter test files
  /// should be bucketed, or `null` when [experimentalBucketEnabled] is
  /// false or there are no test files.
  ///
  /// Every combinable file is round-robin distributed across [bucketCount]
  /// generated combined-bucket files under `test/`. Files that fail either
  /// [FlutterTestSafety] pre-check are quarantined -- reported via
  /// [TestBucketPlan.soloFiles]/[TestBucketPlan.soloReasons] -- but are
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

    for (final filePath in files) {
      final content = fs.file(filePath).readAsStringSync();
      final relativeToPackage = fs.path.relative(filePath, from: path);

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

    final bucketedFiles = List.generate(k, (_) => <String>[]);
    for (var i = 0; i < combinable.length; i++) {
      bucketedFiles[i % k].add(combinable[i]);
    }

    final testDirPath = fs.path.join(path, 'test');

    final buckets = <TestBucket>[
      for (final (b, originalFiles) in bucketedFiles.indexed)
        if (originalFiles.isNotEmpty)
          _writeWrapperFile(
            testDirPath: testDirPath,
            fileName: _bucketFileName(b),
            originalFiles: originalFiles,
          ),
      for (final (s, soloFile) in solo.indexed)
        _writeWrapperFile(
          testDirPath: testDirPath,
          fileName: _soloWrapperFileName(s),
          originalFiles: [soloFile],
        ),
    ];

    return _bucketPlan = TestBucketPlan(
      buckets: buckets,
      soloFiles: solo,
      soloReasons: soloReasons,
    );
  }

  TestBucket _writeWrapperFile({
    required String testDirPath,
    required String fileName,
    required List<String> originalFiles,
  }) {
    final wrapperFile = fs.file(fs.path.join(testDirPath, fileName))
      ..createSync(recursive: true);

    String import((int index, String file) data) {
      final (index, file) = data;
      final importPath = fs.path
          .relative(fs.path.join(path, file), from: testDirPath)
          .replaceAll(fs.path.separator, '/');
      return "import '$importPath' as _i$index;";
    }

    String group((int index, String file) data) {
      final (index, file) = data;
      final groupName = file.replaceAll(fs.path.separator, '/');
      return "group('$groupName', () { _i$index.main(); });";
    }

    final content =
        '''
// GENERATED FILE. DO NOT COMMIT.
// Produced by sip's --experimental-bucket flutter test optimizer.
import 'package:flutter_test/flutter_test.dart' show group;
${originalFiles.indexed.map(import).join('\n')}

void main() {
  ${originalFiles.indexed.map(group).join('\n  ')}
}
''';

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

  void deleteOptimizedTestFile() {
    _bucketPlan = null;

    final testDir = fs.directory(fs.path.join(path, 'test'));
    if (!testDir.existsSync()) return;

    for (final entity in testDir.listSync(followLinks: false).toList()) {
      if (entity is! File) continue;
      if (!entity.basename.startsWith(_optimizedFilePrefix)) continue;

      entity.deleteSync();
    }
  }
}
