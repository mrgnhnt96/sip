import 'dart:async';

import 'package:args/args.dart';
import 'package:args/command_runner.dart';
import 'package:file/file.dart';
import 'package:mason_logger/mason_logger.dart' hide ExitCode;
import 'package:path/path.dart' as path;
import 'package:sip_cli/commands/test_command/tester_mixin.dart';
import 'package:sip_cli/domain/find_file.dart';
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
      ..addFlag(
        'modified',
        help: 'Re-run the test file associated with the most '
            'recent changed file\n'
            'eg. Edit `lib/foo.dart` will re-run `test/foo_test.dart`',
        negatable: false,
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

  void writeWaitingMessage() {
    final waitingMessage = '''

${yellow.wrap('Waiting for changes...')}
${darkGray.wrap('Press `q` to exit')}
${darkGray.wrap('Press `r` to run all tests')}
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
    final modified =
        argResults.wasParsed('modified') && argResults['modified'] as bool;

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

    // This setup up will not include any new packages created,
    // only the ones that exist when the command is run
    while (true) {
      if (printMessage) {
        writeWaitingMessage();
      }

      printMessage = false;

      final (:exit, :file, :runAll) = await waitForChange(
        testDirs: testDirs,
        libDirs: libDirs,
      );

      if (exit) {
        break;
      }

      final testsToRun = <String, DetermineFlutterOrDart>{};

      if (!runAll) {
        if (file == null) {
          logger.detail('No file changed, waiting for changes...');
          continue;
        }

        if (file.endsWith(TesterMixin.optimizedTestFileName)) {
          logger.detail('Optimized test file changed, waiting for changes...');
          continue;
        }

        final testDirResult = findTestDir(tests, file);

        if (testDirResult == null) {
          logger.detail('No test directory found for $file');
          continue;
        }

        logger.info('Running tests for ${path.relative(file)}');

        final (testDir, tool) = testDirResult;
        testsToRun[testDir] = tool;
      } else {
        logger.info('Running all tests');
        testsToRun.addAll(tests);
      }

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

  (String testDir, DetermineFlutterOrDart tool)? findTestDir(
    Map<String, DetermineFlutterOrDart> tests,
    String modifiedFile,
  ) {
    // {<directory>, <key>}
    final keys = <String, String>{};

    for (final test in tests.keys) {
      if (fs.isFileSync(test)) {
        keys[fs.file(test).parent.path] = test;
      } else {
        keys[test] = test;
      }
    }

    for (final MapEntry(key: directory, value: test) in keys.entries) {
      // check if the modified file is in the test directory
      if (modifiedFile.startsWith(directory)) {
        return (directory, tests[test]!);
      }

      // check if the modified file is in the lib directory
      // associated with the test directory
      // eg. lib/foo.dart -> test/foo_test.dart
      final libDir = directory.replaceAll(RegExp(r'test$'), 'lib');
      if (modifiedFile.startsWith(libDir)) {
        return (directory, tests[test]!);
      }
    }

    return null;
  }

  Future<({bool exit, String? file, bool runAll})> waitForChange({
    required Iterable<String> testDirs,
    required Iterable<String> libDirs,
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

    final fileChangeCompleter =
        Completer<({bool exit, String? file, bool runAll})>();

    final input = keyPressListener.listenToKeystrokes(
      onExit: () {
        fileChangeCompleter.complete((exit: true, file: null, runAll: false));
      },
      onRunAll: () {
        fileChangeCompleter.complete((exit: false, file: null, runAll: true));
      },
      onEscape: writeWaitingMessage,
    );

    StreamSubscription<void>? inputSubscription;
    inputSubscription = input?.listen((_) {});

    final fileChangeListener = StreamGroup(fileModifications).merge().listen(
          (file) => fileChangeCompleter.complete(
            (exit: false, file: file, runAll: false),
          ),
        );

    final (:exit, :file, :runAll) = await fileChangeCompleter.future;
    await fileChangeListener.cancel();
    await inputSubscription?.cancel();

    return (exit: exit, file: file, runAll: runAll);
  }
}
