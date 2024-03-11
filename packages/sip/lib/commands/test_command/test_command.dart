// ignore_for_file: cascade_invocations

import 'package:args/args.dart';
import 'package:args/command_runner.dart';
import 'package:file/file.dart';
import 'package:mason_logger/mason_logger.dart' hide ExitCode;
import 'package:sip_cli/commands/test_command/tester_mixin.dart';
import 'package:sip_cli/commands/test_watch_command.dart';
import 'package:sip_cli/domain/any_arg_parser.dart';
import 'package:sip_cli/domain/find_file.dart';
import 'package:sip_cli/utils/exit_code.dart';
import 'package:sip_script_runner/sip_script_runner.dart';

part '__both_args.dart';
part '__dart_args.dart';
part '__flutter_args.dart';

class TestCommand extends Command<ExitCode> with TesterMixin {
  TestCommand({
    required this.pubspecYaml,
    required this.bindings,
    required this.pubspecLock,
    required this.findFile,
    required this.fs,
    required this.logger,
  }) : argParser = ArgParser(usageLineLength: 120) {
    addSubcommand(TestWatchCommand());

    argParser.addSeparator(cyan.wrap('Dart Flags:')!);
    _addDartArgs();

    argParser.addSeparator(cyan.wrap('Flutter Flags:')!);
    _addFlutterArgs();

    argParser.addSeparator(cyan.wrap('Overlapping Flags:')!);
    _addBothArgs();

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
  String get name => 'test';

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

    if (tests.isEmpty) {
      logger.err('No tests found');
      return ExitCode.unavailable;
    }

    final bothArgs = _getBothArgs();
    final flutterArgs = [..._getFlutterArgs(), ...bothArgs];
    final dartArgs = [..._getDartArgs(), ...bothArgs];
    final commandsToRun = getCommandsToRun(
      tests,
      optimize: optimize,
      flutterArgs: flutterArgs,
      dartArgs: dartArgs,
    );

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
