part of './test_command.dart';

extension _BothX on TestCommand {
  void _addBothArgs() {
    argParser
      ..addOption(
        'concurrency',
        abbr: 'j',
        help: 'The number of concurrent test processes to run. '
            'This will be ignored when running integration tests.',
        valueHelp: 'jobs',
      )
      ..addOption(
        'coverage',
        help: 'Gather coverage and output it to the specified directory.\n'
            'Implies --debug.',
      )
      ..addOption(
        'exclude-tags',
        abbr: 'x',
        help:
            'Run only tests that do not have the specified tags. See: https://pub.dev/packages/test#tagging-tests',
      )
      ..addOption(
        'file-reporter',
        help: 'Enable an additional reporter writing test results to a file.\n'
            'Should be in the form <reporter>:<filepath>, '
            'Example: "json:reports/tests.json".',
      )
      ..addMultiOption(
        'name',
        abbr: 'n',
        help: 'A substring of the name of the test to run.\n'
            'Regular expression syntax is supported.\n'
            'If passed multiple times, tests must match all substrings.',
        splitCommas: false,
      )
      ..addMultiOption(
        'plain-name',
        abbr: 'N',
        help: 'A plain-text substring of the name of the test to run.\n'
            'If passed multiple times, tests must match all substrings.',
        splitCommas: false,
      )
      ..addOption(
        'tags',
        abbr: 't',
        help:
            'Run only tests associated with the specified tags. See: https://pub.dev/packages/test#tagging-tests',
      )
      ..addOption(
        'reporter',
        help: 'Set how to print test results. If unset, '
            'value will default to either compact or expanded.',
        allowed: <String>['compact', 'expanded', 'github', 'json'],
        allowedHelp: <String, String>{
          'compact':
              'A single line that updates dynamically (The default reporter).',
          'expanded': 'A separate line for each update. May be preferred '
              'when logging to a file or in continuous integration.',
          'github': 'A custom reporter for GitHub Actions (the default '
              'reporter when running on GitHub Actions).',
          'json':
              'A machine-readable format. See: https://dart.dev/go/test-docs/json_reporter.md',
        },
      )
      ..addFlag(
        'run-skipped',
        help: 'Run skipped tests instead of skipping them.',
      )
      ..addOption(
        'shard-index',
        help: 'Tests can be sharded with the '
            '"--total-shards" and "--shard-index" '
            'arguments, allowing you to split up your test suites and run '
            'them separately.',
      )
      ..addOption(
        'total-shards',
        help: 'Tests can be sharded with the '
            '"--total-shards" and "--shard-index" '
            'arguments, allowing you to split up your test suites and run '
            'them separately.',
      )
      ..addOption(
        'test-randomize-ordering-seed',
        help: 'The seed to randomize the execution order '
            'of test cases within test files. '
            'Must be a 32bit unsigned integer or the string "random", '
            'which indicates that a seed should be selected randomly. '
            'By default, tests run in the order they are declared.',
      )
      ..addOption(
        'timeout',
        help: 'The default test timeout, specified either '
            'in seconds (e.g. "60s"), '
            'as a multiplier of the default timeout (e.g. "2x"), '
            'or as the string "none" to disable the timeout entirely.',
      );
  }

  List<String> _getBothArgs() {
    const options = {
      'concurrency',
      'coverage',
      'exclude-tags',
      'file-reporter',
      'name',
      'plain-name',
      'reporter',
      'run-skipped',
      'shard-index',
      'tags',
      'test-randomize-ordering-seed',
      'timeout',
      'total-shards',
    };

    return _parse(options);
  }

  List<String> _parse(Set<String> options_) {
    final options = {...options_};

    final argResults = this.argResults;

    if (argResults == null) return [];
    final args = <String>[];

    final bail = argResults['bail'] as bool;
    final canFailFast = options.contains('fail-fast');
    if (canFailFast) {
      options.remove('fail-fast');
    }

    if (bail && canFailFast) {
      args.add('--fail-fast');
    }

    final arguments = [
      ...argResults.arguments,
    ];

    for (final option in options) {
      if (!argResults.wasParsed(option)) {
        continue;
      }

      final definedOption = argParser.findByNameOrAlias(option);
      if (definedOption == null) {
        throw Exception('Unknown option: $option');
      }

      final tempParser = AnyArgParser()..inject(definedOption);

      final result = tempParser.parse(arguments);
      final value = result[option];

      if (value == null) {
        continue;
      }

      if (value is List<String>) {
        args.addAll(['--$option', ...value]);
      } else if (value is bool) {
        if (value) {
          args.add('--$option');
        } else {
          args.add('--no-$option');
        }
      } else {
        args.addAll(['--$option', '$value']);
      }
    }

    args.removeWhere((e) => e.isEmpty);

    return args;
  }
}
