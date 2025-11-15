// ignore_for_file: cascade_invocations

import 'package:mason_logger/mason_logger.dart';
import 'package:sip_cli/src/commands/test_command/tester_mixin.dart';
import 'package:sip_cli/src/deps/analytics.dart';
import 'package:sip_cli/src/deps/args.dart';
import 'package:sip_cli/src/deps/logger.dart';
import 'package:sip_cli/src/deps/pubspec_yaml.dart';
import 'package:sip_cli/src/domain/dart_test_args.dart';
import 'package:sip_cli/src/domain/flutter_test_args.dart';
import 'package:sip_cli/src/domain/script_to_run.dart';
import 'package:sip_cli/src/utils/list_ext.dart';
import 'package:sip_cli/src/utils/package.dart';

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
  --omit-errors                     Omit errors from the test output, only show failures
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
    final optimize = args.get<bool>('optimize', defaultValue: true);
    final isRecursive = args.get<bool>(
      'recursive',
      abbr: 'r',
      defaultValue: false,
    );
    final cleanOptimizedFiles = args.get<bool>('clean', defaultValue: true);
    final bail = args.get<bool>('bail', defaultValue: false);
    final slice = args.getOrNull<int>('slice');

    final providedTests = [...paths, ...args.rest]
      ..removeWhere((e) => e.isEmpty || e == '.');

    await analytics.track(
      'test_run',
      props: {
        'provided_paths': providedTests.isNotEmpty,
        'is_recursive': isRecursive,
        'clean_optimized_files': cleanOptimizedFiles,
        'bail': bail,
        'slice': slice,
        'is_dart_only': isDartOnly,
        'is_flutter_only': isFlutterOnly,
        'optimize': optimize,
      },
    );

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

    if (bail) {
      logger.warn('Bailing after first test failure\n');
    }

    final commandsToRun = <Runnable>[];

    void Function()? cleanUp;

    if (testsToRun != null) {
      final pkg = Package.nearest();

      final testGroups = switch (slice) {
        null => [testsToRun],
        final int count => testsToRun.chunked(count),
      };

      for (final group in testGroups) {
        final command = createTestCommand(pkg: pkg, tests: group, bail: bail);

        commandsToRun.add(command);
      }
    } else {
      final pubspecs = await pubspecYaml.all(recursive: isRecursive);

      logger.detail('Found ${pubspecs.length} pubspecs');
      for (final pubspec in pubspecs) {
        logger.detail(' - $pubspec');
      }

      final pkgs = [
        for (final pkg in pubspecs.map(Package.new))
          if (pkg.shouldInclude(
            dartOnly: isDartOnly,
            flutterOnly: isFlutterOnly,
          ))
            if (pkg.hasTests) pkg,
      ];

      logger.detail('Found ${pkgs.length} packages to test');
      for (final pkg in pkgs) {
        logger.detail(' - ${pkg.relativePath}');
      }

      if (pkgs.isEmpty) {
        logger.err('No packages found to test');
        return ExitCode.success;
      }

      commandsToRun.addAll([
        for (final pkg in pkgs)
          for (final group in pkg.testGroups)
            createTestCommand(pkg: pkg, tests: group, bail: bail),
      ]);

      cleanUp = () {
        for (final pkg in pkgs) {
          pkg.deleteOptimizedTestFile();
        }
      };
    }

    _printArgs();

    final exitCode = await runCommands(
      commandsToRun,
      showOutput: !args.get<bool>('concurrent', defaultValue: false),
      bail: bail,
    );

    logger.write('\n');

    if (optimize && cleanOptimizedFiles) {
      cleanUp?.call();
    }

    return exitCode;
  }

  void _printArgs() {
    final flutterArgs = const FlutterTestArgs().arguments;
    final dartArgs = const DartTestArgs().arguments;

    logger.detail('ARGS:');

    if (dartArgs.isNotEmpty) {
      var message = darkGray.wrap('  Dart:    ')!;
      if (dartArgs.isEmpty) {
        message += cyan.wrap('NONE')!;
      } else {
        message += cyan.wrap(dartArgs.join(', '))!;
      }
      logger.detail(message);
    }

    if (flutterArgs.isNotEmpty) {
      var message = darkGray.wrap('  Flutter: ')!;
      if (flutterArgs.isEmpty) {
        message += cyan.wrap('NONE')!;
      } else {
        message += cyan.wrap(flutterArgs.join(', '))!;
      }
      logger.detail(message);
    }

    logger.detail('\n');
  }
}
