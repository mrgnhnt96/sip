part of 'tester_mixin.dart';

class FlutterAndDartArgs {
  const FlutterAndDartArgs();

  int? get concurrent => args.getOrNull<int>('concurrency');
  String? get excludeTags => args.getOrNull<String>('exclude-tags');
  String? get fileReporter => args.getOrNull<String>('file-reporter');
  List<String> get name => args.getOrNull<List<String>>('name') ?? [];
  List<String> get plainName =>
      args.getOrNull<List<String>>('plain-name') ?? [];
  String? get reporter => args.getOrNull<String>('reporter');
  bool get runSkipped => args.get<bool>('run-skipped', defaultValue: false);
  int? get shardIndex => args.getOrNull<int>('shard-index');
  int? get totalShards => args.getOrNull<int>('total-shards');
}

const options = {
  'concurrency',
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

void addBothArgs(ArgParser argParser) {
  argParser
    ..addOption(
      'concurrency',
      abbr: 'j',
      help:
          'The number of concurrent test processes to run. '
          'This will be ignored when running integration tests.',
      valueHelp: 'jobs',
    )
    ..addOption(
      'exclude-tags',
      abbr: 'x',
      help:
          'Run only tests that do not have the specified tags. See: https://pub.dev/packages/test#tagging-tests',
    )
    ..addOption(
      'file-reporter',
      help:
          'Enable an additional reporter writing test results to a file.\n'
          'Should be in the form <reporter>:<filepath>, '
          'Example: "json:reports/tests.json".',
    )
    ..addMultiOption(
      'name',
      abbr: 'n',
      help:
          'A substring of the name of the test to run.\n'
          'Regular expression syntax is supported.\n'
          'If passed multiple times, tests must match all substrings.',
      splitCommas: false,
    )
    ..addMultiOption(
      'plain-name',
      abbr: 'N',
      help:
          'A plain-text substring of the name of the test to run.\n'
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
      help:
          'Set how to print test results. If unset, '
          'value will default to either compact or expanded.',
      allowed: <String>['compact', 'expanded', 'github', 'json'],
      allowedHelp: <String, String>{
        'compact':
            'A single line that updates dynamically (The default reporter).',
        'expanded':
            'A separate line for each update. May be preferred '
            'when logging to a file or in continuous integration.',
        'github':
            'A custom reporter for GitHub Actions (the default '
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
      help:
          'Tests can be sharded with the '
          '"--total-shards" and "--shard-index" '
          'arguments, allowing you to split up your test suites and run '
          'them separately.',
    )
    ..addOption(
      'total-shards',
      help:
          'Tests can be sharded with the '
          '"--total-shards" and "--shard-index" '
          'arguments, allowing you to split up your test suites and run '
          'them separately.',
    )
    ..addOption(
      'test-randomize-ordering-seed',
      help:
          'The seed to randomize the execution order '
          'of test cases within test files. '
          'Must be a 32bit unsigned integer or the string "random", '
          'which indicates that a seed should be selected randomly. '
          'By default, tests run in the order they are declared.',
    )
    ..addOption(
      'timeout',
      help:
          'The default test timeout, specified either '
          'in seconds (e.g. "60s"), '
          'as a multiplier of the default timeout (e.g. "2x"), '
          'or as the string "none" to disable the timeout entirely.',
    );
}

List<String> getBothArgs(ArgParser argParser, ArgResults argResults) {
  return _parseArguments(argParser, argResults, options);
}

List<String> _parseArguments(
  ArgParser argParser,
  ArgResults? argResults,
  Set<String> options, {
  Map<String, String> flagReplacements = const {},
  Set<String> initialArgs = const {},
}) => parseArguments(
  argParser,
  argResults,
  options,
  flagReplacements: flagReplacements,
  initialArgs: initialArgs,
);

/// [flagReplacements]\
/// Flags that are identified by an alternative name, but should
/// be replaced with the original name.
///
/// eg. dart-coverage -> coverage
List<String> parseArguments(
  ArgParser argParser,
  ArgResults? argResults,
  Set<String> options, {
  required Map<String, String> flagReplacements,
  required Set<String> initialArgs,
}) {
  if (argResults == null) return [];
  final args = <String>[...initialArgs];

  final arguments = [...argResults.arguments];

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

    // We to check if the option has a replacement
    dynamic option_ = option;

    if (flagReplacements.containsKey(option)) {
      option_ = flagReplacements[option];
    }

    if (value is List<String>) {
      args.addAll(['--$option_', ...value]);
    } else if (value is bool) {
      if (value) {
        args.add('--$option_');
      } else {
        args.add('--no-$option_');
      }
    } else {
      args.addAll(['--$option_', '$value']);
    }
  }

  args.removeWhere((e) => e.isEmpty);

  return args;
}
