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
  (bail):
  (command): dart format
```

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

- `${{ packageRoot }}`: The nearest `pubspec.yaml` to the current working directory
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
    - echo "${{ packageRoot }}"
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
