// ignore_for_file: cascade_invocations

import 'package:args/args.dart';
import 'package:args/command_runner.dart';
import 'package:file/file.dart';
import 'package:mason_logger/mason_logger.dart' hide ExitCode;
import 'package:sip_cli/commands/test_command/tester_mixin.dart';
import 'package:sip_cli/domain/find_file.dart';
import 'package:sip_cli/utils/exit_code.dart';
import 'package:sip_script_runner/sip_script_runner.dart';

class TestRunCommand extends Command<ExitCode> with TesterMixin {
  TestRunCommand({
    required this.pubspecYaml,
    required this.bindings,
    required this.pubspecLock,
    required this.findFile,
    required this.fs,
    required this.logger,
  }) : argParser = ArgParser(usageLineLength: 120) {
    addTestFlags(this);

    argParser.addSeparator(cyan.wrap('SIP Flags:')!);
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
  }

  @override
  bool get hidden => true;

  /// A single-line template for how to invoke this command (e.g. `"pub get
  /// `package`"`).
  @override
  String get invocation {
    final parents = <String>[];
    for (var command = parent; command != null; command = command.parent) {
      parents.add(command.name);
    }
    parents.add(runner!.executableName);

    final invocation = parents.reversed.join(' ');
    return subcommands.isNotEmpty
        ? '$invocation <subcommand> [arguments]'
        : '$invocation [arguments]';
  }

  @override
  final ArgParser argParser;

  @override
  final PubspecYaml pubspecYaml;

  @override
  late final FileSystem fs;

  @override
  late final Logger logger;

  @override
  final Bindings bindings;

  @override
  final PubspecLock pubspecLock;

  @override
  final FindFile findFile;

  @override
  String get description => 'Run flutter or dart tests';

  @override
  String get name => 'run';

  @override
  Future<ExitCode> run([List<String>? args]) async {
    final argResults = args != null ? argParser.parse(args) : super.argResults!;

    final isDartOnly =
        argResults.wasParsed('dart-only') && argResults['dart-only'] as bool;

    final isFlutterOnly = argResults.wasParsed('flutter-only') &&
        argResults['flutter-only'] as bool;

    final isBoth = isDartOnly == isFlutterOnly;

    final isRecursive = argResults['recursive'] as bool? ?? false;

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

    final testDirsResult = getTestDirs(
      pubspecs,
      isFlutterOnly: isFlutterOnly,
      isDartOnly: isDartOnly,
    );

    // exit code is not null
    if (testDirsResult.$2 case final ExitCode exitCode) {
      return exitCode;
    }

    final (testDirs, dirTools) = testDirsResult.$1!;

    final optimize = argResults['optimize'] as bool;

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

    final (:both, :dart, :flutter) = getArgs(this);

    final flutterArgs = [...flutter, ...both];
    final dartArgs = [...dart, ...both];
    final commandsToRun = getCommandsToRun(
      tests,
      flutterArgs: flutterArgs,
      dartArgs: dartArgs,
    );

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
      runConcurrently: argResults['concurrent'] as bool,
      bail: argResults['bail'] as bool,
    );

    logger.write('\n');

    if (optimize && argResults['clean'] as bool) {
      final done = logger.progress('Cleaning up optimized test files');

      cleanUp(tests.keys);

      done.complete('Optimized test files cleaned!');
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
