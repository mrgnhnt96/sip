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
import 'package:sip_cli/utils/write_optimized_test_file.dart';
import 'package:sip_console/sip_console.dart';
import 'package:sip_console/utils/ansi.dart';
import 'package:sip_script_runner/sip_script_runner.dart';
import 'package:sip_cli/utils/exit_code_extensions.dart';

part '__flutter_args.dart';
part '__dart_args.dart';
part '__both_args.dart';

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
      defaultsTo: false,
      negatable: false,
    );

    argParser.addFlag(
      'concurrent',
      abbr: 'c',
      aliases: ['parallel'],
      help: 'Run tests concurrently',
      defaultsTo: false,
      negatable: false,
    );

    argParser.addFlag(
      'bail',
      abbr: 'b',
      help: 'Bail after first test failure',
      defaultsTo: false,
      negatable: false,
    );

    argParser.addFlag(
      'clean',
      help: 'Whether to remove the optimized test files after running tests',
      defaultsTo: true,
      negatable: true,
    );

    argParser.addFlag(
      'dart-only',
      help: 'Run only dart tests',
      defaultsTo: false,
      negatable: false,
    );

    argParser.addFlag(
      'flutter-only',
      help: 'Run only flutter tests',
      defaultsTo: false,
      negatable: false,
    );

    argParser.addSeparator('Dart Flags:');
    _addDartArgs();

    argParser.addSeparator('Flutter Flags:');
    _addFlutterArgs();

    argParser.addSeparator('Overlapping Flags:');
    _addBothArgs();

    // review https://github.com/dart-lang/test/tree/master/pkgs/test_core/lib/src/runner/configuration/args.dart to add dart test flags
    // review https://github.com/flutter/flutter/blob/master/packages/flutter_tools/lib/src/commands/test.dart#L82 to add flutter test flags
    fs = getIt();
    console = getIt();
  }

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

  @override
  Future<ExitCode> run([List<String>? args]) async {
    final argResults = this.argResults!;

    final dartOnly =
        argResults.wasParsed('dart-only') && argResults['dart-only'] as bool;
    final flutterOnly = argResults.wasParsed('flutter-only') &&
        argResults['flutter-only'] as bool;

    if (dartOnly) {
      console.v('Running only dart tests');
    }
    if (flutterOnly) {
      console.v('Running only flutter tests');
    }

    final pubspecs = <String>[];

    if (argResults['recursive'] as bool) {
      console.v('Running tests recursively');
      pubspecs.addAll(await pubspecYaml.children());
    } else {
      console.v('Running tests in current directory');
      final pubspec = await pubspecYaml.nearest();

      if (pubspec == null) {
        console.e('No pubspec.yaml found');
        return ExitCode.unavailable;
      }

      pubspecs.add(pubspec);
    }

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

      // we only care checking for flutter or dart tests if we are not running both
      if (flutterOnly ^ dartOnly) {
        if (tool.isFlutter && dartOnly && !flutterOnly) {
          continue;
        }

        if (tool.isDart && flutterOnly) {
          continue;
        }
      }

      testables.add(testDirectory);
      testableTool[testDirectory] = tool;
    }

    if (testables.isEmpty) {
      var forTool = '';

      if (flutterOnly ^ dartOnly) {
        forTool = ' ';
        forTool += dartOnly ? 'dart' : 'flutter';
      }
      console.e('No$forTool tests found');
      return ExitCode.unavailable;
    }

    final commandsToRun = <CommandToRun>[];
    final optimizedFiles = <String>[];
    final bothArgs = _getBothArgs();
    final flutterArgs = [..._getFlutterArgs(), ...bothArgs];
    final dartArgs = [..._getDartArgs(), ...bothArgs];

    for (final testable in testables) {
      final allFiles =
          fs.directory(testable).listSync(recursive: true, followLinks: false);

      final testFiles = <String>[];

      for (final file in allFiles) {
        final fileName = path.basename(file.path);
        if (!fileName.endsWith('_test.dart')) {
          continue;
        }

        if (fileName == '.optimized_test.dart') {
          continue;
        }

        testFiles.add(file.path);
      }

      if (testFiles.isEmpty) {
        continue;
      }

      final optimizedPath = path.join(testable, '.optimized_test.dart');
      fs.file(optimizedPath)..createSync(recursive: true);
      optimizedFiles.add(optimizedPath);

      final testables = testFiles
          .map((e) => Testable(absolute: e, optimizedPath: optimizedPath));

      final projectRoot = path.dirname(testable);
      final tool = testableTool[testable]!;

      final content =
          writeOptimizedTestFile(testables, isFlutterPackage: tool.isFlutter);

      fs.file(optimizedPath).writeAsStringSync(content);

      final toolArgs = tool.isFlutter ? flutterArgs : dartArgs;

      final command = tool.tool();

      final script =
          '$command test ${path.relative(optimizedPath, from: projectRoot)} ${toolArgs.join(' ')}';

      var label = darkGray.wrap('Running (')!;
      label += cyan.wrap(command)!;
      label += darkGray.wrap(') tests in ')!;
      label += yellow.wrap(path.relative(projectRoot))!;

      commandsToRun.add(
        CommandToRun(
          command: script,
          workingDirectory: projectRoot,
          label: label,
          runConcurrently: false,
          keys: null,
        ),
      );
    }

    ExitCode? exitCode;

    if (argResults['concurrent'] as bool) {
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

      exitCode = exitCodes.exitCode;
    } else {
      for (final command in commandsToRun) {
        console.v('${command.command}');
        final scriptRunner = RunOneScript(
          command: command,
          bindings: bindings,
        );

        final _exitCode = await scriptRunner.run();

        if (_exitCode != ExitCode.success && argResults['bail'] as bool) {
          exitCode = _exitCode;
        }
      }
    }

    if (argResults['clean'] as bool) {
      for (final optimizedFile in optimizedFiles) {
        fs.file(optimizedFile).deleteSync();
      }
    }

    if (exitCode != null && exitCode != ExitCode.success) {
      console.e('Tests failed');
    } else {
      console.s('Tests passed');
    }

    console.emptyLine();

    return exitCode ?? ExitCode.success;
  }
}
