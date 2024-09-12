import 'package:args/args.dart';
import 'package:args/command_runner.dart';
import 'package:file/file.dart';
import 'package:glob/glob.dart';
import 'package:mason_logger/mason_logger.dart' hide ExitCode;
import 'package:path/path.dart' as path;
import 'package:sip_cli/domain/any_arg_parser.dart';
import 'package:sip_cli/domain/bindings.dart';
import 'package:sip_cli/domain/command_to_run.dart';
import 'package:sip_cli/domain/find_file.dart';
import 'package:sip_cli/domain/pubspec_lock.dart';
import 'package:sip_cli/domain/pubspec_yaml.dart';
import 'package:sip_cli/domain/run_many_scripts.dart';
import 'package:sip_cli/domain/run_one_script.dart';
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
  static String optimizedTestFileName(String type) {
    if (type == 'dart' || type == 'flutter') {
      return '$optimizedTestBasename.dart';
    }

    return '$optimizedTestBasename.$type.dart';
  }

  Logger get logger;
  PubspecYaml get pubspecYaml;
  FindFile get findFile;
  PubspecLock get pubspecLock;
  FileSystem get fs;
  Bindings get bindings;

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
      );

      // we only care checking for flutter or
      // dart tests if we are not running both
      if (isFlutterOnly ^ isDartOnly) {
        if (tool.isFlutter && isDartOnly && !isFlutterOnly) {
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
      return (null, ExitCode.unavailable);
    }

    return ((testDirs, dirTools), null);
  }

  Map<String, DetermineFlutterOrDart> prepareOptimizedFilesFromDirs(
    List<String> testDirs,
    Map<String, DetermineFlutterOrDart> dirTools,
  ) {
    final optimizedFiles = <String, DetermineFlutterOrDart>{};

    for (final testDir in testDirs) {
      final tool = dirTools[testDir]!;
      final allFiles = Glob(path.join('**_test.dart'))
          .listFileSystemSync(fs, followLinks: false, root: testDir);

      final testFiles = separateTestFiles(allFiles, isFlutter: tool.isFlutter);

      if (testFiles.isEmpty) {
        continue;
      }

      optimizedFiles.addAll(
        writeOptimizedFiles(
          testFiles,
          testDir: testDir,
          tool: tool,
        ),
      );
    }

    return optimizedFiles;
  }

  Map<String, List<String>> separateTestFiles(
    List<FileSystemEntity> allFiles, {
    required bool isFlutter,
  }) {
    /// the key is the name of the test type
    final testFiles = <String, List<String>>{};

    for (final file in allFiles) {
      if (file is! File) continue;

      final testType = getTestType(file.path, isFlutter: isFlutter);

      final fileName = path.basename(file.path);

      if (fileName.contains(optimizedTestBasename)) {
        continue;
      }

      (testFiles[testType] ??= []).add(file.path);
    }

    return testFiles;
  }

  /// The [files] param's key is the value of the type of test
  ///
  /// The base values for this are `dart` for dart tests and `flutter`
  /// for flutter tests.
  ///
  /// When these values are different, it is because flutter has specific
  /// tests to be run. Such as `LiveTestWidgetsFlutterBinding`, the value would
  /// be `live`
  Map<String, DetermineFlutterOrDart> writeOptimizedFiles(
    Map<String, List<String>> files, {
    required String testDir,
    required DetermineFlutterOrDart tool,
  }) {
    final optimizedFiles = <String, DetermineFlutterOrDart>{};

    for (final MapEntry(key: type, value: testFiles) in files.entries) {
      final optimizedPath = path.join(testDir, optimizedTestFileName(type));
      fs.file(optimizedPath).createSync(recursive: true);

      final testDirs = testFiles.map(
        (e) => Testable(
          absolute: e,
          optimizedPath: optimizedPath,
          testType: type,
        ),
      );

      final content =
          writeOptimizedTestFile(testDirs, isFlutterPackage: tool.isFlutter);

      fs.file(optimizedPath).writeAsStringSync(content);

      optimizedFiles[optimizedPath] = tool.setTestType(type);
    }

    return optimizedFiles;
  }

  String getTestType(String path, {required bool isFlutter}) {
    var testType = 'dart';

    final file = fs.file(path);

    if (isFlutter) {
      final content = file.readAsStringSync();

      final flutterTestType = RegExp(r'(\w+WidgetsFlutterBinding)')
          .firstMatch(content)
          ?.group(1)
          ?.replaceAll('TestWidgetsFlutterBinding', '')
          .toLowerCase();

      if (flutterTestType == null) {
        testType = 'flutter';
      } else {
        if (flutterTestType.isEmpty) {
          testType = 'test';
        } else {
          testType = flutterTestType;
        }

        logger.detail('Found Flutter $testType test');
      }
    }

    return testType;
  }

  String packageRootFor(String filePath) {
    final parts = path.split(filePath);

    String root;
    if (parts.contains('test')) {
      root = parts.sublist(0, parts.indexOf('test')).join(path.separator);
    } else if (parts.contains('lib')) {
      root = parts.sublist(0, parts.indexOf('lib')).join(path.separator);
    } else {
      root = path.basename(path.dirname(filePath));
    }

    if (root.isEmpty) {
      root = '.';
    }

    return root;
  }

  List<CommandToRun> getCommandsToRun(
    Map<String, DetermineFlutterOrDart> testFiles, {
    required List<String> flutterArgs,
    required List<String> dartArgs,
  }) {
    final commandsToRun = <CommandToRun>[];

    for (final MapEntry(key: test, value: tool) in testFiles.entries) {
      final projectRoot = packageRootFor(test);

      final testPath = path.relative(test, from: projectRoot);

      final command = createTestCommand(
        projectRoot: projectRoot,
        relativeProjectRoot: packageRootFor(path.relative(test)),
        tool: tool,
        flutterArgs: flutterArgs,
        dartArgs: dartArgs,
        tests: [testPath],
      );

      commandsToRun.add(command);
    }

    return commandsToRun;
  }

  CommandToRun createTestCommand({
    required String projectRoot,
    required String relativeProjectRoot,
    required DetermineFlutterOrDart tool,
    required List<String> flutterArgs,
    required List<String> dartArgs,
    required List<String> tests,
  }) {
    if (tests.isEmpty) {
      throw Exception('Cannot create a command without tests');
    }

    final toolArgs = tool.isFlutter ? flutterArgs : dartArgs;

    final command = tool.tool();

    final script = '$command test ${tests.join(' ')} ${toolArgs.join(' ')}';

    logger.detail('Test command: $script');

    var label = darkGray.wrap('Running (')!;
    label += cyan.wrap(command)!;
    if (tool.testType != null) {
      label += darkGray.wrap(' | ')!;
      label += magenta.wrap(tool.testType!.toUpperCase())!;
    }
    if (tests.length == 1) {
      label += darkGray.wrap(') tests in ')!;

      label += yellow.wrap(relativeProjectRoot)!;
    } else {
      label += darkGray.wrap(') tests for ')!;

      label += yellow.wrap(tests.join(', '))!;
    }

    return CommandToRun(
      command: script,
      workingDirectory: projectRoot,
      keys: ['dart', 'test', ...tests, ...toolArgs],
      label: label,
    );
  }

  Future<ExitCode> runCommands(
    List<CommandToRun> commandsToRun, {
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
        label: 'Running tests',
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

        if (bail) {
          return exitCode;
        }
      }
    }

    return exitCode ?? ExitCode.success;
  }

  void cleanUpOptimizedFiles(Iterable<String> optimizedFiles) {
    for (final optimizedFile in optimizedFiles) {
      if (!optimizedFile.contains(optimizedTestBasename)) continue;

      fs.file(optimizedFile).deleteSync();
    }
  }

  (
    Map<String, DetermineFlutterOrDart>? filesToTest,
    ExitCode? exitCode,
  ) getTestsFromDirs(
    List<String> testDirs,
    Map<String, DetermineFlutterOrDart> dirTools, {
    required bool optimize,
  }) {
    logger.detail(
      '${optimize ? '' : 'NOT '}Optimizing ${testDirs.length} test files',
    );

    if (optimize) {
      final done = logger.progress('Optimizing test files');
      final result = prepareOptimizedFilesFromDirs(testDirs, dirTools);

      done.complete();

      if (result.isEmpty) {
        logger.err('No tests found');
        return (null, ExitCode.unavailable);
      }

      return (result, null);
    }

    logger.warn('Running tests without optimization');

    final dirsWithTests = <String>[];

    for (final MapEntry(key: dir, value: _) in dirTools.entries) {
      final result = Glob('**_test.dart')
          .listFileSystemSync(fs, followLinks: false, root: dir);

      final hasTests = result.any((e) => e is File);

      if (hasTests) {
        dirsWithTests.add(dir);
      }
    }

    final dirs = {
      for (final dir in dirsWithTests) dir: dirTools[dir]!,
    };

    if (dirs.isEmpty) {
      logger.err('No tests found');
      return (null, ExitCode.unavailable);
    }

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
