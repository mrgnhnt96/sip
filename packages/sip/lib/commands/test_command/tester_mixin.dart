import 'package:args/args.dart';
import 'package:args/command_runner.dart';
import 'package:file/file.dart';
import 'package:glob/glob.dart';
import 'package:mason_logger/mason_logger.dart' hide ExitCode;
import 'package:path/path.dart' as path;
import 'package:sip_cli/domain/any_arg_parser.dart';
import 'package:sip_cli/domain/bindings.dart';
import 'package:sip_cli/domain/command_to_run.dart';
import 'package:sip_cli/domain/filter_type.dart';
import 'package:sip_cli/domain/find_file.dart';
import 'package:sip_cli/domain/package_to_test.dart';
import 'package:sip_cli/domain/pubspec_lock.dart';
import 'package:sip_cli/domain/pubspec_yaml.dart';
import 'package:sip_cli/domain/pubspec_yaml_impl.dart';
import 'package:sip_cli/domain/run_many_scripts.dart';
import 'package:sip_cli/domain/run_one_script.dart';
import 'package:sip_cli/domain/scripts_yaml.dart';
import 'package:sip_cli/domain/testable.dart';
import 'package:sip_cli/utils/determine_flutter_or_dart.dart';
import 'package:sip_cli/utils/exit_code.dart';
import 'package:sip_cli/utils/exit_code_extensions.dart';
import 'package:sip_cli/utils/stopwatch_extensions.dart';
import 'package:sip_cli/utils/write_optimized_test_file.dart';

part '__both_args.dart';
part '__conflicting_args.dart';
part '__dart_args.dart';
part '__flutter_args.dart';

abstract mixin class TesterMixin {
  const TesterMixin();

  static const String optimizedTestBasename = '.test_optimizer';

  Logger get logger;
  PubspecYaml get pubspecYaml;
  FindFile get findFile;
  PubspecLock get pubspecLock;
  FileSystem get fs;
  Bindings get bindings;
  ScriptsYaml get scriptsYaml;

  ({
    List<String> both,
    List<String> dart,
    List<String> flutter,
  }) getArgs<T>(Command<T> command) {
    final bothArgs = command._getBothArgs();
    final dartArgs = command._getDartArgs();
    final flutterArgs = command._getFlutterArgs();

    return (both: bothArgs, dart: dartArgs, flutter: flutterArgs);
  }

  void addTestFlags<T>(Command<T> command) {
    command
      ..argParser.addSeparator(cyan.wrap('Dart Flags:')!)
      .._addDartArgs()
      ..argParser.addSeparator(cyan.wrap('Flutter Flags:')!)
      .._addFlutterArgs()
      ..argParser.addSeparator(cyan.wrap('Overlapping Flags:')!)
      .._addBothArgs()
      ..argParser.addSeparator(cyan.wrap('Conflicting Flags:')!)
      .._addConflictingArgs();
  }

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
    (
      List<String> testDirs,
      Map<String, DetermineFlutterOrDart> dirTools,
    )?,
    ExitCode? exitCode,
  ) getTestDirs(
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
      final projectRoot = path.dirname(pubspec);
      final testDirectory = path.join(path.dirname(pubspec), 'test');

      if (!fs.directory(testDirectory).existsSync()) {
        logger
            .detail('No test directory found in ${path.relative(projectRoot)}');
        continue;
      }

      final tool = DetermineFlutterOrDart(
        pubspecYaml: path.join(projectRoot, 'pubspec.yaml'),
        findFile: findFile,
        pubspecLock: pubspecLock,
        scriptsYaml: scriptsYaml,
      );

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
      logger.err('No$forTool tests found');
      return (null, ExitCode.success);
    }

    return ((testDirs, dirTools), null);
  }

  Iterable<PackageToTest> prepareOptimizedFilesFromDirs(
    List<String> testDirs,
    Map<String, DetermineFlutterOrDart> dirTools,
  ) sync* {
    final glob = Glob(path.join('**_test.dart'));

    for (final testDir in testDirs) {
      final tool = dirTools[testDir];
      if (tool == null) continue;

      final packageToTest = PackageToTest(
        tool: tool,
        packagePath: testDir,
      );

      if (tool.isFlutter) {
        yield packageToTest;
        continue;
      }

      final allTestFiles =
          glob.listFileSystemSync(fs, followLinks: false, root: testDir);

      final testFiles = omitOptimizedTest(allTestFiles);

      if (testFiles.isEmpty) {
        continue;
      }

      final optimizedPath = writeOptimizedFile(
        testFiles,
        testDir: testDir,
      );

      packageToTest.optimizedPath = optimizedPath;

      yield packageToTest;
    }
  }

  Iterable<String> omitOptimizedTest(List<FileSystemEntity> allFiles) sync* {
    for (final file in allFiles) {
      if (file is! File) continue;

      final fileName = path.basename(file.path);

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
  String writeOptimizedFile(
    Iterable<String> files, {
    required String testDir,
  }) {
    ({String packageName, String barrelFile})? exportFile;

    if (PubspecYamlImpl(fs: fs).parse()?['name']
        case final String packageName) {
      final possibleNames = [
        packageName,
        fs.currentDirectory.basename,
      ];

      for (final name in possibleNames) {
        if (path.join('lib', '$name.dart') case final path
            when fs.file(path).existsSync()) {
          exportFile = (packageName: packageName, barrelFile: '$name.dart');
        }
      }
    }

    final optimizedPath = path.join(testDir, '$optimizedTestBasename.dart');
    fs.file(optimizedPath).createSync(recursive: true);

    final testDirs = files.map(
      (e) => Testable(
        absolute: e,
        optimizedPath: optimizedPath,
      ),
    );

    final content = writeOptimizedTestFile(
      testDirs,
      barrelFile: exportFile,
    );

    fs.file(optimizedPath).writeAsStringSync(content);

    return optimizedPath;
  }

  String packageRootFor(String filePath) {
    final parts = path.split(filePath);

    String root;
    if (parts.contains('test')) {
      root = parts.sublist(0, parts.indexOf('test')).join(path.separator);
    } else if (parts.contains('lib')) {
      root = parts.sublist(0, parts.indexOf('lib')).join(path.separator);
    } else {
      if (fs.isFileSync(filePath)) {
        root = path.basename(path.dirname(filePath));
      } else {
        root = path.basename(filePath);
      }
    }

    if (root.isEmpty) {
      root = '.';
    }

    return root;
  }

  Iterable<CommandToRun> getCommandsToRun(
    Iterable<PackageToTest> packagesToTest, {
    required List<String> flutterArgs,
    required List<String> dartArgs,
    bool bail = false,
  }) sync* {
    for (final packageToTest in packagesToTest) {
      yield createTestCommand(
        projectRoot: packageToTest.packagePath,
        relativeProjectRoot:
            packageRootFor(path.relative(packageToTest.packagePath)),
        flutterArgs: flutterArgs,
        tool: packageToTest.tool,
        dartArgs: dartArgs,
        tests: [
          if (packageToTest.optimizedPath case final test?
              when packageToTest.tool.isDart)
            path.relative(
              test,
              from: packageToTest.packagePath,
            ),
        ],
        bail: bail,
      );
    }
  }

  CommandToRun createTestCommand({
    required String projectRoot,
    required DetermineFlutterOrDart tool,
    required String relativeProjectRoot,
    required List<String> flutterArgs,
    required List<String> dartArgs,
    required List<String> tests,
    required bool bail,
  }) {
    final toolArgs = tool.isFlutter ? flutterArgs : dartArgs;

    final command = tool.tool();

    final script = [
      '$command test',
      if (tests.isNotEmpty) tests.join(' '),
      if (toolArgs.isNotEmpty) toolArgs.join(' '),
    ].join(' ');

    logger.detail('Test command: $script');

    var label = darkGray.wrap('Running (')!;
    label += cyan.wrap(command)!;
    label += darkGray.wrap(') tests in ')!;
    label += yellow.wrap(relativeProjectRoot)!;

    return CommandToRun(
      command: script,
      workingDirectory: projectRoot,
      keys: ['dart', 'test', ...tests, ...toolArgs],
      label: label,
      bail: bail,
      filterOutput: switch (tool.isFlutter) {
        true => FilterType.flutterTest,
        false => FilterType.dartTest,
      },
    );
  }

  Future<ExitCode> runCommands(
    Iterable<CommandToRun> commandsToRun, {
    required bool runConcurrently,
    required bool bail,
  }) async {
    if (runConcurrently) {
      for (final command in commandsToRun) {
        logger.detail('Script: ${darkGray.wrap(command.command)}');
      }

      final runMany = RunManyScripts(
        commands: commandsToRun,
        bindings: bindings,
        logger: logger,
      );

      final exitCodes = await runMany.run(
        label: 'Running tests ',
        bail: bail,
      );

      exitCodes.printErrors(commandsToRun, logger);

      return exitCodes.exitCode(logger);
    }

    ExitCode? exitCode;

    for (final command in commandsToRun) {
      logger.detail(command.command);
      final scriptRunner = RunOneScript(
        command: command,
        bindings: bindings,
        logger: logger,
        showOutput: true,
        filter: command.filterOutput,
      );

      final stopwatch = Stopwatch()..start();

      logger.info(darkGray.wrap(command.label));

      final result = await scriptRunner.run();

      final time = (stopwatch..stop()).format();

      logger
        ..info('Finished in ${cyan.wrap(time)}')
        ..write('\n');

      if (result.exitCodeReason != ExitCode.success) {
        exitCode = result.exitCodeReason;

        if (bail || command.bail) {
          return exitCode;
        }
      }
    }

    return exitCode ?? ExitCode.success;
  }

  void cleanUpOptimizedFiles(Iterable<String?> optimizedFiles) {
    for (final optimizedFile in optimizedFiles) {
      if (optimizedFile == null) continue;

      if (!optimizedFile.contains(optimizedTestBasename)) continue;

      fs.file(optimizedFile).deleteSync();
    }
  }

  (
    Iterable<PackageToTest>? filesToTest,
    ExitCode? exitCode,
  ) getPackagesToTest(
    List<String> testDirs,
    Map<String, DetermineFlutterOrDart> dirTools, {
    required bool optimize,
  }) {
    final dirsWithTests = <String>[];
    final glob = Glob('**_test.dart');
    for (final MapEntry(key: dir, value: _) in dirTools.entries) {
      final result = glob.listFileSystemSync(fs, followLinks: false, root: dir);

      if (result.any((e) => e is File)) {
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
          PackageToTest(
            tool: tool,
            packagePath: dir,
          ),
    ];

    return (dirs, null);
  }

  List<String> getTestsFromProvided(List<String> providedTests) {
    final testsToRun = <String>[];
    for (final fileOrDir in providedTests) {
      if (fs.isFileSync(fileOrDir)) {
        testsToRun.add(fileOrDir);
      } else if (fs.isDirectorySync(fileOrDir)) {
        final files = fs.directory(fileOrDir).listSync(recursive: true);
        for (final file in files) {
          if (file is File) {
            testsToRun.add(file.path);
          }
        }
      } else {
        logger.err('File or directory not found: $fileOrDir');
      }
    }

    logger.detail('Running tests: \n  - ${testsToRun.join('\n  - ')}');
    return testsToRun;
  }
}
