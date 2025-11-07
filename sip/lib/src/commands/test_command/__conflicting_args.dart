part of 'tester_mixin.dart';

extension _ConflictingX<T> on Command<T> {
  static const dartOptions = {'dart-coverage'};

  static const flutterOptions = {'flutter-coverage'};

  void _addConflictingArgs() {
    argParser
      ..addFlag(
        'coverage',
        negatable: false,
        help:
            'Dart: Gather coverage and output it to the `coverage` directory\n'
            'Flutter: Gathers coverage',
      )
      ..addOption(
        'dart-coverage',
        help:
            '${red.wrap('RENAMED')} from ${magenta.wrap('coverage')}\n'
            'Gather coverage and output it to the specified directory.\n'
            'Implies --debug.',
        valueHelp: 'directory',
      )
      ..addFlag(
        'flutter-coverage',
        negatable: false,
        help:
            '${red.wrap('RENAMED')} from ${magenta.wrap('coverage')}\n'
            'Whether to merge coverage data with "coverage/lcov.base.info".\n'
            'Implies collecting coverage data. (Requires lcov.)',
      );
  }

  List<String> _getDartConflictingArgs() {
    final args = <String>{};

    final options = {...dartOptions};
    final coverage = argResults?['coverage'] as bool? ?? false;
    final dartCoverage = argResults?.wasParsed('dart-coverage') ?? false;

    if (coverage && !dartCoverage) {
      args.add('--coverage=coverage');
      options.remove('dart-coverage');
    }

    return _parseArguments(
      argParser,
      argResults,
      options,
      flagReplacements: {'dart-coverage': 'coverage'},
      initialArgs: args,
    );
  }

  List<String> _getFlutterConflictingArgs() {
    final args = <String>{};

    final options = {...flutterOptions};

    final coverage = argResults?['coverage'] as bool? ?? false;
    final flutterCoverage = argResults?['flutter-coverage'] as bool? ?? false;

    if (coverage && !flutterCoverage) {
      args.add('--coverage');
      options.remove('flutter-coverage');
    }

    return _parseArguments(
      argParser,
      argResults,
      options,
      flagReplacements: {'flutter-coverage': 'coverage'},
      initialArgs: args,
    );
  }
}
