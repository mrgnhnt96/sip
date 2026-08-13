# sip — agent & contributor guide

`sip_cli` is a single Dart package (no mono-repo, no codegen). It publishes one
executable, `sip`.

## Quick loops

| Goal | Command |
| --- | --- |
| Run the test suite | `dart test` |
| One file | `dart test test/src/domain/args_test.dart` |
| Analyze | `dart analyze . --fatal-infos --fatal-warnings` |
| Format | `dart format .` |
| Try a change end-to-end | `dart compile exe bin/sip.dart -o /tmp/sip_dev` then run `/tmp/sip_dev` |

> **Verify with `dart test`, not `sip test`.** `sip test` decides pass/fail by
> parsing test output rather than reading the test process's exit code, so a
> failure it fails to parse is reported as a pass — a package with one passing
> and one failing test prints `Results: ✅ 1 ❌ 0` and exits 0 while `dart test`
> exits 1. This is a known bug in this repo, not a quirk to work around.

To exercise the CLI without touching a globally activated `sip`, compile to a
scratch path and run that binary. `sip run install` (alias `sip run i`)
overwrites your global install with the working tree, which is convenient but
not reversible in one step.

## CI

`.github/workflows/ci.yml` runs on ubuntu and windows. It does **not** run
`dart test` — it activates sip from source and runs a single shell smoke test
in `test/integration/smoke`. A red unit suite will not fail CI, so run
`dart test` locally before pushing.

`hooks/pre_commit.dart` (hooksman) formats and analyzes staged Dart files with
`--fatal-infos --fatal-warnings` on commit.

## Project layout

```
bin/sip.dart              entrypoint
lib/sip_runner.dart       top-level arg dispatch (the command table lives here)
lib/src/commands/         one directory or file per command
lib/src/deps/             scoped_deps providers — the injection seam
lib/src/domain/           models: Script, ScriptsConfig, Args, TestData, ...
lib/src/utils/            constants, mixins, helpers
test/src/                 unit tests
test/e2e/                 per-feature dirs with an `inputs/scripts.yaml`
test/integration/smoke/   the only thing CI actually runs
```

## Conventions

**Commands** are `const` classes with a `Future<ExitCode> run([List<String>])`
method. They read a `_usage` string, check `--help` first, call
`analytics.track(...)`, and return an `ExitCode`. They take no constructor
arguments — collaborators come from `lib/src/deps/`.

```dart
const _usage = '''
Usage: sip thing [options]
...
''';

class ThingCommand {
  const ThingCommand();

  Future<ExitCode> run() async {
    if (args.get<bool>('help', defaultValue: false)) {
      logger.write(_usage);
      return ExitCode.success;
    }
    ...
  }
}
```

Register the command in the `switch (args.path)` in `lib/sip_runner.dart` and
add a line to its `_usage`.

**Dependencies** are `scoped_deps` providers (`fs`, `logger`, `args`,
`analytics`, `process`, `scriptRunner`, …). Read them as top-level getters;
never construct a `FileSystem` or `Logger` directly, or tests can't substitute
them. Tests use `testScoped` from `test/utils/test_scoped.dart`, which
overrides every provider and takes a `MemoryFileSystem`.

**Boolean flags must be registered.** `lib/src/domain/boolean_flags.dart` lists
every flag sip reads as a `bool`. Anything not listed greedily consumes the
next argument — that is deliberate, since it lets sip forward unknown options
to `dart`/`flutter`, but it means an unregistered boolean flag silently eats a
positional argument. Add new ones to `booleanFlagNames`; add an abbreviation to
`booleanFlagAbbrs` only if it is unambiguous across every command.

**Argument order.** `Args.parse` stops filling `path` at the first flag;
positionals after a flag land in `rest`. A command that takes a subcommand name
should therefore fall back to `args.rest` if its path is empty.

## scripts.yaml semantics worth knowing before touching them

- References inside `${{ }}` split on **dots**. A colon (`${{ a:b }}`) is not
  substituted and reaches the shell verbatim. `lib/src/domain/variables.dart`
  has the two regexes: the current `${{ }}` form permits dots only; colons
  belong to the legacy `{a:b}` form, which requires no surrounding spaces.
- The built-in variable is `projectRoot` (`Vars.projectRoot`). There is no
  `packageRoot`.
- `(bail):` with no value parses as `null`, which `Script.fromJson` reads as
  `false`. Only `(bail): true` (or `'true'`/`'yes'`/`'y'`) enables it.
- Reserved keys are exactly `Keys.scriptParameters` (`(command)`, `(aliases)`,
  `(description)`, `(bail)`, `(env)`) plus `Keys.nonScriptKeys` (`(variables)`,
  `(executables)`). Every other key is a nested script.

## Known bugs

Confirmed against the working tree; each is reproducible.

1. **`sip test` reports success for a failing suite.** `TesterMixin.runCommands`
   returns `ExitCode.success` based on `data.failing`/`data.allFailures` alone
   (`lib/src/commands/test_command/tester_mixin.dart`). The child process's
   exit code is captured in `scriptResults` but only ever consulted by
   `_runBucketFallbacks`. Independent of `--optimize`.
2. **Bail does not stop later commands.** Both `--bail` and `(bail): true` still
   run subsequent entries of a `(command)` list.
3. **This repo's own `scripts.yaml` is broken.** `build_runner` uses
   `${{ build_runner:_ }}`, which does not resolve; `sip run build_runner build`
   exits 64 with `bad substitution`. Change the colons to dots.

## Releasing

`sip run publish` is the release path. It chains `sip test`, `sip run prep`,
`dart pub publish`, then a commit, a tag and a push. Note that its first step is
`sip test`, which has the reporting bug above — a red suite will not stop the
release.

`sip run prep` keeps three things in sync from `CHANGELOG.md`: `pubspec.yaml`'s
`version`, `packageVersion` in `lib/src/version.dart`, and `example/README.md`
(copied from `README.md` with asset paths rewritten). The top `# ` heading in
`CHANGELOG.md` is the source of truth for the version.

## AI reference files

`sip ai <claude|cursor|copilot|windsurf|cline|all>` installs a sip reference
document into a *consumer's* project. The content lives in
`lib/src/commands/ai/ai_templates.dart`; the file paths per tool are in
`lib/src/commands/ai/ai_tool.dart`. When `scripts.yaml` semantics change, update
those templates — they are the documentation users' assistants read.

`llms.txt` at the repo root is the same surface in llms.txt form.
