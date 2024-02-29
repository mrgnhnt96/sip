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
import 'package:sip_cli/setup/setup.dart';
import 'package:sip_cli/utils/determine_flutter_or_dart.dart';
import 'package:sip_cli/utils/exit_code.dart';
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
    final pubspecs = <String>[];

    if (argResults!['recursive'] as bool) {
      final allFiles = fs.directory('.').listSync(recursive: true);

      for (final file in allFiles) {
        if (path.basename(file.path) == 'pubspec.yaml') {
          pubspecs.add(file.path);
        }
      }
    } else {
      final pubspec = await pubspecYaml.nearest();

      if (pubspec == null) {
        console.e('No pubspec.yaml found');
        return ExitCode.unavailable;
      }

      pubspecs.add(pubspec);
    }
    final children = await pubspecYaml.children();

    final testables = <String>[];

    for (final child in children) {
      final testDirectory = path.join(path.dirname(child), 'test');

      if (!fs.directory(testDirectory).existsSync()) {
        continue;
      }

      testables.add(testDirectory);
    }

    final commandsToRun = <CommandToRun>[];
    final optimizedFiles = <String>[];
    final flutterArgs = _getFlutterArgs();
    final dartArgs = _getDartArgs();
    final bothArgs = _getBothArgs();

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

      final testables = <Testable>[];

      for (final testFile in testFiles) {
        final testable = Testable(
          absolute: testFile,
          optimizedPath: optimizedPath,
        );

        testables.add(testable);
      }

      final content = writeOptimized(testables);

      fs.file(optimizedPath).writeAsStringSync(content);
      final projectRoot = path.dirname(testable);

      final tool = DetermineFlutterOrDart(
        pubspecYaml: path.join(projectRoot, 'pubspec.yaml'),
        findFile: findFile,
        pubspecLock: pubspecLock,
      ).tool();

      final toolArgs =
          tool == 'flutter' ? flutterArgs.toList() : dartArgs.toList();

      toolArgs.addAll(bothArgs);

      final script =
          '$tool test ${path.relative(optimizedPath, from: projectRoot)} ${toolArgs.join(' ')}';

      var label = darkGray.wrap('Running (')!;
      label += cyan.wrap(tool)!;
      label += darkGray.wrap(') tests in ')!;
      label += yellow.wrap(path.relative(projectRoot))!;
      label += darkGray.wrap('\n  ${script}')!;

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

    if (argResults!['concurrent'] as bool) {
      final runMany = RunManyScripts(
        commands: commandsToRun,
        bindings: bindings,
      );

      final exitCodes = await runMany.run();

      exitCodes.printErrors(commandsToRun);

      exitCode = exitCodes.exitCode;
    } else {
      for (final command in commandsToRun) {
        final scriptRunner = RunOneScript(
          command: command,
          bindings: bindings,
        );

        final _exitCode = await scriptRunner.run();

        if (_exitCode != ExitCode.success && argResults!['bail'] as bool) {
          exitCode = _exitCode;
        }
      }
    }

    if (argResults!['clean'] as bool) {
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

class Testable {
  Testable({
    required this.absolute,
    required this.optimizedPath,
  })  : fileName = path.basenameWithoutExtension(absolute),
        relativeToOptimized =
            path.relative(absolute, from: path.dirname(optimizedPath));

  final String absolute;
  final String fileName;
  final String optimizedPath;
  final String relativeToOptimized;
}

String writeOptimized(List<Testable> testables) {
  String writeTest(Testable testable) {
    return "group('${testable.relativeToOptimized}', () => ${testable.fileName}.main());";
  }

  String writeImport(Testable testable) {
    return "import '${testable.relativeToOptimized}' as ${testable.fileName};";
  }

  return '''
import 'package:test/test.dart';
${testables.map(writeImport).join('\n')}

void main() {
  ${testables.map(writeTest).join('\n  ')}
}
''';
}
