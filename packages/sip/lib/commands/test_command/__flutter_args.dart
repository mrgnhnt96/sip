part of './tester_mixin.dart';

extension _FlutterX<T> on Command<T> {
  static const options = {
    'experimental-faster-testing',
    'start-paused',
    'merge-coverage',
    'branch-coverage',
    'coverage-path',
    'coverage-package',
    'update-goldens',
    'test-assets',
  };

  void _addFlutterArgs() {
    argParser
      ..addFlag(
        'experimental-faster-testing',
        negatable: false,
        hide: true,
        help: 'Run each test in a separate lightweight '
            'Flutter Engine to speed up testing.',
      )
      ..addFlag(
        'start-paused',
        negatable: false,
        help: 'Start in a paused mode and wait for a debugger to connect.\n'
            'You must specify a single test file to run, explicitly.\n'
            'Instructions for connecting with a debugger are printed to the '
            'console once the test has started.',
      )
      ..addFlag(
        'merge-coverage',
        negatable: false,
        help: 'Whether to merge coverage data with "coverage/lcov.base.info".\n'
            'Implies collecting coverage data. (Requires lcov.)',
      )
      ..addFlag(
        'branch-coverage',
        negatable: false,
        help: 'Whether to collect branch coverage information. '
            'Implies collecting coverage data.',
      )
      ..addOption(
        'coverage-path',
        defaultsTo: 'coverage/lcov.info',
        help: 'Where to store coverage information (if coverage is enabled).',
      )
      ..addMultiOption(
        'coverage-package',
        help: 'A regular expression matching packages names '
            'to include in the coverage report (if coverage is enabled). '
            'If unset, matches the current package name.',
        valueHelp: 'package-name-regexp',
        splitCommas: false,
      )
      ..addFlag(
        'update-goldens',
        negatable: false,
        help: 'Whether "matchesGoldenFile()" calls within your '
            'test methods should '
            'update the golden files rather than test for an existing match.',
      )
      ..addFlag(
        'test-assets',
        defaultsTo: true,
        help: 'Whether to build the assets bundle for testing. '
            'This takes additional time before running the tests. '
            'Consider using "--no-test-assets" if assets are not required.',
      );
  }

  List<String> _getFlutterArgs() {
    final original = _parseArguments(
      argParser,
      argResults,
      options,
      flagReplacements: {
        'flutter-coverage': 'coverage',
      },
    );

    final conflicted = _getFlutterConflictingArgs();

    return [...original, ...conflicted, '--no-pub'];
  }
}
