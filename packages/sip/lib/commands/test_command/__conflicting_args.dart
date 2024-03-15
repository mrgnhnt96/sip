part of './tester_mixin.dart';

extension _ConflictingX<T> on Command<T> {
  static const dartOptions = {
    'dart-coverage',
  };

  static const flutterOptions = {
    'flutter-coverage',
  };

  void _addConflictingArgs() {
    argParser
      ..addOption(
        'dart-coverage',
        help: '${red.wrap('RENAMED')} from ${magenta.wrap('coverage')}\n'
            'Gather coverage and output it to the specified directory.\n'
            'Implies --debug.',
        valueHelp: 'directory',
      )
      ..addFlag(
        'flutter-coverage',
        negatable: false,
        help: '${red.wrap('RENAMED')} from ${magenta.wrap('coverage')}\n'
            'Whether to merge coverage data with "coverage/lcov.base.info".\n'
            'Implies collecting coverage data. (Requires lcov.)',
      );
  }

  List<String> _getDartConflictingArgs() {
    return _parseArguments(
      argParser,
      argResults,
      dartOptions,
      flagReplacements: {
        'dart-coverage': 'coverage',
      },
    );
  }

  List<String> _getFlutterConflictingArgs() {
    return _parseArguments(
      argParser,
      argResults,
      flutterOptions,
      flagReplacements: {
        'flutter-coverage': 'coverage',
      },
    );
  }
}
