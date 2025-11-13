// ignore_for_file: cascade_invocations

import 'dart:math';

import 'package:mason_logger/mason_logger.dart';
import 'package:path/path.dart' as path;
import 'package:sip_cli/src/commands/test_command/tester_mixin.dart';
import 'package:sip_cli/src/deps/args.dart';
import 'package:sip_cli/src/deps/logger.dart';
import 'package:sip_cli/src/deps/pubspec_yaml.dart';
import 'package:sip_cli/src/domain/dart_test_args.dart';
import 'package:sip_cli/src/domain/flutter_test_args.dart';
import 'package:sip_cli/src/domain/script_to_run.dart';
import 'package:sip_cli/src/utils/determine_flutter_or_dart.dart';

const _usage = '''
Usage: sip test <...files or directories> [arguments]

Run flutter or dart tests

Flags:
  --help                            Print usage information
  --recursive, -r                   Run tests in subdirectories
  --[no-]concurrent, -c             Run tests concurrently
  --bail                            Bail after first test failure
  --clean                           Remove the optimized test files after running tests
                                      (default: true)
  --dart-only                       Run only dart tests
  --flutter-only                    Run only flutter tests
  --optimize                        Create optimized test files (Dart only)
                                      (default: true)
  --slice [count]                   Splits test files into chunks and runs them concurrently
---

Include any dart or flutter args run `dart test --help` or `flutter test --help`
for more information.
''';

class TestRunCommand with TesterMixin {
  const TestRunCommand();

  Future<ExitCode> run(List<String> paths) async {
    if (args.get<bool>('help', defaultValue: false)) {
      logger.write(_usage);
      return ExitCode.success;
    }

    final isDartOnly = args.get<bool>('dart-only', defaultValue: false);
    final isFlutterOnly = args.get<bool>('flutter-only', defaultValue: false);
    final isBoth = isDartOnly == isFlutterOnly;
    final optimize = args.get<bool>('optimize', defaultValue: true);
    final isRecursive = args.get<bool>('recursive', defaultValue: false);
    final cleanOptimizedFiles = args.get<bool>('clean', defaultValue: true);
    final bail = args.get<bool>('bail', defaultValue: false);
    final slice = args.getOrNull<int>('slice');

    final providedTests = [...paths, ...args.rest];

    List<String>? testsToRun;
    if (providedTests.isNotEmpty) {
      testsToRun = await getTestsFromProvided(providedTests);

      if (testsToRun.isEmpty) {
        logger.err('No valid files or directories found');
        return ExitCode.usage;
      }
    }

    if (isRecursive && testsToRun != null) {
      logger.err(
        'Cannot run tests recursively with specific files or directories',
      );
      return ExitCode.usage;
    }

    warnDartOrFlutterTests(
      isFlutterOnly: isFlutterOnly,
      isDartOnly: isDartOnly,
    );

    if (isRecursive) {
      logger.detail('Running tests recursively');
    }

    final pubspecs = await pubspecYaml.all(recursive: isRecursive);

    if (pubspecs.isEmpty) {
      logger.err('No pubspec.yaml files found');
      return ExitCode.unavailable;
    }

    final flutterArgs = const FlutterTestArgs().arguments;
    final dartArgs = const DartTestArgs().arguments;

    if (bail) {
      logger.warn('Bailing after first test failure\n');
    }

    final commandsToRun = <Runnable>[];

    void Function()? cleanUp;

    if (testsToRun != null) {
      final pubspec = pubspecYaml.nearest();

      if (pubspec == null) {
        logger.err('No pubspec.yaml file found');
        return ExitCode.unavailable;
      }

      final tool = DetermineFlutterOrDart(pubspec);

      final groups = switch (slice) {
        null => [testsToRun],
        final int count => testsToRun.chunked(count),
      };

      for (final group in groups) {
        final command = createTestCommand(
          projectRoot: tool.directory(),
          relativeProjectRoot: path.relative(tool.directory()),
          pathToProjectRoot: tool.directory(),
          tool: tool,
          flutterArgs: flutterArgs,
          dartArgs: dartArgs,
          tests: group,
          bail: bail,
        );

        commandsToRun.add(command);
      }
    } else {
      final (dirs, dirExitCode) = getTestDirs(
        pubspecs,
        isFlutterOnly: isFlutterOnly,
        isDartOnly: isDartOnly,
      );

      // exit code is not null
      if (dirExitCode case final ExitCode exitCode) {
        return exitCode;
      } else if (dirs == null) {
        logger.err('No tests found');
        return ExitCode.success;
      }

      final (testDirs, dirTools) = dirs;
      logger.detail('Found ${testDirs.length} test directories');
      logger.detail('  - ${testDirs.join('\n  - ')}');

      final (tests, testsExitCode) = getPackagesToTest(
        testDirs,
        dirTools,
        optimize: optimize,
      );

      // exit code is not null
      if (testsExitCode case final ExitCode exitCode) {
        return exitCode;
      } else if (tests == null) {
        logger.err('No tests found');
        return ExitCode.success;
      }

      commandsToRun.addAll(
        getCommandsToRun(
          tests,
          flutterArgs: flutterArgs,
          dartArgs: dartArgs,
          bail: bail,
        ),
      );

      cleanUp = () => cleanUpOptimizedFiles(tests.map((e) => e.optimizedPath));
    }

    logger.info('ARGS:');

    if (isBoth || isDartOnly) {
      var message = darkGray.wrap('  Dart:    ')!;
      if (dartArgs.isEmpty) {
        message += cyan.wrap('NONE')!;
      } else {
        message += cyan.wrap(dartArgs.join(', '))!;
      }
      logger.info(message);
    }

    if (isBoth || isFlutterOnly) {
      var message = darkGray.wrap('  Flutter: ')!;
      if (flutterArgs.isEmpty) {
        message += cyan.wrap('NONE')!;
      } else {
        message += cyan.wrap(flutterArgs.join(', '))!;
      }
      logger.info(message);
    }

    logger.write('\n');

    final exitCode = await runCommands(
      commandsToRun,
      showOutput: !args.get<bool>('concurrent', defaultValue: false),
      bail: bail,
    );

    logger.write('\n');

    if (optimize && cleanOptimizedFiles) {
      final done = logger.progress('Cleaning up optimized test files');

      cleanUp?.call();

      done.complete('Optimized test files cleaned!');
    }

    return exitCode;
  }
}

extension _ListT<T> on List<T> {
  List<List<T>> chunked(int count) {
    final chunks = <List<T>>[];

    for (var i = 0; i < length; i += count) {
      chunks.add(sublist(i, min(i + count, length)));
    }

    return chunks;
  }
}
