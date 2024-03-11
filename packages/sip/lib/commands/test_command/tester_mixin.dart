import 'package:file/file.dart';
import 'package:glob/glob.dart';
import 'package:mason_logger/mason_logger.dart' hide ExitCode;
import 'package:path/path.dart' as path;
import 'package:sip_cli/domain/find_file.dart';
import 'package:sip_cli/domain/run_many_scripts.dart';
import 'package:sip_cli/domain/run_one_script.dart';
import 'package:sip_cli/domain/testable.dart';
import 'package:sip_cli/utils/determine_flutter_or_dart.dart';
import 'package:sip_cli/utils/exit_code.dart';
import 'package:sip_cli/utils/exit_code_extensions.dart';
import 'package:sip_cli/utils/stopwatch_extensions.dart';
import 'package:sip_cli/utils/write_optimized_test_file.dart';
import 'package:sip_script_runner/sip_script_runner.dart';

abstract mixin class TesterMixin {
  const TesterMixin();

  static const String optimizedTestFileName = '.optimized_test.dart';

  Logger get logger;
  PubspecYaml get pubspecYaml;
  FindFile get findFile;
  PubspecLock get pubspecLock;
  FileSystem get fs;
  Bindings get bindings;

  Future<List<String>> pubspecs({
    required bool isRecursive,
  }) async {
    final pubspecs = <String>{};

    final pubspec = pubspecYaml.nearest();

    if (pubspec != null) {
      pubspecs.add(pubspec);
    }

    if (isRecursive) {
      logger.detail('Running tests recursively');
      final children = await pubspecYaml.children();
      pubspecs.addAll(children.map((e) => path.join(path.separator, e)));
    }

    return pubspecs.toList();
  }

  (
    List<String> testDirs,
    Map<String, DetermineFlutterOrDart> dirTools,
  ) getTestDirs(
    List<String> pubspecs, {
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

    return (testDirs, dirTools);
  }

  Map<String, DetermineFlutterOrDart> writeOptimizedFiles(
    List<String> testDirs,
    Map<String, DetermineFlutterOrDart> dirTools,
  ) {
    final optimizedFiles = <String, DetermineFlutterOrDart>{};

    for (final testDir in testDirs) {
      final allFiles = Glob(path.join('**_test.dart'))
          .listFileSystemSync(fs, followLinks: false, root: testDir);

      final testFiles = <String>[];

      for (final file in allFiles) {
        if (file is! File) continue;

        final fileName = path.basename(file.path);

        if (fileName == optimizedTestFileName) {
          continue;
        }

        testFiles.add(file.path);
      }

      if (testFiles.isEmpty) {
        continue;
      }

      final optimizedPath = path.join(testDir, optimizedTestFileName);
      fs.file(optimizedPath).createSync(recursive: true);

      final testDirs = testFiles
          .map((e) => Testable(absolute: e, optimizedPath: optimizedPath));

      final tool = dirTools[testDir]!;

      final content =
          writeOptimizedTestFile(testDirs, isFlutterPackage: tool.isFlutter);

      fs.file(optimizedPath).writeAsStringSync(content);

      optimizedFiles[optimizedPath] = tool;
    }

    return optimizedFiles;
  }

  List<CommandToRun> getCommandsToRun(
    Map<String, DetermineFlutterOrDart> testFiles, {
    required bool optimize,
    required List<String> flutterArgs,
    required List<String> dartArgs,
  }) {
    final commandsToRun = <CommandToRun>[];

    for (final MapEntry(key: test, value: tool) in testFiles.entries) {
      String projectRoot;
      if (fs.isFileSync(test)) {
        projectRoot = path.dirname(path.dirname(test));
      } else {
        projectRoot = path.dirname(test);
      }

      final toolArgs = tool.isFlutter ? flutterArgs : dartArgs;

      final command = tool.tool();

      final testPath = path.relative(test, from: projectRoot);

      final script = '$command test $testPath ${toolArgs.join(' ')}';

      var label = darkGray.wrap('Running (')!;
      label += cyan.wrap(command)!;
      label += darkGray.wrap(') tests in ')!;
      if (test.endsWith(optimizedTestFileName)) {
        label +=
            darkGray.wrap(path.dirname(path.dirname(path.relative(test))))!;
      } else {
        label += darkGray.wrap(path.relative(test))!;
      }

      commandsToRun.add(
        CommandToRun(
          command: script,
          workingDirectory: projectRoot,
          keys: null,
          label: label,
        ),
      );
    }

    return commandsToRun;
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

      if (result != ExitCode.success) {
        exitCode = result;

        if (bail) {
          return exitCode;
        }
      }
    }

    return exitCode ?? ExitCode.success;
  }

  void cleanUp(Iterable<String> optimizedFiles) {
    for (final optimizedFile in optimizedFiles) {
      if (!optimizedFile.endsWith(optimizedTestFileName)) continue;

      fs.file(optimizedFile).deleteSync();
    }
  }

  Map<String, DetermineFlutterOrDart> getTests(
    List<String> testDirs,
    Map<String, DetermineFlutterOrDart> dirTools, {
    required bool optimize,
  }) {
    logger.detail(
      '${optimize ? '' : 'NOT '}Optimizing ${testDirs.length} test files',
    );

    if (optimize) {
      final done = logger.progress('Optimizing test files');
      final result = writeOptimizedFiles(testDirs, dirTools);

      done.complete();

      return result;
    }

    logger.warn('Running tests without optimization');

    final dirsWithTests = <String>[];

    for (final MapEntry(key: dir, value: _) in dirTools.entries) {
      final allFiles = Glob('**_test.dart')
          .listFileSystemSync(fs, followLinks: false, root: dir);

      var hasTests = false;

      for (final file in allFiles) {
        if (file is! File) continue;

        hasTests = true;

        break;
      }

      if (hasTests) {
        dirsWithTests.add(dir);
      }
    }

    return {
      for (final dir in dirsWithTests) dir: dirTools[dir]!,
    };
  }
}
