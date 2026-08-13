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

> **`dart test` is still the reference.** `sip test` used to report a passing
> run for a failing suite; it now counts failures correctly and also fails on a
> non-zero exit code from the test process, so a failure the parser misses can
> no longer pass silently. It remains a layer of parsing over `dart test`, so
> when a result looks surprising, confirm with `dart test` directly.

To exercise the CLI without touching a globally activated `sip`, compile to a
scratch path and run that binary. `sip run install` (alias `sip run i`)
overwrites your global install with the working tree, which is convenient but
not reversible in one step.

## CI

`.github/workflows/ci.yml` runs on ubuntu and windows: `dart analyze
--fatal-infos --fatal-warnings`, `dart test`, then a shell smoke test in
`test/integration/smoke` against sip activated from source. Every step tees to
`ci_logs/`, which is uploaded as an artifact.

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
should therefore fall back to `args.rest` when its path is empty — `sip run`
and `sip ai` do. `sip pub` deliberately does not: it reads `args.rest` as
package names (`pub_upgrade_command.dart`, `pub_constrain_command.dart`), so
the same fallback would read the subcommand as a package to upgrade.

**Exit codes.** Commands return mason_logger's `ExitCode`, whose constructor is
private, so sip cannot return a child's arbitrary code (127 and friends).
`ScriptRunner.run` preserves the first failing command's code in its aggregate
result, and `CommandResult.exitCodeReason` maps it — falling back to `software`
(70), never `usage` (64), which would claim the CLI was invoked wrongly. Codes
that have an `ExitCode` (65, 70, 77, 78, …) round-trip exactly. Full
passthrough would mean changing the `ExitCode` return contract everywhere.

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

## Recently fixed — worth understanding before working nearby

Each of these was reproducible and is covered by a regression test. The
mechanisms are easy to reintroduce.

1. **Test failures were swallowed by the output parser.** sip forces the
   `github` reporter by exporting `GITHUB_ACTIONS=true`
   (`TesterMixin.createTestCommand`). That reporter closes the previous group
   on the line before opening the next, so a failure arrives as a chunk
   starting with `::endgroup::`. `TestData.parseCi` strips the group markers in
   place, which left a leading newline, so its `^[✅❌]` check missed the result
   and recorded the whole failure as *error text on the previous passing test*.
   A failing suite summarized as `✅ 1 ❌ 0`. Fixed by trimming after stripping.
   Any change to that marker handling needs `test/src/domain/test_data_test.dart`
   to still fail without the trim — note it must reuse one `ScriptToRun`
   instance, since the per-script state is keyed by identity.

2. **A non-zero exit code did not fail the run.** `TesterMixin.runCommands`
   judged pass/fail purely from parsed output; the process exit code was
   captured in `scriptResults` but read only by `_runBucketFallbacks`. It is
   now also a failure signal, except for commands superseded by a bucket
   fallback (their exit code describes the discarded run).

3. **Bail never stopped anything.** `ScriptRunner._group` launches every task
   before yielding `controller.stream`, so the consumer's `break` on failure
   always came too late — `--bail` and `(bail): true` ran the whole list while
   printing "Bail is set, stopping on first error". Bail is now enforced inside
   the launch loop. Already-running `(+)` commands still finish; they cannot be
   unstarted.

## Releasing

`sip run publish` is the release path. It chains `sip test --bail --recursive`,
`sip run prep`, `dart pub publish`, then a commit, a tag and a push. It sets
`(bail): true`, so a failing step now stops the release — before the fixes above
it did not, and a red suite would publish.

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
