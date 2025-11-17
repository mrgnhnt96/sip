import 'dart:convert';

import 'package:file/file.dart';
import 'package:glob/glob.dart';
import 'package:mason_logger/mason_logger.dart';
import 'package:sip_cli/src/deps/fs.dart';
import 'package:sip_cli/src/deps/logger.dart';
import 'package:sip_cli/src/deps/script_runner.dart';
import 'package:sip_cli/src/domain/dart_test_args.dart';
import 'package:sip_cli/src/domain/flutter_test_args.dart';
import 'package:sip_cli/src/domain/message_action.dart';
import 'package:sip_cli/src/domain/script_to_run.dart';
import 'package:sip_cli/src/domain/test_data.dart';
import 'package:sip_cli/src/utils/package.dart';

abstract mixin class TesterMixin {
  const TesterMixin();

  static const String optimizedTestBasename = '.test_optimizer';

  void warnDartOrFlutterTests({
    required bool isFlutterOnly,
    required bool isDartOnly,
  }) {
    if (isDartOnly || isFlutterOnly) {
      if (isDartOnly && !isFlutterOnly) {
        logger.info('Running only dart tests');
      } else if (isFlutterOnly && !isDartOnly) {
        logger.info('Running only flutter tests');
      } else {
        logger.info('Running both dart and flutter tests');
      }
    }
  }

  String packageRootFor(String filePath) {
    final parts = fs.path.split(filePath);

    String root;
    if (parts.contains('test')) {
      root = parts.sublist(0, parts.indexOf('test')).join(fs.path.separator);
    } else if (parts.contains('lib')) {
      root = parts.sublist(0, parts.indexOf('lib')).join(fs.path.separator);
    } else {
      if (fs.isFileSync(filePath)) {
        root = fs.path.basename(fs.path.dirname(filePath));
      } else {
        root = fs.path.basename(filePath);
      }
    }

    if (root.isEmpty) {
      root = '.';
    }

    return root;
  }

  Runnable createTestCommand({
    required Package pkg,
    required List<String> tests,
    required bool bail,
  }) {
    final toolArgs = switch (pkg) {
      Package(isFlutter: true) => const FlutterTestArgs().arguments,
      Package(isDart: true) => const DartTestArgs().arguments,
      _ => <String>[],
    };

    final command = pkg.tool;

    final script = ['$command test', ...toolArgs, ...tests].join(' ').trim();

    logger.detail('\nTest command: $script');

    final label = [
      ?darkGray.wrap('Running ('),
      ?cyan.wrap(command),
      ?darkGray.wrap(') tests in '),
      ?darkGray.wrap(fs.path.relative(pkg.path)),
      ?darkGray.wrap(fs.path.separator),
      ?yellow.wrap(pkg.relativePath),
    ].join();

    return ScriptToRun(
      script,
      workingDirectory: pkg.path,
      label: label,
      bail: bail,
      runInParallel: true,
      data: pkg,
    );
  }

  Future<ExitCode> runCommands(
    List<Runnable> commandsToRun, {
    required bool showOutput,
    required bool bail,
  }) async {
    final labels = {
      for (final command in commandsToRun)
        switch (command) {
          ScriptToRun(:final label) => label,
          _ => null,
        },
    }.whereType<String>();

    for (final label in labels) {
      logger.info(label);
    }

    final data = TestData();

    var killEverything = false;
    var canKill = false;

    var snapshot = (passing: 0, failing: 0, skipped: 0);

    try {
      await scriptRunner.run(
        commandsToRun,
        bail: bail,
        logTime: false,
        printLabels: false,
        onMessage: (runnable, message) {
          if (message.message.contains(
            'The Dart compiler exited unexpectedly',
          )) {
            logger
              ..err('The Dart compiler exited unexpectedly')
              ..write(message.message);

            data.addError(runnable, 'The Dart compiler exited unexpectedly');

            return MessageAction.kill;
          }

          final lines = const LineSplitter().convert(message.message.trim());
          final tests = <String>[];
          final buf = StringBuffer();
          final timePattern = RegExp(r'^\d{2,}:\d{2,}');

          for (final line in lines) {
            if (timePattern.hasMatch(line)) {
              if (buf.isNotEmpty) {
                tests.add(buf.toString());
                buf.clear();
              }
            }

            buf.writeln(line);
          }

          if (buf.isNotEmpty) {
            tests.add(buf.toString());
          }

          for (final test in tests) {
            data.parse(runnable, test);
          }

          if (bail) {
            // setup to fail on next
            if (data.failing > 0 && !canKill) {
              snapshot = data.snapshot;
              canKill = true;
              return null;
            }

            if (canKill && !killEverything) {
              // wait till we have all the error data
              if (data.snapshot == snapshot) {
                return null;
              }

              killEverything = true;
            } else if (killEverything) {
              return MessageAction.kill;
            }
          }

          return null;
        },
      );
    } catch (e) {
      data.addError(null, e);
    }

    data.printResults();

    if (data.failing > 0 || data.allFailures.isNotEmpty) {
      return ExitCode.software;
    }

    return ExitCode.success;
  }

  void cleanUpOptimizedFiles(Iterable<String?> optimizedFiles) {
    for (final optimizedFile in optimizedFiles) {
      if (optimizedFile == null) continue;

      if (!optimizedFile.contains(optimizedTestBasename)) continue;

      fs.file(optimizedFile).deleteSync();
    }
  }

  Future<List<String>> getTestsFromProvided(List<String> providedTests) async {
    final testsToRun = <String>[];
    final glob = Glob('**/*_test.dart', recursive: true);

    for (final path in providedTests) {
      final fileOrDir = switch (path) {
        '.' => fs.currentDirectory.path,
        _ => path,
      };

      if (fs.isFileSync(fileOrDir)) {
        if (fs.path.basename(fileOrDir).endsWith('_test.dart')) {
          testsToRun.add(fileOrDir);
        }
      } else if (fs.isDirectorySync(fileOrDir)) {
        final results = glob.listFileSystemSync(
          fs,
          followLinks: false,
          root: fileOrDir,
        );
        final files = results.whereType<File>();

        final directories = {for (final file in files) file.parent.path};

        testsToRun.addAll(directories);
      } else {
        logger.err('File or directory not found: $fileOrDir');
      }
    }

    logger.detail('Running tests: \n  - ${testsToRun.join('\n  - ')}');
    return testsToRun;
  }
}
