import 'dart:convert';

import 'package:file/file.dart';
import 'package:glob/glob.dart';
import 'package:mason_logger/mason_logger.dart';
import 'package:sip_cli/src/deps/fs.dart';
import 'package:sip_cli/src/deps/logger.dart';
import 'package:sip_cli/src/deps/script_runner.dart';
import 'package:sip_cli/src/domain/command_result.dart';
import 'package:sip_cli/src/domain/dart_test_args.dart';
import 'package:sip_cli/src/domain/flutter_test_args.dart';
import 'package:sip_cli/src/domain/message.dart';
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
    List<String>? providedPaths,
    List<List<String>>? bucketFileGroups,
  }) {
    final toolArgs = switch (pkg) {
      Package(isFlutter: true) => const FlutterTestArgs().arguments,
      Package(isDart: true) => const DartTestArgs().arguments,
      _ => <String>[],
    };

    final command = pkg.tool;

    // If original paths were '.', 'test', or empty, don't pass test directories
    // Just run the test command without path arguments
    // However, always include optimized/bucketed test files when present.
    // A `--experimental-bucket` command must ALWAYS keep its explicit file
    // list regardless of shouldSkipPaths -- it dispatches specific
    // generated bucket files and/or specific solo (quarantined) files, not
    // "run the whole package", and a solo file's own name won't match
    // optimizedTestBasename the way a generated bucket file's does.
    final shouldSkipPaths = shouldSkipTestPaths(providedPaths);
    final hasOptimizedTestFile = tests.any(
      (test) => test.contains(optimizedTestBasename),
    );
    final isBucketCommand = bucketFileGroups != null;
    final testsToPass =
        (shouldSkipPaths && !hasOptimizedTestFile && !isBucketCommand)
        ? <String>[]
        : tests;

    final script = [
      '$command test',
      ...toolArgs,
      ...testsToPass,
    ].join(' ').trim();

    logger.detail('\nTest command: $script');

    // Determine the display path: use provided paths
    // if available (for directories),
    // otherwise use test paths, otherwise use package path
    final displayPath = _getDisplayPath(
      tests,
      pkg,
      providedPaths: providedPaths,
    );

    final label = [
      ?darkGray.wrap('Running ('),
      ?cyan.wrap(command),
      ?darkGray.wrap(') tests in '),
      ?yellow.wrap(displayPath),
    ].join();

    return ScriptToRun(
      script,
      workingDirectory: pkg.path,
      label: label,
      bail: bail,
      runInParallel: true,
      data: pkg,
      variables: {'GITHUB_ACTIONS': 'true'},
      bucketFileGroups: bucketFileGroups,
    );
  }

  bool shouldSkipTestPaths(List<String>? providedPaths) {
    if (providedPaths == null) return false;
    if (providedPaths.isEmpty) return true; // No paths provided

    // Check if all provided paths are '.' or 'test'
    return providedPaths.every((path) {
      final normalized = path.trim();
      return normalized == '.' || normalized == 'test';
    });
  }

  String _getDisplayPath(
    List<String> tests,
    Package pkg, {
    List<String>? providedPaths,
  }) {
    // If original provided paths are available, use those for display
    // (this handles the case where directories were provided and we want
    // to show the directory, not the subdirectories
    //  where test files were found)
    if (providedPaths != null && providedPaths.isNotEmpty) {
      final displayPaths = providedPaths.map((providedPath) {
        // Handle both absolute and relative paths
        final absolutePath = switch (providedPath) {
          '.' => fs.currentDirectory.path,
          _ =>
            fs.path.isAbsolute(providedPath)
                ? providedPath
                : fs.path.join(fs.currentDirectory.path, providedPath),
        };

        // Convert to relative path from current directory for display
        final relativePath = fs.path.relative(
          absolutePath,
          from: fs.currentDirectory.path,
        );

        // Normalize '.' to '.' (not './')
        return relativePath.isEmpty || relativePath == '.' ? '.' : relativePath;
      }).toList();

      // If all paths are the same, show just one
      final uniquePaths = displayPaths.toSet();
      if (uniquePaths.length == 1) {
        return uniquePaths.first;
      }

      // If multiple different paths, show the first path
      return displayPaths.first;
    }

    // If no paths were provided at all (sip test with no arguments),
    // show '.' (current directory) instead of resolved test paths
    if (providedPaths != null && providedPaths.isEmpty) {
      return '.';
    }

    // If tests are provided but no original paths, show the
    // relative path(s) of the tests
    if (tests.isNotEmpty) {
      // Get the relative paths from current directory for display
      final testPaths = tests.map((test) {
        // Handle both absolute and relative paths
        final absolutePath = fs.path.isAbsolute(test)
            ? test
            : fs.path.join(pkg.path, test);

        // If it's a file, use its directory; if it's a directory,
        // use it directly
        final pathToShow = fs.isFileSync(absolutePath)
            ? fs.path.dirname(absolutePath)
            : absolutePath;

        // Convert to relative path from current directory for display
        final relativePath = fs.path.relative(
          pathToShow,
          from: fs.currentDirectory.path,
        );

        // Normalize '.' to '.' (not './')
        return relativePath.isEmpty || relativePath == '.' ? '.' : relativePath;
      }).toList();

      // If all paths are the same, show just one
      final uniquePaths = testPaths.toSet();
      if (uniquePaths.length == 1) {
        return uniquePaths.first;
      }

      // If multiple different paths, show the first path
      // (showing all would be too verbose)
      return testPaths.first;
    }

    // Fallback to package relative path when no specific tests provided
    // Normalize empty or '.' to '.' for root directory
    final pkgRelativePath = pkg.relativePath;
    return pkgRelativePath.isEmpty || pkgRelativePath == '.'
        ? '.'
        : pkgRelativePath;
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

    logger.write(darkGray.wrap('loading...'));

    final data = TestData();
    final scriptResults = <Runnable, CommandResult>{};

    try {
      await scriptRunner.run(
        commandsToRun,
        bail: bail,
        logTime: false,
        printLabels: false,
        onScriptResult: (script, result) => scriptResults[script] = result,
        onMessage: _testOutputHandler(data, bail: bail),
      );
    } catch (e) {
      data.addError(null, e);
    }

    final superseded = await _runBucketFallbacks(
      commandsToRun,
      scriptResults: scriptResults,
      data: data,
      bail: bail,
    );

    data.printResults();

    if (data.failing > 0 || data.allFailures.isNotEmpty) {
      return ExitCode.software;
    }

    // Parsed output is not the whole story: a failure the parser does not
    // recognize (a crashed runner, an unreported failure, a reporter change)
    // leaves the counters at zero while the process still exits non-zero.
    // Trusting the counters alone reports a passing run for a failing suite,
    // so a non-zero exit fails the run even when nothing was parsed.
    //
    // A command whose results were discarded and re-run individually is
    // skipped: its exit code describes the run that was thrown away, and the
    // fallback's own result stands in for it.
    for (final MapEntry(key: command, value: result) in scriptResults.entries) {
      if (superseded.contains(command)) continue;
      if (result.exitCode != ExitCode.success.code) {
        return ExitCode.software;
      }
    }

    return ExitCode.success;
  }

  /// Builds a fresh `onMessage` handler that parses raw script output into
  /// [data] and, when [bail] is set, kills the run once a failure has fully
  /// reported. Each call gets its own bail-tracking state, so this is safe
  /// to call again for a follow-up run (e.g. a bucket fallback re-run)
  /// sharing the same [data].
  MessageAction? Function(Runnable, Message) _testOutputHandler(
    TestData data, {
    required bool bail,
  }) {
    var killEverything = false;
    var canKill = false;
    var snapshot = (passing: 0, failing: 0, skipped: 0);

    return (runnable, message) {
      if (message.message.contains('The Dart compiler exited unexpectedly')) {
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
      final ciPattern = RegExp('^[✅❌⚠️]');

      for (final line in lines) {
        // In CI format, each emoji-prefixed line is a separate test
        if (ciPattern.hasMatch(line)) {
          if (buf.isNotEmpty) {
            tests.add(buf.toString());
            buf.clear();
          }
          // Add the CI format line as its own test
          tests.add(line);
          continue;
        } else if (timePattern.hasMatch(line)) {
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
    };
  }

  /// `--experimental-bucket` fallback-on-failure: a bucket-mode command
  /// covers one or more groups of original files (one group per generated
  /// bucket file, plus a single-item group per solo file, all dispatched as
  /// separate `flutter test` arguments in ONE invocation -- see
  /// `Package.testGroups`/`bucketFileGroupsFor`). For any group where an
  /// original file never reported a single test result, that group's run is
  /// untrustworthy (a compile error or an unsafe binding can zero out an
  /// entire bucket's results, per `FlutterTestSafety`; a process-level crash
  /// can zero out several groups at once) -- so just that group's results
  /// are discarded and its original files re-run individually (today's
  /// normal, uncombined behavior), with that clearly logged. Every other
  /// (healthy) group sharing the same invocation is left untouched.
  ///
  /// A group that simply has a genuine failing (but fully-executing) test
  /// is not touched here: every original file in it still reports results
  /// in that case, so there's nothing to fall back from.
  ///
  /// Returns the commands whose results were discarded, so the caller knows
  /// not to judge them by the exit code of the run that was thrown away.
  Future<Set<Runnable>> _runBucketFallbacks(
    List<Runnable> commandsToRun, {
    required Map<Runnable, CommandResult> scriptResults,
    required TestData data,
    required bool bail,
  }) async {
    final superseded = <Runnable>{};

    for (final command in commandsToRun) {
      if (command is! ScriptToRun) continue;

      final groups = command.bucketFileGroups;
      if (groups == null || groups.isEmpty) continue;

      final pkg = command.data;
      if (pkg is! Package) continue;

      final outputs = data.outputsFor(command);
      final missingGroups = [
        for (final group in groups)
          if (group.any((file) => !_bucketFileWasReported(file, outputs)))
            group,
      ];

      if (missingGroups.isEmpty) continue;

      final filesToRerun = [for (final group in missingGroups) ...group];
      final exitCode = scriptResults[command]?.exitCode;

      logger.warn(
        '${command.label ?? command.exe} failed when combined '
        '(exit code: ${exitCode ?? 'unknown'}; '
        '${missingGroups.length}/${groups.length} combined group(s) never '
        'fully reported results) -- re-running ${filesToRerun.length} '
        'file(s) individually.',
      );

      data.discardOutputsForFiles(command, filesToRerun.toSet());
      if (missingGroups.length == groups.length) {
        data.clearErrorFor(command);
      }

      final fallbackCommand = createTestCommand(
        pkg: pkg,
        tests: filesToRerun,
        bail: bail,
      );

      superseded.add(command);

      try {
        await scriptRunner.run(
          [fallbackCommand],
          bail: bail,
          logTime: false,
          printLabels: false,
          onScriptResult: (script, result) => scriptResults[script] = result,
          onMessage: _testOutputHandler(data, bail: bail),
        );
      } catch (e) {
        data.addError(fallbackCommand, e);
      }
    }

    return superseded;
  }

  /// Whether any recorded [outputs] belong to the original file [file].
  /// Every dispatched unit (bucket or solo) is wrapped in its own top-level
  /// `group('<file>', ...)` (see `Package.bucketPlan`), and that literal
  /// group name ends up in a different `TestOutput` field depending on how
  /// many file arguments were passed to the one `flutter test`/`dart test`
  /// invocation -- confirmed empirically against real `dart test` CI-format
  /// output:
  ///  - a single-file invocation puts it in [TestOutput.path] (e.g.
  ///    `✅ test/a_test.dart a passes` -> `path: test/a_test.dart`).
  ///  - a multi-file invocation (the normal `--experimental-bucket` shape,
  ///    since a shard's buckets/solo files are all passed as arguments to
  ///    ONE invocation) prefixes with the *physical* wrapper file instead
  ///    and pushes the group name into [TestOutput.test] (e.g.
  ///    `✅ test/.test_optimizer_bucket_0.dart: test/a_test.dart a passes`
  ///    -> `path: test/.test_optimizer_bucket_0.dart, test: test/a_test.dart
  ///    a passes`).
  /// So both fields are checked.
  bool _bucketFileWasReported(String file, List<TestOutput> outputs) {
    final normalized = file.replaceAll(r'\', '/');

    return outputs.any(
      (output) =>
          output.path == normalized ||
          output.test == normalized ||
          output.test.startsWith('$normalized '),
    );
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
      // Resolve relative paths to absolute paths
      final fileOrDir = switch (path) {
        '.' => fs.currentDirectory.path,
        _ =>
          fs.path.isAbsolute(path)
              ? path
              : fs.path.join(fs.currentDirectory.path, path),
      };

      if (fs.isFileSync(fileOrDir)) {
        if (fs.path.basename(fileOrDir).endsWith('_test.dart')) {
          testsToRun.add(fileOrDir);
        }
      } else if (fs.isDirectorySync(fileOrDir)) {
        // Use glob to find test files in subdirectories
        final results = glob.listFileSystemSync(
          fs,
          followLinks: false,
          root: fileOrDir,
        );
        final files = results.whereType<File>().toList();

        // Also check for test files directly in the provided directory
        // (the glob pattern **/*_test.dart matches files in subdirectories,
        // but not files directly in the root)
        final dir = fs.directory(fileOrDir);
        final directFiles = dir.listSync()
          ..retainWhere(
            (entity) =>
                entity is File && entity.basename.endsWith('_test.dart'),
          );
        files.addAll(directFiles.whereType<File>());

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
