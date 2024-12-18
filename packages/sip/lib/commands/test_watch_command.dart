import 'dart:async';

import 'package:args/args.dart';
import 'package:args/command_runner.dart';
import 'package:file/file.dart';
import 'package:mason_logger/mason_logger.dart' hide ExitCode;
import 'package:path/path.dart' as path;
import 'package:sip_cli/commands/test_command/tester_mixin.dart';
import 'package:sip_cli/domain/bindings.dart';
import 'package:sip_cli/domain/find_file.dart';
import 'package:sip_cli/domain/package_to_test.dart';
import 'package:sip_cli/domain/pubspec_lock.dart';
import 'package:sip_cli/domain/pubspec_yaml.dart';
import 'package:sip_cli/domain/scripts_yaml.dart';
import 'package:sip_cli/domain/test_scope.dart';
import 'package:sip_cli/utils/exit_code.dart';
import 'package:sip_cli/utils/key_press_listener.dart';
import 'package:sip_cli/utils/stream_group.dart';

class TestWatchCommand extends Command<ExitCode> with TesterMixin {
  TestWatchCommand({
    required this.bindings,
    required this.findFile,
    required this.fs,
    required this.logger,
    required this.pubspecLock,
    required this.pubspecYaml,
    required this.keyPressListener,
    required this.scriptsYaml,
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
        'scope',
        help: 'The scope of tests to run',
        defaultsTo: TestScope.active.option,
        allowed: TestScope.values.map((e) => e.option).toList(),
        allowedHelp: {
          for (final val in TestScope.values) val.option: val.help,
        },
      )
      ..addFlag(
        'optimize',
        help: 'Whether to create optimized test files (Dart only)',
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

  @override
  final ScriptsYaml scriptsYaml;

  final KeyPressListener keyPressListener;

  void writeWaitingMessage(TestScope scope, {required bool runConcurrently}) {
    var testScope = darkGray.wrap('Test Scope: ')!;
    testScope += magenta.wrap(scope.option)!;
    testScope += darkGray.wrap(' (${scope.help})')!;

    testScope += darkGray.wrap(
      '\n  Press `t` to cycle ${TestScope.values.map((e) => e.option)}',
    )!;
    testScope = darkGray.wrap(testScope)!;

    var concurrent = darkGray.wrap('Concurrency: ')!;

    if (runConcurrently) {
      concurrent += green.wrap('ON')!;
    } else {
      concurrent += darkGray.wrap('OFF')!;
    }
    concurrent += darkGray.wrap('\n  Press `c` to toggle concurrency')!;

    final waitingMessage = '''

${yellow.wrap('Waiting for changes...')}
$testScope
$concurrent
${darkGray.wrap('Press `r` to run tests again')}
${darkGray.wrap('Press `q` to exit')}
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
        TestScope.options[argResults['scope'] as String] ?? TestScope.active;

    warnDartOrFlutterTests(
      isFlutterOnly: isFlutterOnly,
      isDartOnly: isDartOnly,
    );

    final pubspecs = await pubspecYaml.all(recursive: isRecursive);

    final testDirsResult = getTestDirs(
      pubspecs,
      isFlutterOnly: isFlutterOnly,
      isDartOnly: isDartOnly,
    );

    if (testDirsResult.$2 case final ExitCode exitCode) {
      return exitCode;
    }

    final (testDirs, dirTools) = testDirsResult.$1!;

    final testsResult = getPackagesToTest(
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
    var runConcurrently = concurrent;

    Iterable<PackageToTest>? lastTests;

    // This setup up will not include any new packages created,
    // only the ones that exist when the command is run
    while (true) {
      if (printMessage) {
        writeWaitingMessage(
          runType,
          runConcurrently: runConcurrently,
        );
      }

      printMessage = false;

      final (type: event, :file) = await waitForChange(
        testDirs: testDirs,
        libDirs: libDirs,
        printMessage: () => writeWaitingMessage(
          runType,
          runConcurrently: runConcurrently,
        ),
      );

      if (event.isExit) {
        break;
      }

      if (event.isToggleModified) {
        runType = TestScope.toggle(runType);
        printMessage = true;
        lastTests = null;
        continue;
      }

      if (event.isToggleConcurrency) {
        runConcurrently = !runConcurrently;
        printMessage = true;
        continue;
      }

      final testsToRun = <PackageToTest>{};

      if (!event.isRun) {
        if (file == null) {
          logger.detail('No file changed, waiting for changes...');
          continue;
        }

        if (file.endsWith(TesterMixin.optimizedTestBasename)) {
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
        final packageToTest = await findTest(
          tests,
          file,
          returnTestFile: runType.isModified,
        );

        if (packageToTest == null) {
          logger.detail('No test found for $file, waiting for changes...');
          continue;
        }

        logger.info('Running tests for ${path.relative(file)}');

        testsToRun.add(packageToTest);
      }

      lastTests = testsToRun;

      printMessage = true;

      final commandsToRun = getCommandsToRun(
        testsToRun,
        flutterArgs: flutterArgs,
        dartArgs: dartArgs,
      );

      final exitCode = await runCommands(
        commandsToRun,
        runConcurrently: runConcurrently,
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

      cleanUpOptimizedFiles(tests.map((e) => e.optimizedPath));

      done.complete('Optimized test files cleaned!');
    }

    return ExitCode.success;
  }

  Future<PackageToTest?> findTest(
    Iterable<PackageToTest> packagesToTest,
    String modifiedFile, {
    required bool returnTestFile,
  }) async {
    PackageToTest? testResult;

    final sorted = [...packagesToTest]
      ..sort((a, b) => b.packagePath.length.compareTo(a.packagePath.length));

    for (final packageToTest in sorted) {
      if (modifiedFile.startsWith(packageToTest.packagePath)) {
        final libSegments = path.split(packageToTest.packagePath);
        final modifiedSegments = path.split(modifiedFile);

        if (libSegments.length > modifiedSegments.length) {
          continue;
        }

        final segments = modifiedSegments.skip(libSegments.length).toList();

        final libIndex = segments.indexOf('lib');
        final testIndex = segments.indexOf('test');
        if ((libIndex != 0) & (testIndex != 0)) {
          continue;
        }

        testResult = packageToTest;
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
    final possibleFiles = await findFile.childrenOf(
      nameOfTest,
      directoryPath: path.join(testResult.packagePath, 'test'),
    );

    if (possibleFiles.isEmpty) {
      return null;
    }

    if (possibleFiles.length == 1) {
      testResult.optimizedPath = possibleFiles.first;
      return testResult;
    }

    final libPath = path.join(testResult.packagePath, 'lib');
    final modifiedFileInLib = modifiedFile
        .replaceAll(libPath, path.join(testResult.packagePath, 'test'))
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
          testResult.optimizedPath = test;
          return testResult;
        }
      }
    }

    return null;
  }

  Future<
      ({
        EventType type,
        String? file,
      })> waitForChange({
    required Iterable<String> testDirs,
    required Iterable<String> libDirs,
    required void Function() printMessage,
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
          EventType type,
          String? file,
        })>();

    final input = keyPressListener.listenToKeystrokes(
      onExit: () {
        fileChangeCompleter.complete(
          (
            type: EventType.exit,
            file: null,
          ),
        );
      },
      onEscape: printMessage,
      customStrokes: {
        'r': () {
          fileChangeCompleter.complete(
            (
              type: EventType.run,
              file: null,
            ),
          );
        },
        't': () {
          fileChangeCompleter.complete(
            (
              type: EventType.toggleModified,
              file: null,
            ),
          );
        },
        'c': () {
          fileChangeCompleter.complete(
            (
              type: EventType.toggleConcurrency,
              file: null,
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
              type: EventType.file,
              file: file,
            ),
          ),
        );

    final result = await fileChangeCompleter.future;
    await fileChangeListener.cancel();
    await inputSubscription?.cancel();

    return result;
  }
}

enum EventType {
  exit,
  file,
  run,
  toggleModified,
  toggleConcurrency;

  const EventType();

  bool get isExit => this == EventType.exit;
  bool get isFile => this == EventType.file;
  bool get isRun => this == EventType.run;
  bool get isToggleModified => this == EventType.toggleModified;
  bool get isToggleConcurrency => this == EventType.toggleConcurrency;
}
