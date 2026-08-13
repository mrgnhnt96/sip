/// Every flag that sip reads as a `bool`, including aliases.
///
/// `Args.parse` reads `--key value` as an option and its value, which is
/// wrong for a flag that never takes one: `sip test --omit-errors a_test.dart`
/// would set `omit-errors` to `a_test.dart` and drop the file from the tests
/// to run. Flags listed here are always parsed as `true` and leave the
/// following argument alone.
///
/// Anything not listed still greedily consumes the next argument, which is
/// what lets sip forward options it doesn't know about to `dart`/`flutter`.
/// So a boolean flag missing from this set silently eats a positional
/// argument -- add new ones here.
const booleanFlagNames = <String>{
  // sip itself
  'color',
  'disable-analytics',
  'help',
  'loud',
  'quiet',
  'version',
  'version-check',

  // sip list
  'resolve',

  // sip validate
  'fatal-warnings',

  // sip ai
  'force',

  // sip run
  'bail',
  'h',
  'list',
  'ls',
  'never-exit',
  'parallel',
  'print',

  // sip test
  'clean',
  'concurrent',
  'dart-only',
  'experimental-bucket',
  'flutter-only',
  'omit-errors',
  'optimize',
  'recursive',

  // sip clean
  'pubspec-lock',

  // sip pub
  'dev',
  'dev_dependencies',
  'dry-run',
  'enforce-lockfile',
  'executables',
  'json',
  'major',
  'major-versions',
  'majors',
  'offline',
  'pin',
  'precompile',
  'separated',
  'tighten',
  'unlock-transitive',

  // forwarded to `dart test` / `flutter test`
  'branch-coverage',
  'chain-stack-traces',
  'debug',
  'experimental-faster-testing',
  'fail-fast',
  'ignore-timeouts',
  'js-trace',
  'merge-coverage',
  'no-retry',
  'pause-after-load',
  'run-skipped',
  'start-paused',
  'test-assets',
  'update-goldens',
  'use-data-isolate-strategy',
  'verbose-trace',
};

/// Abbreviations of [booleanFlagNames].
///
/// Only unambiguous abbreviations belong here. `-n` is left out because it
/// means `--dry-run` for `sip pub` but `--name` (which takes a value) for
/// `sip test`.
const booleanFlagAbbrs = <String>{
  'b', // --bail
  'd', // --dev_dependencies
  'l', // --list, --pubspec-lock
  'r', // --recursive
};
