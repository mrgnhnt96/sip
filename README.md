# SIP

A command-line tool to handle mono-repos in dart/flutter

## Installation

```bash
dart pub global activate sip
```

## Usage

```bash
sip --help
```

## Script Execution Commands

Regardless of your current working directory, the script will always be executed from the same directory as the `scripts.yaml` file.

### RUN

The `sip run` command will run a script defined within the `scripts.yaml` file.

```yaml
build_runner:
    build: dart run build_runner build --delete-conflicting-outputs
```

```bash
$ sip run build_runner build

- dart run build_runner build --delete-conflicting-outputs
...
```

### RUN-MANY

The `sip run-many` command will run a script defined within the `scripts.yaml` file concurrently.

```yaml
pub:
    get:
        - cd packages/core && dart pub get
        - cd packages/data && dart pub get
        - cd packages/ui && flutter pub get
```

```bash
$: sip run-many pub get

- Running "cd packages/core && dart pub get"
- Running "cd packages/data && dart pub get"
- Running "cd packages/ui && flutter pub get"
```

## Pub Commands

### PUB GET

`sip pub get` runs `pub get` in the closest parent directory containing a `pubspec.yaml` file.

```bash
# Current working directory: packages/core/lib
$ sip pub get

- Running pub get

- (dart)    ./..
```

Sip can determine if flutter is being used within the project, so it will run `flutter pub get` instead of `dart pub get`.

```bash
# Current working directory: packages/ui/lib
$ sip pub get

- Running pub get

- (flutter) ./..
```

#### Recursively

`sip pub get --recursive` runs `pub get` in all children directories containing a `pubspec.yaml` file, **_concurrently_**.

**_Note:_** A pubspec.yaml file does not need to be present in the current working directory.

```bash
# Current working directory: packages
$ sip pub get --recursive

- Running pub get

- (dart)    ./core
- (dart)    ./data
- (flutter) ./ui
```

### PUB UPGRADE

`sip pub upgrade` runs `pub upgrade`. It performs and functions the same as `sip pub get` but will upgrade all dependencies to the latest version.

## `Script.yaml` configuration

```yaml
# scripts.yaml

# The name of the script
build_runner:

    # The command to run
    build: dart run build_runner build --delete-conflicting-outputs

    watch:
        # The description of the script
        (description): Run build_runner in watch mode

        # The alternative way to define the command
        (command): dart run build_runner watch --delete-conflicting-outputs

        # The aliases for the script
        (aliases):
            - w

test:
    # {--coverage} is an optional argument, if it is provided, it will be passed into the command, otherwise it will be ignored
    (command): dart test test {--coverage}

    # {$test} references the defined script `test`. The flag `--coverage=coverage` will activate the coverage flag found in`test`, passing it (--coverage) and it's value (=coverage) to the `test` command
    # Supported flag formats:
    #    e.g. --flag  |  --flag=value  |  --flag value1 value2
    # Supports multiple flags
    #    e.g. --flag1 --flag2=value2 --flag3 value3 value4
    coverage: "{$test} --coverage=coverage"

echo:
    dirs:
        - echo "{packageRoot}" # The directory that the pubspec.yaml file is in
        - echo "{scriptsRoot}" # The directory that the scripts.yaml file is in
        - echo "{cwd}" # The current directory that you are in

```
