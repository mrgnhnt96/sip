import 'package:file/file.dart';
import 'package:glob/glob.dart';
import 'package:mason_logger/mason_logger.dart';
import 'package:sip_cli/src/deps/fs.dart';
import 'package:sip_cli/src/deps/logger.dart';
import 'package:sip_cli/src/deps/pubspec_yaml.dart';
import 'package:sip_cli/src/deps/script_runner.dart';
import 'package:sip_cli/src/domain/package_to_test.dart';
import 'package:sip_cli/src/domain/script_to_run.dart';
import 'package:sip_cli/src/domain/testable.dart';
import 'package:sip_cli/src/utils/determine_flutter_or_dart.dart';
import 'package:sip_cli/src/utils/write_optimized_test_file.dart';

abstract mixin class TesterMixin {
  const TesterMixin();

  static const String optimizedTestBasename = '.test_optimizer';

  void warnDartOrFlutterTests({
    required bool isFlutterOnly,
    required bool isDartOnly,
  }) {
    if (isDartOnly || isFlutterOnly) {
      if (isDartOnly && !isFlutterOnly) {
        logger.info('Running only dart tests');
      } else if (isFlutterOnly && !isDartOnly) {
        logger.info('Running only flutter tests');
      } else {
        logger.info('Running both dart and flutter tests');
      }
    }
  }

  /// This method is used to get the test directories and the tools
  /// to run the tests
  ///
  /// It returns a map of test directories and the tools to run the tests
  (
    (List<String> testDirs, Map<String, DetermineFlutterOrDart> dirTools)?,
    ExitCode? exitCode,
  )
  getTestDirs(
    Iterable<String> pubspecs, {
    required bool isFlutterOnly,
    required bool isDartOnly,
  }) {
    final testDirs = <String>[];
    final dirTools = <String, DetermineFlutterOrDart>{};

    logger.detail(
      'Found ${pubspecs.length} pubspecs, checking for test directories',
    );
    for (final pubspec in pubspecs) {
      final projectRoot = fs.path.dirname(pubspec);
      final testDirectory = fs.path.join(projectRoot, 'test');

      if (!fs.directory(testDirectory).existsSync()) {
        logger.detail(
          'No test directory found in ${fs.path.relative(projectRoot)}',
        );
        continue;
      }

      final tool = DetermineFlutterOrDart(pubspec);

      // we only care checking for flutter or
      // dart tests if we are not running both
      if (isFlutterOnly ^ isDartOnly) {
        if (tool.isFlutter && isDartOnly) {
          continue;
        }

        if (tool.isDart && isFlutterOnly) {
          continue;
        }
      }

      testDirs.add(testDirectory);
      dirTools[testDirectory] = tool;
    }

    if (testDirs.isEmpty) {
      var forTool = '';

      if (isFlutterOnly ^ isDartOnly) {
        forTool = ' ';
        forTool += isDartOnly ? 'dart' : 'flutter';
      }
      logger.err('No $forTool tests found');
      return (null, ExitCode.success);
    }

    return ((testDirs, dirTools), null);
  }

  Iterable<PackageToTest> prepareOptimizedFilesFromDirs(
    List<String> testDirs,
    Map<String, DetermineFlutterOrDart> dirTools,
  ) sync* {
    final glob = Glob(fs.path.join('**_test.dart'));

    for (final testDir in testDirs) {
      final tool = dirTools[testDir];
      if (tool == null) continue;

      final packageToTest = PackageToTest(tool: tool, packagePath: testDir);

      if (tool.isFlutter) {
        yield packageToTest;
        continue;
      }

      final allTestFiles = glob.listFileSystemSync(
        fs,
        followLinks: false,
        root: testDir,
      );

      final testFiles = omitOptimizedTest(allTestFiles);

      if (testFiles.isEmpty) {
        continue;
      }

      final optimizedPath = writeOptimizedFile(testFiles, testDir: testDir);

      packageToTest.optimizedPath = optimizedPath;

      yield packageToTest;
    }
  }

  Iterable<String> omitOptimizedTest(List<FileSystemEntity> allFiles) sync* {
    for (final file in allFiles) {
      if (file is! File) continue;

      final fileName = fs.path.basename(file.path);

      if (fileName.contains(optimizedTestBasename)) {
        continue;
      }

      yield file.path;
    }
  }

  /// The [files] param's key is the value of the type of test
  ///
  /// The base values for this are `dart` for dart tests and `flutter`
  /// for flutter tests.
  ///
  /// When these values are different, it is because flutter has specific
  /// tests to be run. Such as `LiveTestWidgetsFlutterBinding`, the value would
  /// be `live`
  String writeOptimizedFile(Iterable<String> files, {required String testDir}) {
    ({String packageName, String barrelFile})? exportFile;

    if (pubspecYaml.parse()?['name'] case final String packageName) {
      final possibleNames = [packageName, fs.currentDirectory.basename];

      for (final name in possibleNames) {
        if (fs.path.join('lib', '$name.dart') case final path
            when fs.file(path).existsSync()) {
          exportFile = (packageName: packageName, barrelFile: '$name.dart');
        }
      }
    }

    final optimizedPath = fs.path.join(testDir, '$optimizedTestBasename.dart');
    fs.file(optimizedPath).createSync(recursive: true);

    final testDirs = files.map(
      (e) => Testable(absolute: e, optimizedPath: optimizedPath),
    );

    final content = writeOptimizedTestFile(testDirs, barrelFile: exportFile);

    fs.file(optimizedPath).writeAsStringSync(content);

    return optimizedPath;
  }

  String packageRootFor(String filePath) {
    final parts = fs.path.split(filePath);

    String root;
    if (parts.contains('test')) {
      root = parts.sublist(0, parts.indexOf('test')).join(fs.path.separator);
    } else if (parts.contains('lib')) {
      root = parts.sublist(0, parts.indexOf('lib')).join(fs.path.separator);
    } else {
      if (fs.isFileSync(filePath)) {
        root = fs.path.basename(fs.path.dirname(filePath));
      } else {
        root = fs.path.basename(filePath);
      }
    }

    if (root.isEmpty) {
      root = '.';
    }

    return root;
  }

  List<Runnable> getCommandsToRun(
    Iterable<PackageToTest> packagesToTest, {
    required List<String> flutterArgs,
    required List<String> dartArgs,
    bool bail = false,
  }) {
    Iterable<Runnable> create() sync* {
      for (final packageToTest in packagesToTest) {
        yield createTestCommand(
          projectRoot: packageToTest.packagePath,
          relativeProjectRoot: packageRootFor(
            fs.path.relative(packageToTest.packagePath),
          ),
          pathToProjectRoot: fs.path.dirname(
            fs.path.relative(packageToTest.packagePath),
          ),
          flutterArgs: flutterArgs,
          tool: packageToTest.tool,
          dartArgs: dartArgs,
          tests: [
            if (packageToTest.optimizedPath case final test?
                when packageToTest.tool.isDart)
              fs.path.relative(test, from: packageToTest.packagePath),
          ],
          bail: bail,
        );
      }
    }

    return create().toList();
  }

  Runnable createTestCommand({
    required String projectRoot,
    required DetermineFlutterOrDart tool,
    required String relativeProjectRoot,
    required String pathToProjectRoot,
    required List<String> flutterArgs,
    required List<String> dartArgs,
    required List<String> tests,
    required bool bail,
  }) {
    final toolArgs = tool.isFlutter ? flutterArgs : dartArgs;

    final command = tool.tool();

    final script = [
      '$command test',
      if (toolArgs.isNotEmpty) toolArgs.join(' '),
      if (tests.isNotEmpty)
        for (final test in tests)
          fs.path.relative(test, from: tool.directory()),
    ].join(' ');

    logger.detail('Test command: $script');

    var label = darkGray.wrap('Running (')!;
    label += cyan.wrap(command)!;
    label += darkGray.wrap(') tests in ')!;
    label += darkGray.wrap(pathToProjectRoot)!;
    label += darkGray.wrap(fs.path.separator)!;
    label += yellow.wrap(relativeProjectRoot)!;

    return ScriptToRun(
      script,
      workingDirectory: projectRoot,
      label: label,
      bail: bail,
      runInParallel: true,
    );
  }

  Future<ExitCode> runCommands(
    List<Runnable> commandsToRun, {
    required bool showOutput,
    required bool bail,
  }) async {
    for (final command in commandsToRun) {
      switch (command) {
        case ConcurrentBreak():
          continue;
        case ScriptToRun(:final exe):
          logger.detail(darkGray.wrap(exe));
      }
    }

    final result = await scriptRunner.run(
      commandsToRun,
      bail: bail,
      onMessage: (message) {
        logger.write(message.message);
        return null;
      },
    );

    return result.exitCodeReason;
  }

  void cleanUpOptimizedFiles(Iterable<String?> optimizedFiles) {
    for (final optimizedFile in optimizedFiles) {
      if (optimizedFile == null) continue;

      if (!optimizedFile.contains(optimizedTestBasename)) continue;

      fs.file(optimizedFile).deleteSync();
    }
  }

  (Iterable<PackageToTest>? filesToTest, ExitCode? exitCode) getPackagesToTest(
    List<String> testDirs,
    Map<String, DetermineFlutterOrDart> dirTools, {
    required bool optimize,
  }) {
    final dirsWithTests = <String>[];
    final glob = Glob('**/*_test.dart', recursive: true);

    for (final MapEntry(key: dir, value: _) in dirTools.entries) {
      final results = glob.listFileSystemSync(
        fs,
        followLinks: false,
        root: dir,
      );
      final tests = results.whereType<File>();

      if (tests.isNotEmpty) {
        dirsWithTests.add(dir);
      }
    }

    if (dirsWithTests.isEmpty) {
      logger.err('No tests found');
      return (null, ExitCode.success);
    }

    logger
      ..detail('Found ${dirsWithTests.length} directories with tests')
      ..detail('  - ${dirsWithTests.join('\n  - ')}')
      ..detail(
        '${optimize ? '' : 'NOT '}Optimizing '
        '${dirsWithTests.length} test files',
      );

    if (optimize) {
      // only dart tests can be optimized
      Progress? done;
      for (final dir in dirsWithTests) {
        final tool = dirTools[dir];
        if (tool == null) continue;
        if (tool.isFlutter) continue;

        done = logger.progress('Optimizing test files');
        break;
      }
      final result = prepareOptimizedFilesFromDirs(dirsWithTests, dirTools);

      done?.complete();

      if (result.isEmpty) {
        logger.err('No tests found');
        return (null, ExitCode.success);
      }

      return (result, null);
    }

    logger.warn('Running tests without optimization');

    final dirs = [
      for (final dir in dirsWithTests)
        if (dirTools[dir] case final tool?)
          PackageToTest(tool: tool, packagePath: dir),
    ];

    return (dirs, null);
  }

  Future<List<String>> getTestsFromProvided(List<String> providedTests) async {
    final testsToRun = <String>[];
    final glob = Glob('**/*_test.dart', recursive: true);

    for (final path in providedTests) {
      final fileOrDir = switch (path) {
        '.' => fs.currentDirectory.path,
        _ => path,
      };

      if (fs.isFileSync(fileOrDir)) {
        if (fs.path.basename(fileOrDir).endsWith('_test.dart')) {
          testsToRun.add(fileOrDir);
        }
      } else if (fs.isDirectorySync(fileOrDir)) {
        final results = glob.listFileSystemSync(
          fs,
          followLinks: false,
          root: fileOrDir,
        );
        final files = results.whereType<File>();

        final directories = {for (final file in files) file.parent.path};

        testsToRun.addAll(directories);
      } else {
        logger.err('File or directory not found: $fileOrDir');
      }
    }

    logger.detail('Running tests: \n  - ${testsToRun.join('\n  - ')}');
    return testsToRun;
  }
}
