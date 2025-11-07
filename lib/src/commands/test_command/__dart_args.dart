part of 'tester_mixin.dart';

const _dartOptions = {
  'platform',
  'compiler',
  'preset',
  'ignore-timeouts',
  'pause-after-load',
  'debug',
  'chain-stack-traces',
  'no-retry',
  'use-data-isolate-strategy',
  'verbose-trace',
  'js-trace',
  'color',
};

void addDartArgs(ArgParser argParser) {
  argParser
    // The UI term "platform" corresponds with
    // the implementation term "runtime".
    // The [Runtime] class used to be called
    // [TestPlatform], but it was changed to
    // avoid conflicting with [SuitePlatform].
    // We decided not to also change the
    // UI to avoid a painful migration.
    ..addMultiOption(
      'platform',
      abbr: 'p',
      help: 'The platform(s) on which to run the tests.\n',
    )
    ..addMultiOption(
      'compiler',
      help:
          'The compiler(s) to use to run tests '
          'Each platform has a default compiler but may support other '
          'compilers.\n'
          'You can target a compiler to a specific platform using arguments '
          'of the following form [<platform-selector>:]<compiler>.\n'
          'If a platform is specified but no given compiler is supported for '
          'that platform, then it will use its default compiler.',
    )
    ..addMultiOption(
      'preset',
      abbr: 'P',
      help: 'The configuration preset(s) to use.',
    )
    ..addFlag(
      'ignore-timeouts',
      help: 'Ignore all timeouts (useful if debugging)',
      negatable: false,
    )
    ..addFlag(
      'pause-after-load',
      help:
          'Pause for debugging before any tests execute.\n'
          'Implies --concurrency=1, --debug, and --ignore-timeouts.\n'
          'Currently only supported for browser tests.',
      negatable: false,
    )
    ..addFlag(
      'debug',
      help: 'Run the VM and Chrome tests in debug mode.',
      negatable: false,
    )
    ..addFlag(
      'chain-stack-traces',
      help:
          'Use chained stack traces to provide greater exception details\n'
          'especially for asynchronous code. It may be useful to disable\n'
          'to provide improved test performance but at the cost of\n'
          'debuggability.',
    )
    // --bail will enable this flag
    // ..addFlag(
    //   'fail-fast',
    //   help: 'Stop running tests after the first failure.\n',
    // )
    ..addFlag(
      'no-retry',
      help: "Don't rerun tests that have retry set.",
      negatable: false,
    )
    ..addFlag(
      'use-data-isolate-strategy',
      help: '**DEPRECATED**: This is now just an alias for --compiler source.',
      hide: true,
      negatable: false,
    )
    ..addFlag(
      'verbose-trace',
      negatable: false,
      help: 'Emit stack traces with core library frames.',
    )
    ..addFlag(
      'js-trace',
      negatable: false,
      help: 'Emit raw JavaScript stack traces for browser tests.',
    )
    ..addFlag(
      'color',
      help: 'Use terminal colors.\n(auto-detected by default)',
    );
}

List<String> getDartArgs(ArgParser argParser, ArgResults argResults) {
  final args = <String>{};

  final options = {..._dartOptions};

  if (argParser.options.containsKey('bail')) {
    if (argResults['bail'] as bool? ?? false) {
      args.add('--fail-fast');
    }
    options.remove('fail-fast');
  }

  final original = _parseArguments(
    argParser,
    argResults,
    options,
    flagReplacements: {'dart-coverage': 'coverage'},
    initialArgs: args,
  );

  final conflicted = getDartConflictingArgs(argParser, argResults);

  return [...original, ...conflicted];
}
