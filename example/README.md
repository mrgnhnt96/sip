# SIP

Sip is a command-line tool that simplifies managing Dart and Flutter projects. It helps you run scripts, manage pub commands, execute tests, and more — all from a single configuration file.

![Sip](../assets/build_runner.gif)

## Features

- Define and run scripts from a `scripts.yaml` file

  - Supports nested scripts
  - Run scripts concurrently

- Run pub commands (`pub get`, `pub upgrade`, etc.)

  - Runs **recursively and concurrently**

- Run Dart/Flutter tests

  - Recursive mode
  - Fail fast mode (stops running tests after the first failure)
  - Run only Dart or only Flutter tests

- Customize executable commands (`dart`, `flutter`, etc.)

- Validate `scripts.yaml` before running it (`sip validate`)

- Work with AI coding assistants

  - `--json` output for `list`, `run --print`, `test` and `validate`
  - An MCP server (`sip mcp`)
  - Reference files for the popular assistants (`sip ai`)

## Installation

```bash
dart pub global activate sip_cli
```

## Usage

```bash
sip --help
```

## Quick Start

Create a `scripts.yaml` file in your project root:

```yaml
# scripts.yaml
hello:
  world: echo "Hello, World!"
```

Run your script:

```bash
sip run hello world
```

## `scripts.yaml` Configuration

The `scripts.yaml` file defines all scripts and configuration for Sip. It usually lives in your project root.

### Executable Commands

Sip uses `dart` and `flutter` by default. To override them:

```yaml
(executables):
  dart: fvm dart
  flutter: fvm flutter
```

### Defining a Script

A script maps a key to a command:

```yaml
build_runner: dart run build_runner build
```

```bash
sip run build_runner
```

Commands can also be lists:

```yaml
build_runner:
  - cd packages/core && dart run build_runner build
  - cd packages/data && dart run build_runner build
```

### Script Key Rules

- Allowed pattern: `^_?([a-z][a-z0-9_.\-]*)?(?<=[a-z0-9_])$`
- Keys wrapped in parentheses (e.g., `(command)`) are reserved
- Must start with a letter or `_`
- Must end with a letter, number, or `_`

### Nested Scripts

You can nest scripts:

```yaml
format:
  ui: cd packages/ui && dart format .
  core: cd packages/core && dart format .
```

Use `(command)` to specify a default command for the top level script itself:

```yaml
format:
  (command): dart format .
  ui: cd packages/ui && dart format .
  core: cd packages/core && dart format .
```

### Listing Scripts

```bash
sip list   # or sip ls
```

Search:

```bash
sip list build_runner
```

To explore nested scripts, you can use the `--help` flag:

```bash
sip run build_runner --help
```

#### Machine-readable listing

`--json` prints every script as data instead of a tree — its dotted key, its
aliases and description, the raw commands as written, the **fully resolved**
commands that will actually run, and the `scripts.yaml` line it was declared
on:

```bash
sip list --json
sip list build --json      # only scripts matching a query
sip list --json --no-resolve   # skip expanding references and variables
```

```json
{
  "version": 1,
  "scriptsYaml": "/repo/scripts.yaml",
  "executables": { "dart": "fvm dart" },
  "variables": { "projectRoot": "/repo" },
  "scripts": [
    {
      "path": ["build_runner", "build"],
      "key": "build_runner.build",
      "name": "build",
      "parent": "build_runner",
      "aliases": ["b"],
      "description": null,
      "private": false,
      "runnable": true,
      "bail": false,
      "commands": ["${{ build_runner._ }} build"],
      "resolved": [
        { "command": "fvm dart run build_runner build", "concurrent": false }
      ],
      "resolveError": null,
      "env": null,
      "location": { "file": "/repo/scripts.yaml", "line": 28, "column": 3 }
    }
  ]
}
```

Pass the `path` back to `sip run` (`sip run build_runner build`). A script
that cannot be resolved reports why in `resolveError` instead of failing the
whole listing.

### Referencing Other Scripts

Use `${{ key }}` to reference another script:

```yaml
pub_get: dart pub get
pub_get_ui: cd packages/ui && ${{ pub_get }}
```

References work with nesting:

```yaml
pub:
  (command): dart pub
  get: "${{ pub }} get"
  ui: cd packages/ui && ${{ pub.get }}
```

> [!IMPORTANT]
> Nested references are separated by dots. A colon (`${{ pub:get }}`) is not
> substituted — it is passed to the shell verbatim and fails with
> `bad substitution`.

### Flags

Sip forwards only the flags and arguments you explicitly include using `${{ --FLAG_NAME }}`:

```yaml
test: dart test ${{ --coverage }}
```

Examples:

```bash
sip run test --coverage=coverage
sip run other --flag value1 value2 --verbose
```

Unspecified flags are ignored.

### Private Keys

Private keys (starting with `_`) cannot be run directly, but can be referenced:

```yaml
format:
  _hidden: dart format .
  (command): cd packages/ui && ${{ format._hidden }}
```

### Bail

Use `--bail` to stop running as soon as a command fails:

```bash
sip run format --bail
```

Or set it in config:

```yaml
format:
  (bail): true
  (command): dart format
```

> [!NOTE]
> `(bail)` must be given an explicit `true`. An empty value (`(bail):`) is
> parsed as `null` and read as `false`.

### Concurrent Commands

Run scripts concurrently using `(+)`:

```yaml
format:
  (command):
    - echo "Running format"
    - (+) cd packages/ui && dart format .
    - (+) cd packages/core && dart format .
    - echo "Finished running format"
```

You can disable concurrency by passing the `--no-concurrent` flag.

```bash
sip run format --no-concurrent
```

### Variables

Sip provides built-in variables:

- `${{ projectRoot }}`: The nearest `pubspec.yaml` to the current working directory
- `${{ scriptsRoot }}`: The nearest `scripts.yaml` to the current working directory
- `${{ cwd }}`: The current working directory
- `${{ dartOrFlutter }}`: Either `dart` or `flutter` executable, depending on the nearest `pubspec.yaml` to the current working directory
- `${{ dart }}`: The `dart` executable
- `${{ flutter }}`: The `flutter` executable

Define custom variables under `(variables)`:

```yaml
(variables):
  ocarinaTune: |-
    echo "Playing Song of Time..."
```

Use them:

```yaml
play: ${{ ocarinaTune }}
```

### Example `scripts.yaml`

```yaml
(variables):
  flutter: fvm flutter

build_runner:
  build: dart run build_runner build
  watch:
    (description): Run build_runner in watch mode
    (command): dart run build_runner watch
    (aliases): [w]

test:
  (command): "${{ flutter }} test ${{ --coverage }}"
  coverage: "${{ test }} --coverage=coverage"

echo:
  dirs:
    - echo "${{ projectRoot }}"
    - echo "${{ scriptsRoot }}"
    - echo "${{ cwd }}"

format:
  _command: dart format .
  (command):
    - echo "Running format"
    - (+) ${{ format.ui }}
    - (+) ${{ format.data }}
    - (+) ${{ format.application }}
    - echo "Finished running format"

  ui: cd packages/ui && ${{ format._command }}
  data: cd packages/data && ${{ format._command }}
  application: cd application && ${{ format._command }}
```

## Running Scripts

Sip always executes from the directory containing your `scripts.yaml`, regardless of your current working directory.

```bash
sip run build_runner build
```

Run `sip run --help` for all available flags.

`--print` shows the resolved commands without executing them, and `--json`
alongside it prints them as data:

```bash
sip run build_runner build --print
sip run build_runner build --print --json
```

## Validating `scripts.yaml`

`sip validate` checks the file without running anything, and reports each
problem against the line it was written on:

```bash
sip validate
sip validate --json             # structured diagnostics with stable codes
sip validate --fatal-warnings   # exit non-zero for warnings too
```

```console
scripts.yaml:8:1: error: ${{ a:b }} is not a valid substitution, so it is passed to the shell unchanged.
  Separate script names with dots: ${{ a.b }}
scripts.yaml:16:3: warning: (bail) has no value, which sip reads as false.
  Write `(bail): true`.
1 error, 1 warning
```

It finds:

| Code | Severity | What it catches |
| --- | --- | --- |
| `invalid-yaml` | error | The file does not parse |
| `unknown-reference` | error | `${{ x }}` names no script or variable |
| `malformed-substitution` | error | `${{ a:b }}` and friends, passed to the shell verbatim |
| `reference-has-no-command` | error | A reference to a group with no `(command)` |
| `circular-reference` | error | Scripts that reference each other in a loop |
| `invalid-key` | error | A script name sip rejects |
| `empty-bail` | warning | `(bail):` with no value, which reads as `false` |
| `unknown-reserved-key` | warning | `(descriptions)` and other near-misses |
| `duplicate-alias` | warning | An alias claimed twice, which deactivates it |
| `empty-script` | warning | A script with no `(command)` and no subscripts |

Errors exit `78`. Warnings exit `0` unless `--fatal-warnings` is passed.
Diagnostics go to stderr, so `--json` output on stdout stands alone.

## Environment Configuration

You can load environment variables before running a script:

```yaml
build:
  (command): flutter build apk
  (env): .env # or ['.env', '.env.local']
```

Or run a command to generate env vars:

```yaml
(env):
  file: .env # or ['.env', '.env.local']
  command: dart run generate_env.dart # can be a list of commands
```

Or inline variables:

```yaml
(env):
  vars:
    FLUTTER_BUILD_MODE: release
```

Parent script env overrides nested script env.

## Continuous Commands

Use `--never-exit` to restart a command whenever it fails:

```bash
sip run build_runner watch --never-exit
```

> [!WARNING]
> Use with caution — the command restarts indefinitely.
> You can stop the script by pressing `Ctrl + C`.
> There is a 1 second delay between each run of the command, to prevent any runaway scripts.

## Running Tests

Run all tests:

```bash
sip test --recursive
```

Dart-only:

```bash
sip test --dart-only
```

Flutter-only:

```bash
sip test --flutter-only
```

Fail fast:

```bash
sip test --bail
```

> [!NOTE]
> `sip test` fails when a test fails, when the test process exits non-zero, and
> when it finds no packages to test — running nothing is not a pass.

Machine-readable results:

```bash
sip test --json
```

```json
{
  "passed": false,
  "counts": { "passing": 12, "failing": 1, "skipped": 0 },
  "failures": [
    {
      "path": "test/a_test.dart",
      "test": "fails loudly",
      "error": "Expected: <2>\n  Actual: <1>"
    }
  ],
  "skipped": [],
  "errors": []
}
```

`errors` holds failures that are not test failures — a compile error, a
crashed runner, output sip could not parse. A run with an empty `failures`
list and a non-empty `errors` list still failed, which is why `passed`
exists rather than leaving it to be inferred from the counts.

### Experimental: Flutter Test Bucketing

> [!WARNING]
> Experimental and strictly opt-in — may change or be removed without notice.

For large Flutter widget-test suites, `--experimental-bucket` combines test files into a handful of generated bucket files (one `flutter test` invocation per shard) to cut per-file VM-isolate startup overhead:

```bash
sip test --experimental-bucket
```

Files that can't be safely combined (an explicit non-default `TestWidgetsFlutterBinding` subtype, or a test-surface mutation like `tester.view.physicalSize` left unreset) always run in their own isolated wrapper, never sharing an isolate with anything else. If a bucket's combined run looks untrustworthy — a compile error or hard binding assertion cuts it short — just that bucket's files are automatically discarded and re-run individually, and this is logged clearly.

This does **not** catch arbitrary test-state leakage between files sharing an isolate (e.g. an unreset image cache) — that class of bug can't be caught statically or by the fallback above, so treat a bucketed run as a strong signal, not a guarantee of unbucketed-equivalent results.

For CI matrix jobs, split the generated buckets across N jobs with `--bucket-shard-index`/`--bucket-shard-count` (entirely sip-side; distinct from `flutter test`'s own `--shard-index`/`--total-shards`, which isn't recommended for this since it still pays full test-graph discovery/compile cost per shard):

```bash
sip test --experimental-bucket --bucket-shard-index=0 --bucket-shard-count=4
```

`--bucket-count` controls how many combined bucket files are generated (default: number of processors).

## AI Coding Assistants

Install a sip reference file so your AI assistant knows how `scripts.yaml` and
the CLI work:

```bash
sip ai agents     # AGENTS.md
sip ai claude     # CLAUDE.md
sip ai cursor     # .cursor/rules/sip-*.mdc
sip ai copilot    # .github/copilot-instructions.md
sip ai windsurf   # .windsurfrules
sip ai cline      # .clinerules
sip ai all        # every file above
```

Existing files are left alone; pass `--force` to overwrite them.

### MCP server

`sip mcp` runs sip as an [MCP](https://modelcontextprotocol.io) server over
stdio, so an assistant discovers your scripts as tools instead of having to
remember a CLI convention:

| Tool | What it does |
| --- | --- |
| `list_scripts` | Every script, with the commands it actually runs |
| `dry_run` | What a script expands to, without running it |
| `run_script` | Run a declared script; returns exit code, stdout and stderr |
| `validate` | Check `scripts.yaml` for problems |

Point your assistant at it:

```json
{
  "mcpServers": {
    "sip": { "command": "sip", "args": ["mcp"] }
  }
}
```

`run_script` takes a script name, never a command, so it cannot run anything
that is not declared in `scripts.yaml`. What a declared script does is of
course up to your project, so the tool is marked destructive.

### Output for scripts and assistants

sip's output is meant to be read by whoever is reading it:

- **Colour follows the terminal.** Piped or redirected output is plain text.
  `--color` / `--no-color`, `NO_COLOR`, `FORCE_COLOR` and `TERM=dumb`
  override the guess.
- **The update notice never touches stdout.** It goes to stderr, and is
  skipped entirely (along with its network request) when stdout is not a
  terminal. `--no-version-check` or `SIP_NO_VERSION_CHECK=1` also turn it off.
- **`--json` output stands alone on stdout.** Every message, warning and
  error goes to stderr.

## Pub Commands

### Pub Get

```bash
sip pub get
```

Automatically detects whether to use `dart` or `flutter`.

Recursive:

```bash
sip pub get --recursive
```

### Pub Upgrade

```bash
sip pub upgrade
```

Upgrade all or specific packages:

```bash
sip pub upgrade provider shared_preferences
```

### Pub Downgrade

```bash
sip pub downgrade
```

### Pub Deps

```bash
sip pub deps --json
```

### Pub Constrain

Constrain versions to your current resolution:

```bash
sip pub constrain
```

Constrain only selected packages:

```bash
sip pub constrain provider shared_preferences:2.3.0
```

Pin versions:

```bash
sip pub constrain provider --pin
```

Unpin:

```bash
sip pub constrain provider --no-pin
```

Supported flags:

- `recursive`
- `dev_dependencies`
- `bump` (`breaking`, `major`, `minor`, `patch`)
- `dry-run`
- `dart-only`
- `flutter-only`
- `pin`
- `no-pin`
