/// Template strings for AI coding assistant reference files.
///
/// [sipReference] is the shared master document. Every tool that reads a
/// single plain-markdown file uses it verbatim; Cursor gets it split into
/// glob-scoped `.mdc` rules instead.
library;

// ---------------------------------------------------------------------------
// Shared master reference document
// ---------------------------------------------------------------------------

const sipReference = r'''
## Commands

| Command | Purpose |
| --- | --- |
| `sip run <script>` (`sip r`) | Run a script from `scripts.yaml` |
| `sip list [query]` (`sip ls`) | List or search scripts |
| `sip validate` | Check `scripts.yaml` without running anything |
| `sip test [files or dirs]` | Run Dart/Flutter tests |
| `sip pub <get\|upgrade\|downgrade\|deps\|constrain>` | Pub operations across packages |
| `sip clean` | Remove `.dart_tool`/`build`, run `flutter clean` |
| `sip mcp` | Run sip as an MCP server over stdio |
| `sip update` | Update sip itself |
| `sip version` | Print the installed version |

`sip run` always executes from the directory containing `scripts.yaml`,
whatever the current working directory is.

## scripts.yaml

`scripts.yaml` lives at the repo root. Every top-level key is a script,
except the reserved parenthesized keys.

```yaml
format: dart format .

analyze: dart analyze .

build_runner:
  (aliases): [b, br]
  (description): Code generation
  build: dart run build_runner build --delete-conflicting-outputs
  watch: dart run build_runner watch --delete-conflicting-outputs
```

```bash
sip run format
sip run build_runner build
sip run b build          # via alias
```

### Reserved keys

These are configuration, not scripts. They are the only keys wrapped in
parentheses that sip understands.

| Key | Scope | Meaning |
| --- | --- | --- |
| `(command)` | script | The command(s) this script runs. A string or a list of strings. |
| `(aliases)` | script | Alternate names. A string or a list of strings. |
| `(description)` | script | Shown by `sip list`. |
| `(bail)` | script | Stop on first error. **Must be `true`** — see gotchas. |
| `(env)` | script | Environment variables to load before running. |
| `(variables)` | top level only | User-defined string variables. |
| `(executables)` | top level only | Override the `dart` / `flutter` executables. |

A script is either a plain command or a map. When it is a map, `(command)` is
what the script itself runs, and any non-reserved key is a nested subscript:

```yaml
format:
  (command): dart format .      # `sip run format`
  ui: cd packages/ui && dart format .   # `sip run format ui`
```

### Script key rules

Allowed pattern: `^_?([a-z][a-z0-9_.\-]*)?(?<=[a-z0-9_])$` (case-insensitive).
A key must start with a letter or `_`, must end with a letter, digit or `_`,
and must not contain spaces. Invalid keys are reported and skipped.

Keys starting with `_` are **private**: they cannot be run from the command
line and are hidden from `sip list`, but they can be referenced.

```yaml
format:
  _base: dart format .
  ui: cd packages/ui && ${{ format._base }}
```

### Referencing other scripts

`${{ script.path }}` inlines another script's command. Nesting is expressed
with **dots**:

```yaml
pub:
  (command): dart pub
  get: ${{ pub }} get
  ui: cd packages/ui && ${{ pub.get }}
```

Only dots work inside `${{ }}`. A colon (`${{ pub:get }}`) is **not**
substituted — see gotchas.

Circular references are detected and reported as an error.

### Built-in variables

| Variable | Value |
| --- | --- |
| `${{ projectRoot }}` | Directory of the nearest `pubspec.yaml` |
| `${{ scriptsRoot }}` | Directory of the nearest `scripts.yaml` |
| `${{ cwd }}` | Current working directory |
| `${{ dart }}` | The `dart` executable (respects `(executables)`) |
| `${{ flutter }}` | The `flutter` executable (respects `(executables)`) |
| `${{ dartOrFlutter }}` | `dart` or `flutter`, based on the nearest `pubspec.yaml` |

The variable is `projectRoot`. There is no `packageRoot`.

### Custom variables

```yaml
(variables):
  coverage_dir: coverage

test: dart test --coverage=${{ coverage_dir }}
```

Values must be strings; anything else is warned about and skipped. Reusing a
built-in name is warned about and ignored.

### Overriding executables

```yaml
(executables):
  dart: fvm dart
  flutter: fvm flutter
```

### Forwarding flags

Scripts receive only the flags they explicitly name, via `${{ --flag }}`:

```yaml
test: dart test ${{ --coverage }}
```

| Invocation | Expands to |
| --- | --- |
| `sip run test` | `` (empty — unspecified flags are dropped) |
| `sip run test --coverage` | `--coverage` |
| `sip run test --coverage=out` | `--coverage out` |
| `sip run test --no-coverage` | `--no-coverage` |

### Concurrency

Prefix a command with `(+) ` to run it concurrently with its neighbours:

```yaml
checks:
  (command):
    - echo "starting"
    - (+) dart format --set-exit-if-changed .
    - (+) dart analyze .
    - echo "done"
```

`sip run checks --no-concurrent` forces everything sequential.

### Environment variables

```yaml
build:
  (command): flutter build apk
  (env): .env                     # one file
```

```yaml
build:
  (command): flutter build apk
  (env):
    file: [.env, .env.local]      # files, merged in order
    command: dart run tool/gen_env.dart   # command(s) whose output defines vars
    vars:
      FLUTTER_BUILD_MODE: release  # inline
```

Env files are parsed line by line: blank lines and `#` comments are skipped,
`KEY=VALUE` sets a variable, and a bare `KEY` sets it to the empty string. A
line with more than one `=` is skipped.

## Running scripts

```bash
sip run <script> [subscript...] [flags]
```

| Flag | Effect |
| --- | --- |
| `--print` | Print the resolved commands without running them |
| `--json` | With `--print`, print those commands as JSON |
| `--bail` | Stop on first error (see gotchas) |
| `--no-concurrent` | Disable all concurrency |
| `--never-exit`, `-n` | Restart the script forever, 1s between runs |
| `--list`, `--ls`, `-l` | List available scripts |

`--print` is the fastest way to check how references, variables and flags
actually expand before running anything.

## Reading sip's output

Every command that reports something takes `--json`, and the payload is the
only thing on stdout -- messages, warnings and errors all go to stderr. sip
emits ANSI colour only when stdout is a terminal, so piped output is plain.

```bash
sip list --json                      # every script, resolved
sip list <query> --json              # only the ones matching a query
sip run <script> --print --json      # one script's resolved commands
sip test --json                      # counts and structured failures
sip validate --json                  # diagnostics with stable codes
```

**Prefer `sip list --json` over reading `scripts.yaml`.** Each entry carries
the dotted `key`, the `path` to pass to `sip run`, the raw `commands` as
written and the `resolved` commands that will actually run -- references,
`(variables)` and `(executables)` already applied. Reading the file tells you
what was declared; this tells you what happens.

```json
{
  "path": ["build_runner", "build"],
  "key": "build_runner.build",
  "aliases": ["b"],
  "private": false,
  "runnable": true,
  "commands": ["${{ build_runner._ }} build"],
  "resolved": [{"command": "fvm dart run build_runner build",
                "concurrent": false}],
  "location": {"file": "/repo/scripts.yaml", "line": 28, "column": 3}
}
```

`runnable: false` means a group with no `(command)` -- run one of its
children. `private: true` means a `_`-prefixed script: referenceable from
another script, but not runnable.

`sip test --json` reports `passed`, `counts`, and a `failures` list with the
file, test name and message for each. Failures that are not test failures --
a compile error, a crashed runner -- are in `errors`, so an empty `failures`
list does not mean the run passed. Check `passed`.

## Validating

Run `sip validate` after editing `scripts.yaml`. It reports problems against
the line they were written on, and catches every gotcha listed below before
a script runs:

```console
scripts.yaml:8:1: error: ${{ a:b }} is not a valid substitution, so it is passed to the shell unchanged.
  Separate script names with dots: ${{ a.b }}
```

Errors exit `78`; warnings exit `0` unless `--fatal-warnings` is passed.
`--json` gives each diagnostic a stable `code` (`unknown-reference`,
`malformed-substitution`, `circular-reference`, `empty-bail`,
`duplicate-alias`, ...) alongside its `location`.

## Testing

```bash
sip test                    # tests in the current package
sip test --recursive        # every package in the repo
sip test --dart-only
sip test --flutter-only
sip test --bail
sip test path/to/a_test.dart
```

| Flag | Effect |
| --- | --- |
| `--recursive`, `-r` | Include subdirectories |
| `--[no-]concurrent`, `-c` | Run concurrently |
| `--bail` | Stop after the first failure |
| `--dart-only` / `--flutter-only` | Restrict by package type |
| `--optimize` | Combine Dart tests into one entrypoint (default: true) |
| `--clean` | Delete generated optimized files afterwards (default: true) |
| `--slice [count]` | Split test files into chunks and run them concurrently |
| `--omit-errors` | Show failures only |
| `--json` | Report counts and structured failures instead of prose |

Unrecognized flags are forwarded to `dart test` / `flutter test`.

`sip test` fails the run both when a test reports a failure and when the test
process exits non-zero, so a failure it cannot parse still fails the run. It
also fails when it finds nothing to test, rather than passing silently.

## Pub

```bash
sip pub get --recursive
sip pub upgrade provider shared_preferences
sip pub downgrade
sip pub deps --json
sip pub constrain --recursive
```

Common flags: `--recursive`/`-r`, `--no-concurrent`, `--bail`/`-b`,
`--dart-only`, `--flutter-only`, `--separated`. `sip pub get` also forwards
`--offline`, `--dry-run`, `--enforce-lockfile`, `--precompile`.

`sip pub constrain` rewrites constraints to the currently resolved versions:

```bash
sip pub constrain                       # all packages
sip pub constrain provider              # only these
sip pub constrain provider --pin        # ^1.2.3 -> 1.2.3
sip pub constrain provider --no-pin     # 1.2.3 -> ^1.2.3
sip pub constrain --bump minor          # breaking | major | minor | patch
sip pub constrain --dev --dry-run
```

## Gotchas

These are verified behaviours of the current release, not style advice.
`sip validate` detects 1, 2 and 4 statically -- run it after editing
`scripts.yaml` rather than relying on remembering them. 3, 5 and 6 are
runtime and argument-parsing behaviours it cannot see.

1. **Colon references are silently not substituted.** `${{ a.b }}` resolves;
   `${{ a:b }}` does not — it is passed to the shell verbatim, which fails
   with `bad substitution`. Always use dots.

2. **`(bail):` with no value does not enable bail.** An empty YAML value is
   `null`, which sip reads as `false`. Write `(bail): true`.

3. **Bail stops launching, but cannot unstart `(+)` commands.** Once a command
   fails under `--bail` or `(bail): true`, no further commands are launched;
   concurrent commands already running still finish.

4. **The variable is `projectRoot`, not `packageRoot`.** An unknown name is
   left unsubstituted and reaches the shell.

5. **A subcommand name after a flag only works for `sip run` and `sip ai`.**
   The command path stops at the first flag. `sip run --bail build` and
   `sip ai --force claude` recover the name; `sip pub --recursive get` does
   not, because pub reads the same list for package names. Put the subcommand
   before the flags.

6. **Unknown flags consume the next argument.** sip forwards flags it does not
   know to `dart`/`flutter`, so it assumes an unknown `--flag` takes a value.
   `sip test --some-flag a_test.dart` reads `a_test.dart` as the flag's value
   and drops it from the file list. Use `--some-flag=value` form, or put
   positional arguments first.
''';

// ---------------------------------------------------------------------------
// Single-file tool templates
// ---------------------------------------------------------------------------

const _preamble = '''
# sip

> sip (`sip_cli`) is a Dart command-line tool for Dart and Flutter repos and
> mono-repos. It runs scripts declared in a `scripts.yaml` file, and runs
> `pub`, `test` and `clean` across every package in a repo — recursively and
> concurrently.

This project uses sip to run its scripts. They are declared in `scripts.yaml`
at the repo root; run them with `sip run <script>`.

Start with `sip list --json` — it reports every script along with the command
it actually runs, so prefer running a declared script over reconstructing its
command yourself. Use `sip run <script> --print` to see what one expands to
without executing it, and `sip validate` after editing `scripts.yaml`.

Install sip with `dart pub global activate sip_cli`.
''';

const agentsMd = '$_preamble\n$sipReference';
const claudeMd = '$_preamble\n$sipReference';
const copilotMd = '$_preamble\n$sipReference';
const windsurfRules = '$_preamble\n$sipReference';
const clineRules = '$_preamble\n$sipReference';

// ---------------------------------------------------------------------------
// Cursor MDC files — glob-scoped so they attach only where they are relevant
// ---------------------------------------------------------------------------

const cursorMdcFiles = <String, String>{
  'sip-scripts.mdc': r'''
---
description: Authoring scripts.yaml for the sip CLI — keys, references, variables, concurrency, env
globs: scripts.yaml
alwaysApply: false
---

# scripts.yaml (sip)

`scripts.yaml` declares the scripts that `sip run` executes. It lives at the
repo root, and `sip run` always executes from its directory.

## Structure

Every top-level key is a script, except the reserved parenthesized keys. A
script is either a plain command or a map; in a map, `(command)` is what the
script runs and any non-reserved key is a nested subscript.

```yaml
(executables):
  flutter: fvm flutter

(variables):
  coverage_dir: coverage

format:
  (command): ${{ dart }} format .
  ui: cd packages/ui && ${{ format }}

test:
  (aliases): [t]
  (description): Run the test suite
  (command): ${{ dartOrFlutter }} test ${{ --coverage }}
```

## Reserved keys

| Key | Scope | Meaning |
| --- | --- | --- |
| `(command)` | script | The command(s) to run — string or list |
| `(aliases)` | script | Alternate names — string or list |
| `(description)` | script | Shown by `sip list` |
| `(bail)` | script | Stop on first error — must be `true`, not empty |
| `(env)` | script | Env vars to load first |
| `(variables)` | top level | User-defined string variables |
| `(executables)` | top level | Override `dart` / `flutter` |

## Key rules

Pattern `^_?([a-z][a-z0-9_.\-]*)?(?<=[a-z0-9_])$`, case-insensitive: start
with a letter or `_`, end with a letter, digit or `_`, no spaces. Keys
starting with `_` are private — referenceable, but not runnable and not
listed.

## References and variables

Reference another script with dots. **Colons do not work** — `${{ a:b }}` is
passed to the shell verbatim and fails with `bad substitution`.

```yaml
pub:
  (command): ${{ dart }} pub
  get: ${{ pub }} get
  ui: cd packages/ui && ${{ pub.get }}
```

Built-ins: `${{ projectRoot }}` (dir of nearest `pubspec.yaml` — **not**
`packageRoot`), `${{ scriptsRoot }}`, `${{ cwd }}`, `${{ dart }}`,
`${{ flutter }}`, `${{ dartOrFlutter }}`.

Forward a flag with `${{ --flag }}`; flags the script does not name are
dropped. `sip run test --coverage=out` expands `${{ --coverage }}` to
`--coverage out`.

## Concurrency

Prefix with `(+) ` to run concurrently with neighbouring commands:

```yaml
checks:
  (command):
    - (+) ${{ dart }} format --set-exit-if-changed .
    - (+) ${{ dart }} analyze .
```

`--no-concurrent` forces sequential execution.

## Environment

```yaml
build:
  (command): ${{ flutter }} build apk
  (env):
    file: [.env, .env.local]
    command: dart run tool/gen_env.dart
    vars:
      MODE: release
```

Env files skip blanks and `#` comments; `KEY=VALUE` sets a value, bare `KEY`
sets empty, and lines with more than one `=` are skipped.

## Verify before running

`sip validate` checks the whole file and reports each problem against the
line it was written on -- unresolvable references, `${{ a:b }}`, circular
references, invalid names, duplicate aliases, a valueless `(bail)`. Run it
after every edit.

`sip run <script> --print` prints the fully resolved commands without
executing them. Use it to confirm references and flags expanded as intended.
''',

  'sip-cli.mdc': r'''
---
description: Running the sip CLI — run, test, pub, clean, and the failure modes worth knowing
globs: scripts.yaml,pubspec.yaml
alwaysApply: false
---

# sip CLI

| Command | Purpose |
| --- | --- |
| `sip run <script>` (`sip r`) | Run a script from `scripts.yaml` |
| `sip list [query]` (`sip ls`) | List or search scripts |
| `sip validate` | Check `scripts.yaml` without running anything |
| `sip test [files or dirs]` | Run Dart/Flutter tests |
| `sip pub <get\|upgrade\|downgrade\|deps\|constrain>` | Pub across packages |
| `sip clean` | Remove `.dart_tool`/`build`, run `flutter clean` |
| `sip mcp` | Run sip as an MCP server over stdio |
| `sip update` | Update sip itself |

## Machine-readable output

`sip list`, `sip run --print`, `sip test` and `sip validate` all take
`--json`. The payload is the only thing on stdout; everything else goes to
stderr. Colour is emitted only when stdout is a terminal.

`sip list --json` is the fastest way to learn a project: it gives every
script's dotted `key`, the `path` to pass to `sip run`, the raw `commands`
and the `resolved` commands that actually run. Prefer it to reading
`scripts.yaml`, which does not tell you what a reference expands to.

## run

`--print` (resolve without executing), `--json` (with `--print`), `--bail`,
`--no-concurrent`, `--never-exit`/`-n` (restart forever, 1s apart),
`--list`/`-l`.

## validate

Run it after editing `scripts.yaml`. Reports unresolvable references,
malformed `${{ }}`, circular references, invalid names, duplicate aliases and
a valueless `(bail)` -- each against its line. Errors exit `78`; `--json`
gives each diagnostic a stable `code`.

## test

`--recursive`/`-r`, `--[no-]concurrent`/`-c`, `--bail`, `--dart-only`,
`--flutter-only`, `--optimize` (default true), `--clean` (default true),
`--slice [count]`, `--omit-errors`. Unknown flags are forwarded to
`dart test` / `flutter test`.

## pub

`--recursive`/`-r`, `--no-concurrent`, `--bail`/`-b`, `--dart-only`,
`--flutter-only`, `--separated`. `sip pub constrain` rewrites constraints to
resolved versions and takes `--pin`/`--no-pin`, `--bump <breaking|major|minor|patch>`,
`--dev`, `--dry-run`.

## Failure modes

1. **`sip test` fails on either signal.** A reported test failure *or* a
   non-zero exit from the test process fails the run, so a failure the output
   parser cannot read still fails it. Finding no packages to test is also a
   failure (`66`), not a silent pass.

2. **Bail stops launching, not running work.** After a failure under `--bail`
   or `(bail): true`, nothing further is launched, but concurrent `(+)`
   commands already running finish.

3. **`(bail):` with no value is `false`.** Write `(bail): true`.

4. **Unknown flags eat the next argument.** Because sip forwards unknown flags
   to `dart`/`flutter`, it assumes they take a value:
   `sip test --some-flag a_test.dart` swallows the file. Prefer
   `--some-flag=value`, or put positional arguments first.

5. **`${{ a:b }}` is not substituted.** Use dots: `${{ a.b }}`.
''',
};
