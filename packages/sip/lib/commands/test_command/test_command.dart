// ignore_for_file: cascade_invocations

import 'package:args/args.dart';
import 'package:args/command_runner.dart';
import 'package:file/file.dart';
import 'package:mason_logger/mason_logger.dart' hide ExitCode;
import 'package:path/path.dart' as path;
import 'package:sip_cli/domain/any_arg_parser.dart';
import 'package:sip_cli/domain/find_file.dart';
import 'package:sip_cli/domain/run_many_scripts.dart';
import 'package:sip_cli/domain/run_one_script.dart';
import 'package:sip_cli/domain/testable.dart';
import 'package:sip_cli/utils/determine_flutter_or_dart.dart';
import 'package:sip_cli/utils/exit_code.dart';
import 'package:sip_cli/utils/exit_code_extensions.dart';
import 'package:sip_cli/utils/write_optimized_test_file.dart';
import 'package:sip_script_runner/sip_script_runner.dart';

part '__both_args.dart';
part '__dart_args.dart';
part '__flutter_args.dart';

class TestCommand extends Command<ExitCode> {
  TestCommand({
    required this.pubspecYaml,
    required this.bindings,
    required this.pubspecLock,
    required this.findFile,
    required this.fs,
    required this.logger,
  }) {
    argParser
      ..addFlag(
        'recursive',
        abbr: 'r',
        help: 'Run tests in subdirectories',
        negatable: false,
      )
      ..addFlag(
        'concurrent',
        abbr: 'c',
        aliases: ['parallel'],
        help: 'Run tests concurrently',
        negatable: false,
      )
      ..addFlag(
        'bail',
        abbr: 'b',
        help: 'Bail after first test failure',
        negatable: false,
      )
      ..addFlag(
        'clean',
        help: 'Whether to remove the optimized test files after running tests',
        defaultsTo: true,
      )
      ..addFlag(
        'dart-only',
        help: 'Run only dart tests',
        negatable: false,
      )
      ..addFlag(
        'flutter-only',
        help: 'Run only flutter tests',
        negatable: false,
      )
      ..addFlag(
        'optimize',
        help: 'Whether to create optimized test files',
        defaultsTo: true,
      );

    argParser.addSeparator('Dart Flags:');
    _addDartArgs();

    argParser.addSeparator('Flutter Flags:');
    _addFlutterArgs();

    argParser.addSeparator('Overlapping Flags:');
    _addBothArgs();
  }

  static const String optimizedTestFileName = '.optimized_test.dart';

  final PubspecYaml pubspecYaml;
  late final FileSystem fs;
  late final Logger logger;
  final Bindings bindings;
  final PubspecLock pubspecLock;
  final FindFile findFile;

  @override
  String get description => 'Run flutter or dart tests';

  @override
  String get name => 'test';

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
    List<String> testables,
    Map<String, DetermineFlutterOrDart> testableTool,
  ) {
    final optimizedFiles = <String, DetermineFlutterOrDart>{};

    for (final testable in testables) {
      final allFiles =
          fs.directory(testable).listSync(recursive: true, followLinks: false);

      final testFiles = <String>[];

      for (final file in allFiles) {
        final fileName = path.basename(file.path);
        if (!fileName.endsWith('_test.dart')) {
          continue;
        }

        if (fileName == optimizedTestFileName) {
          continue;
        }

        testFiles.add(file.path);
      }

      if (testFiles.isEmpty) {
        continue;
      }

      final optimizedPath = path.join(testable, optimizedTestFileName);
      fs.file(optimizedPath).createSync(recursive: true);

      final testables = testFiles
          .map((e) => Testable(absolute: e, optimizedPath: optimizedPath));

      final tool = testableTool[testable]!;

      final content =
          writeOptimizedTestFile(testables, isFlutterPackage: tool.isFlutter);

      fs.file(optimizedPath).writeAsStringSync(content);

      optimizedFiles[optimizedPath] = tool;
    }

    return optimizedFiles;
  }

  Map<String, DetermineFlutterOrDart> getTestFiles(
    List<String> testables,
    Map<String, DetermineFlutterOrDart> testableTool,
  ) {
    final testFiles = <String, DetermineFlutterOrDart>{};

    for (final testable in testables) {
      final allFiles =
          fs.directory(testable).listSync(recursive: true, followLinks: false);

      for (final file in allFiles) {
        final fileName = path.basename(file.path);
        if (!fileName.endsWith('_test.dart')) {
          continue;
        }

        if (fileName == optimizedTestFileName) {
          continue;
        }

        final tool = testableTool[testable]!;

        testFiles[file.path] = tool;
      }
    }

    return testFiles;
  }

  List<CommandToRun> getCommandsToRun(
    Map<String, DetermineFlutterOrDart> testFiles, {
    required List<String> flutterArgs,
    required List<String> dartArgs,
  }) {
    final commandsToRun = <CommandToRun>[];

    for (final MapEntry(key: testFile, value: tool) in testFiles.entries) {
      final projectRoot = path.dirname(path.dirname(testFile));

      final toolArgs = tool.isFlutter ? flutterArgs : dartArgs;

      final command = tool.tool();

      final testPath = path.relative(testFile, from: projectRoot);

      final script = '$command test $testPath ${toolArgs.join(' ')}';

      var label = darkGray.wrap('Running (')!;
      label += cyan.wrap(command)!;
      label += darkGray.wrap(') tests in ')!;
      if (testFile.endsWith(optimizedTestFileName)) {
        label += yellow.wrap(path.relative(projectRoot))!;
      } else {
        label += darkGray.wrap(path.relative(testFile, from: projectRoot))!;
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

      stopwatch.stop();

      final seconds = stopwatch.elapsed.inMilliseconds / 1000;
      final time = '${seconds.toStringAsPrecision(1)}s';

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
    List<String> testables,
    Map<String, DetermineFlutterOrDart> testableTool, {
    required bool optimize,
  }) {
    if (optimize) {
      final done = logger.progress('Optimizing test files');
      final result = writeOptimizedFiles(testables, testableTool);

      done.complete();

      return result;
    }

    logger.warn('Running tests without optimization');

    return getTestFiles(testables, testableTool);
  }

  @override
  Future<ExitCode> run([List<String>? args]) async {
    final argResults = args != null ? argParser.parse(args) : super.argResults!;

    final isDartOnly =
        argResults.wasParsed('dart-only') && argResults['dart-only'] as bool;

    final isFlutterOnly = argResults.wasParsed('flutter-only') &&
        argResults['flutter-only'] as bool;

    final isRecursive = argResults['recursive'] as bool? ?? false;

    if (isDartOnly || isFlutterOnly) {
      if (isDartOnly && !isFlutterOnly) {
        logger.info('Running only dart tests');
      } else if (isFlutterOnly && !isDartOnly) {
        logger.info('Running only flutter tests');
      } else {
        logger.info('Running both dart and flutter tests');
      }
    }

    final pubspecs = await this.pubspecs(isRecursive: isRecursive);

    if (pubspecs.isEmpty) {
      logger.err('No pubspec.yaml files found');
      return ExitCode.unavailable;
    }

    final (testDirs, dirTools) = getTestDirs(
      pubspecs,
      isFlutterOnly: isFlutterOnly,
      isDartOnly: isDartOnly,
    );

    if (testDirs.isEmpty) {
      var forTool = '';

      if (isFlutterOnly ^ isDartOnly) {
        forTool = ' ';
        forTool += isDartOnly ? 'dart' : 'flutter';
      }
      logger.err('No$forTool tests found');
      return ExitCode.unavailable;
    }

    final optimize = argResults['optimize'] as bool;

    final tests = getTests(
      testDirs,
      dirTools,
      optimize: optimize,
    );

    final bothArgs = _getBothArgs();
    final flutterArgs = [..._getFlutterArgs(), ...bothArgs];
    final dartArgs = [..._getDartArgs(), ...bothArgs];
    final commandsToRun = getCommandsToRun(
      tests,
      flutterArgs: flutterArgs,
      dartArgs: dartArgs,
    );

    logger.write('\n');

    final exitCode = await runCommands(
      commandsToRun,
      runConcurrently: argResults['concurrent'] as bool,
      bail: argResults['bail'] as bool,
    );

    logger.write('\n');

    if (optimize && argResults['clean'] as bool) {
      final done = logger.progress('Cleaning up optimized test files');

      cleanUp(tests.keys);

      done.complete();
    }

    if (exitCode != ExitCode.success) {
      logger.err('${red.wrap('✗')} Some tests failed');
    } else {
      logger.write('${green.wrap('✔')} Tests passed');
    }

    logger.write('\n');

    return exitCode;
  }
}
