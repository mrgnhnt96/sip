// ignore_for_file: cascade_invocations

import 'package:args/args.dart';
import 'package:args/command_runner.dart';
import 'package:file/file.dart';
import 'package:path/path.dart' as path;
import 'package:sip_cli/domain/any_arg_parser.dart';
import 'package:sip_cli/domain/find_file.dart';
import 'package:sip_cli/domain/pubspec_lock_impl.dart';
import 'package:sip_cli/domain/pubspec_yaml_impl.dart';
import 'package:sip_cli/domain/run_many_scripts.dart';
import 'package:sip_cli/domain/run_one_script.dart';
import 'package:sip_cli/domain/testable.dart';
import 'package:sip_cli/setup/setup.dart';
import 'package:sip_cli/utils/determine_flutter_or_dart.dart';
import 'package:sip_cli/utils/exit_code.dart';
import 'package:sip_cli/utils/exit_code_extensions.dart';
import 'package:sip_cli/utils/write_optimized_test_file.dart';
import 'package:sip_console/sip_console.dart';
import 'package:sip_console/utils/ansi.dart';
import 'package:sip_script_runner/sip_script_runner.dart';

part '__both_args.dart';
part '__dart_args.dart';
part '__flutter_args.dart';

class TestCommand extends Command<ExitCode> {
  TestCommand({
    this.pubspecYaml = const PubspecYamlImpl(),
    this.bindings = const BindingsImpl(),
    this.pubspecLock = const PubspecLockImpl(),
    this.findFile = const FindFile(),
  }) {
    argParser.addFlag(
      'recursive',
      abbr: 'r',
      help: 'Run tests in subdirectories',
      negatable: false,
    );

    argParser.addFlag(
      'concurrent',
      abbr: 'c',
      aliases: ['parallel'],
      help: 'Run tests concurrently',
      negatable: false,
    );

    argParser.addFlag(
      'bail',
      abbr: 'b',
      help: 'Bail after first test failure',
      negatable: false,
    );

    argParser.addFlag(
      'clean',
      help: 'Whether to remove the optimized test files after running tests',
      defaultsTo: true,
    );

    argParser.addFlag(
      'dart-only',
      help: 'Run only dart tests',
      negatable: false,
    );

    argParser.addFlag(
      'flutter-only',
      help: 'Run only flutter tests',
      negatable: false,
    );

    argParser.addSeparator('Dart Flags:');
    _addDartArgs();

    argParser.addSeparator('Flutter Flags:');
    _addFlutterArgs();

    argParser.addSeparator('Overlapping Flags:');
    _addBothArgs();

    fs = getIt();
    console = getIt();
  }

  static const String optimizedTestFileName = '.optimized_test.dart';

  final PubspecYaml pubspecYaml;
  late final FileSystem fs;
  late final SipConsole console;
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
      console.v('Running tests recursively');
      final children = await pubspecYaml.children();
      pubspecs.addAll(children.map((e) => path.join(path.separator, e)));
    }

    return pubspecs.toList();
  }

  (
    List<String> testables,
    Map<String, DetermineFlutterOrDart> testableTool,
  ) getTestables(
    List<String> pubspecs, {
    required bool isFlutterOnly,
    required bool isDartOnly,
  }) {
    final testables = <String>[];
    final testableTool = <String, DetermineFlutterOrDart>{};

    console
        .v('Found ${pubspecs.length} pubspecs, checking for test directories');
    for (final pubspec in pubspecs) {
      final projectRoot = path.dirname(pubspec);
      final testDirectory = path.join(path.dirname(pubspec), 'test');

      if (!fs.directory(testDirectory).existsSync()) {
        console.v('No test directory found in ${path.relative(projectRoot)}');
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

      testables.add(testDirectory);
      testableTool[testDirectory] = tool;
    }

    return (testables, testableTool);
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

  List<CommandToRun> getCommandsToRun(
    Map<String, DetermineFlutterOrDart> optimizedFiles, {
    required List<String> flutterArgs,
    required List<String> dartArgs,
  }) {
    final commandsToRun = <CommandToRun>[];

    for (final MapEntry(key: optimizedPath, value: tool)
        in optimizedFiles.entries) {
      final projectRoot = path.dirname(path.dirname(optimizedPath));

      final toolArgs = tool.isFlutter ? flutterArgs : dartArgs;

      final command = tool.tool();

      final testPath = path.relative(optimizedPath, from: projectRoot);

      final script = '$command test $testPath ${toolArgs.join(' ')}';

      var label = darkGray.wrap('Running (')!;
      label += cyan.wrap(command)!;
      label += darkGray.wrap(') tests in ')!;
      label += yellow.wrap(path.relative(projectRoot))!;

      commandsToRun.add(
        CommandToRun(
          command: script,
          workingDirectory: projectRoot,
          label: label,
          keys: null,
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
      console.w('Running (${commandsToRun.length}) tests concurrently');

      for (final command in commandsToRun) {
        console.v('Script: ${darkGray.wrap(command.command)}');
      }

      final runMany = RunManyScripts(
        commands: commandsToRun,
        bindings: bindings,
      );

      final exitCodes = await runMany.run();

      exitCodes.printErrors(commandsToRun);

      return exitCodes.exitCode;
    }

    ExitCode? exitCode;

    for (final command in commandsToRun) {
      console.v(command.command);
      final scriptRunner = RunOneScript(
        command: command,
        bindings: bindings,
      );

      final exitCode0 = await scriptRunner.run();

      if (exitCode0 != ExitCode.success) {
        exitCode = exitCode0;

        if (bail) {
          return exitCode;
        }
      }
    }

    return exitCode ?? ExitCode.success;
  }

  void cleanUp(Iterable<String> optimizedFiles) {
    for (final optimizedFile in optimizedFiles) {
      fs.file(optimizedFile).deleteSync();
    }
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
        console.l('Running only dart tests');
      } else if (isFlutterOnly && !isDartOnly) {
        console.l('Running only flutter tests');
      } else {
        console.l('Running both dart and flutter tests');
      }
    }

    final pubspecs = await this.pubspecs(isRecursive: isRecursive);

    if (pubspecs.isEmpty) {
      console.e('No pubspec.yaml files found');
      return ExitCode.unavailable;
    }

    final (testables, testableTool) = getTestables(
      pubspecs,
      isFlutterOnly: isFlutterOnly,
      isDartOnly: isDartOnly,
    );

    if (testables.isEmpty) {
      var forTool = '';

      if (isFlutterOnly ^ isDartOnly) {
        forTool = ' ';
        forTool += isDartOnly ? 'dart' : 'flutter';
      }
      console.e('No$forTool tests found');
      return ExitCode.unavailable;
    }

    final optimizedFiles = writeOptimizedFiles(testables, testableTool);

    final bothArgs = _getBothArgs();
    final flutterArgs = [..._getFlutterArgs(), ...bothArgs];
    final dartArgs = [..._getDartArgs(), ...bothArgs];
    final commandsToRun = getCommandsToRun(
      optimizedFiles,
      flutterArgs: flutterArgs,
      dartArgs: dartArgs,
    );

    final exitCode = await runCommands(
      commandsToRun,
      runConcurrently: argResults['concurrent'] as bool,
      bail: argResults['bail'] as bool,
    );

    if (argResults['clean'] as bool) {
      cleanUp(optimizedFiles.keys);
    }

    if (exitCode != ExitCode.success) {
      console.e('Tests failed');
    } else {
      console.s('Tests passed');
    }

    console.emptyLine();

    return exitCode;
  }
}
