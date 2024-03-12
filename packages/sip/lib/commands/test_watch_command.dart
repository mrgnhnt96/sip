import 'dart:async';

import 'package:args/args.dart';
import 'package:args/command_runner.dart';
import 'package:file/file.dart';
import 'package:mason_logger/mason_logger.dart' hide ExitCode;
import 'package:path/path.dart' as path;
import 'package:sip_cli/commands/test_command/tester_mixin.dart';
import 'package:sip_cli/domain/find_file.dart';
import 'package:sip_cli/domain/run_tests.dart';
import 'package:sip_cli/utils/determine_flutter_or_dart.dart';
import 'package:sip_cli/utils/exit_code.dart';
import 'package:sip_cli/utils/key_press_listener.dart';
import 'package:sip_cli/utils/stream_group.dart';
import 'package:sip_script_runner/domain/bindings.dart';
import 'package:sip_script_runner/domain/pubspec_lock.dart';
import 'package:sip_script_runner/domain/pubspec_yaml.dart';

class TestWatchCommand extends Command<ExitCode> with TesterMixin {
  TestWatchCommand({
    required this.bindings,
    required this.findFile,
    required this.fs,
    required this.logger,
    required this.pubspecLock,
    required this.pubspecYaml,
    required this.keyPressListener,
  }) : argParser = ArgParser(usageLineLength: 120) {
    addTestFlags(this);

    argParser
      ..addSeparator(cyan.wrap('SIP Flags:')!)
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
      ..addOption(
        'run',
        help: 'The type of tests to run',
        defaultsTo: RunTests.package.option,
        allowed: RunTests.values.map((e) => e.option).toList(),
        allowedHelp: {
          for (final val in RunTests.values) val.option: val.help,
        },
      )
      ..addFlag(
        'optimize',
        help: 'Whether to create optimized test files',
        defaultsTo: true,
      );
  }

  @override
  String get name => 'watch';

  @override
  String get description => 'Run tests in watch mode.';

  @override
  final Bindings bindings;

  @override
  final FindFile findFile;

  @override
  final FileSystem fs;

  @override
  final Logger logger;

  @override
  final PubspecLock pubspecLock;

  @override
  final PubspecYaml pubspecYaml;

  @override
  final ArgParser argParser;

  final KeyPressListener keyPressListener;

  void writeWaitingMessage(RunTests runType) {
    var returnTestType = '';

    switch (runType) {
      case RunTests.package:
        returnTestType = [
          darkGray.wrap('Will run '),
          magenta.wrap('package tests'),
          darkGray.wrap(' with the most recent changed file'),
        ].join();
      case RunTests.modified:
        returnTestType = [
          darkGray.wrap('Will run '),
          magenta.wrap('test file'),
          darkGray.wrap(' associated with '),
          darkGray.wrap('the most recent changed file'),
        ].join();
      case RunTests.all:
        returnTestType = [
          darkGray.wrap('Will run '),
          magenta.wrap('all tests'),
          darkGray.wrap(' in all packages'),
        ].join();
    }

    returnTestType += darkGray.wrap('\n  Press `t` to toggle this feature')!;
    returnTestType = darkGray.wrap(returnTestType)!;

    final waitingMessage = '''

${yellow.wrap('Waiting for changes...')}
$returnTestType
${darkGray.wrap('Press `q` to exit')}
${darkGray.wrap('Press `r` to run tests')}
''';

    logger.write(waitingMessage);
  }

  @override
  Future<ExitCode> run([List<String>? args]) async {
    final argResults = args != null ? argParser.parse(args) : super.argResults!;

    final isRecursive = argResults['recursive'] as bool;
    final isDartOnly =
        argResults.wasParsed('dart-only') && argResults['dart-only'] as bool;
    final isFlutterOnly = argResults.wasParsed('flutter-only') &&
        argResults['flutter-only'] as bool;
    final concurrent = argResults['concurrent'] as bool;
    final clean = argResults['clean'] as bool;

    final optimize = argResults['optimize'] as bool;
    final runTestType =
        RunTests.options[argResults['run'] as String] ?? RunTests.package;

    warnDartOrFlutterTests(
      isFlutterOnly: isFlutterOnly,
      isDartOnly: isDartOnly,
    );

    final pubspecs = await this.pubspecs(isRecursive: isRecursive);

    final testDirsResult = getTestDirs(
      pubspecs,
      isFlutterOnly: isFlutterOnly,
      isDartOnly: isDartOnly,
    );

    if (testDirsResult.$2 case final ExitCode exitCode) {
      return exitCode;
    }

    final (testDirs, dirTools) = testDirsResult.$1!;

    final testsResult = getTests(
      testDirs,
      dirTools,
      optimize: optimize,
    );

    // exit code is not null
    if (testsResult.$2 case final ExitCode exitCode) {
      return exitCode;
    }

    final tests = testsResult.$1!;

    final libDirs = testDirs.map((e) => e.replaceAll(RegExp(r'test$'), 'lib'));

    final (:both, :dart, :flutter) = getArgs(this);

    final flutterArgs = [...flutter, ...both];
    final dartArgs = [...dart, ...both];

    var printMessage = true;

    logger.detail(
      'Watching directories: ${[
        ...testDirs,
        ...libDirs,
      ].map(path.relative).join(', ')}',
    );

    var runType = runTestType;

    Map<String, DetermineFlutterOrDart>? lastTests;

    // This setup up will not include any new packages created,
    // only the ones that exist when the command is run
    while (true) {
      if (printMessage) {
        writeWaitingMessage(runType);
      }

      printMessage = false;

      final (:exit, :file, :run, :toggleModified) = await waitForChange(
        testDirs: testDirs,
        libDirs: libDirs,
        runType: runType,
      );

      if (exit) {
        break;
      }

      if (toggleModified) {
        runType = RunTests.toggle(runType);
        printMessage = true;
        lastTests = null;
        continue;
      }

      final testsToRun = <String, DetermineFlutterOrDart>{};

      if (!run) {
        if (file == null) {
          logger.detail('No file changed, waiting for changes...');
          continue;
        }

        if (file.endsWith(TesterMixin.optimizedTestFileName)) {
          logger.detail('Optimized test file changed, waiting for changes...');
          continue;
        }
      }

      if (runType.isAll) {
        logger.info('Running all tests');

        testsToRun.addAll(tests);
      } else if (file == null) {
        logger.info('Checking for last tests run...');
        await Future<void>.delayed(const Duration(milliseconds: 100));
        if (lastTests == null) {
          logger.info(
            red.wrap('No previous tests found, modify a file to run tests'),
          );

          printMessage = true;
          continue;
        }

        testsToRun.addAll(lastTests);
      } else {
        final testResult = await findTest(
          tests,
          file,
          returnTestFile: runType.isModified,
        );

        if (testResult == null) {
          logger.detail('No test found for $file, waiting for changes...');
          continue;
        }

        logger.info('Running tests for ${path.relative(file)}');

        final (test, tool) = testResult;
        testsToRun[test] = tool;
      }

      lastTests = testsToRun;

      printMessage = true;

      final commandsToRun = getCommandsToRun(
        testsToRun,
        optimize: optimize,
        flutterArgs: flutterArgs,
        dartArgs: dartArgs,
      );

      final exitCode = await runCommands(
        commandsToRun,
        runConcurrently: concurrent,
        bail: false,
      );

      if (exitCode != ExitCode.success) {
        logger.err('${red.wrap('✗')} Some tests failed');
      } else {
        logger.write('${green.wrap('✔')} Tests passed');
      }
    }

    if (optimize && clean) {
      final done = logger.progress('Cleaning up optimized test files');

      cleanUp(tests.keys);

      done.complete('Optimized test files cleaned!');
    }

    return ExitCode.success;
  }

  Future<(String test, DetermineFlutterOrDart tool)?> findTest(
    Map<String, DetermineFlutterOrDart> tests,
    String modifiedFile, {
    required bool returnTestFile,
  }) async {
    // {<directory>, <key>}
    final keys = <String, String>{};

    for (final test in tests.keys) {
      if (fs.isFileSync(test)) {
        keys[fs.file(test).parent.path] = test;
      } else {
        keys[test] = test;
      }
    }

    (String, DetermineFlutterOrDart)? testResult;

    for (final MapEntry(key: directory, value: test) in keys.entries) {
      // check if the modified file is in the test directory
      if (modifiedFile.startsWith(directory)) {
        testResult = (directory, tests[test]!);
        break;
      }

      // check if the modified file is in the lib directory
      // associated with the test directory
      // eg. lib/foo.dart -> test/foo_test.dart
      final libDir = directory.replaceAll(RegExp(r'test$'), 'lib');
      if (modifiedFile.startsWith(libDir)) {
        testResult = (directory, tests[test]!);
        break;
      }
    }

    if (testResult == null) {
      return null;
    }

    if (!returnTestFile) {
      return testResult;
    }

    // check for the test file associated with the modified file
    final base = path.basenameWithoutExtension(modifiedFile);
    final nameOfTest =
        base.endsWith('_test') ? '$base.dart' : '${base}_test.dart';
    final possibleFiles =
        await findFile.childrenOf(nameOfTest, directoryPath: testResult.$1);

    if (possibleFiles.isEmpty) {
      return null;
    }

    if (possibleFiles.length == 1) {
      return (possibleFiles.first, testResult.$2);
    }

    final libPath = testResult.$1.replaceAll(RegExp(r'.*.?test$'), 'lib');
    final modifiedFileInLib = modifiedFile
        .replaceAll(libPath, 'test')
        .replaceAll(path.basename(modifiedFile), nameOfTest);
    final segments = path.split(modifiedFileInLib);

    for (final test in possibleFiles) {
      final segmentsInTestFile = path.split(test);
      if (segmentsInTestFile.length != segments.length) {
        continue;
      }

      for (var i = 0; i < segments.length; i++) {
        if (segments[i] != segmentsInTestFile[i]) {
          break;
        }

        if (i == segments.length - 1) {
          return (test, testResult.$2);
        }
      }
    }

    return null;
  }

  Future<
      ({
        bool exit,
        String? file,
        bool run,
        bool toggleModified,
      })> waitForChange({
    required Iterable<String> testDirs,
    required Iterable<String> libDirs,
    required RunTests runType,
  }) async {
    String eventType(int event) {
      switch (event) {
        case FileSystemEvent.create:
          return 'create';
        case FileSystemEvent.delete:
          return 'delete';
        case FileSystemEvent.move:
          return 'move';
        case FileSystemEvent.modify:
          return 'modify';
        case FileSystemEvent.all:
          return 'all';
        default:
          return 'unknown';
      }
    }

    final fileModifications = [...testDirs, ...libDirs].map((dir) {
      StreamSubscription<void>? subscription;
      final controller = StreamController<String>.broadcast(
        onCancel: () async {
          await subscription?.cancel();
        },
      );

      final watcher = fs.directory(dir).watch(recursive: true);

      subscription = watcher.listen((event) {
        logger
          ..detail('\n')
          ..detail('File event: ${eventType(event.type)}')
          ..detail('File changed: ${event.path}');

        controller.add(event.path);
      });

      return controller.stream;
    }).toList();

    final fileChangeCompleter = Completer<
        ({
          bool exit,
          String? file,
          bool run,
          bool toggleModified,
        })>();

    final input = keyPressListener.listenToKeystrokes(
      onExit: () {
        fileChangeCompleter.complete(
          (
            exit: true,
            file: null,
            run: false,
            toggleModified: false,
          ),
        );
      },
      onEscape: () => writeWaitingMessage(runType),
      customStrokes: {
        'r': () {
          fileChangeCompleter.complete(
            (
              exit: false,
              file: null,
              run: true,
              toggleModified: false,
            ),
          );
        },
        't': () {
          fileChangeCompleter.complete(
            (
              exit: false,
              file: null,
              run: false,
              toggleModified: true,
            ),
          );
        },
      },
    );

    StreamSubscription<void>? inputSubscription;
    inputSubscription = input?.listen((_) {});

    final fileChangeListener = StreamGroup(fileModifications).merge().listen(
          (file) => fileChangeCompleter.complete(
            (
              exit: false,
              file: file,
              run: false,
              toggleModified: false,
            ),
          ),
        );

    final result = await fileChangeCompleter.future;
    await fileChangeListener.cancel();
    await inputSubscription?.cancel();

    return result;
  }
}
