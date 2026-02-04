# TODO

## Features

- Create VSCode extension
  - Support embedded bash language
    - Syntax highlighting
    - Completions
    - Linting
    - Formatting

## Fix

### Fake Circular Reference Detection

```yaml
# What sip_cli uses for built in commands
(executables):
  dart: fvm dart
  flutter: fvm flutter

# Folders
_drops: cd drops

# Private Utilities
_build_runner:
  build: ${{ dart }} run build_runner build

# Public Commands
build: ${{_drops}} && ${{_build_runner.build}}
setup:
  - sip pub get -r
  - ${{_drops}} && ${{flutter}} gen-l10n
  - ${{build}}
```

Running `sip run setup` results in

```console
Exception: Circular reference detected: ${{_drops}}
"build" referenced from "setup"
```

But this is false

### Test count

- When running tests (not on CI), the test count is not accurate, sometimes the number increments more than 1 at a time.

### Internal `sip pub get` command stalls out

Add a `sip pub get -r` command within the `script.yaml` file and run it. The command stalls out and never finishes.

### Convert `dartOrFlutter` variable to shell script

We are resolving the `dartOrFlutter` variable pre-script execution. Meaning that the same value will be used regardless of where the script tries to `cd` to

### Too many entries

```yaml
_packages_root: ${{scriptsRoot}}/drops/app/packages
_packages:
  - (+) cd ${{_packages_root}}/base_isolate_encapsulation
  - (+) cd ${{_packages_root}}/roon_dev_utility
  - (+) cd ${{_packages_root}}/roon_flutter_widgets
  - (+) cd ${{_packages_root}}/short_background_op_manager
pub_get: ${{_packages}} && ${{dartOrFlutter}} pub get
```

This outputs N^2 entries in the script execution.

the duplication is happening when you have a list inside another list

```yaml
pub_get:
  (command): ${{_drops}} && ${{flutter}} pub get
  all:
    - ${{pub_get}}
    - ${{pub_get_packages}}
pub_get_packages:
  - cd ${{scriptsRoot}}/drops/app/packages/base_isolate_encapsulation && ${{flutter}} pub get
  - cd ${{scriptsRoot}}/drops/app/packages/roon_dev_utility && ${{flutter}} pub get
  - cd ${{scriptsRoot}}/drops/app/packages/roon_flutter_widgets && ${{flutter}} pub get
  - cd ${{scriptsRoot}}/drops/app/packages/short_background_op_manager && ${{flutter}} pub get
```

Running pub_get_packages works correctly. Running pub_get all duplicates.
lol, but this works perfectly for both

```yaml
pub_get:
  (command): ${{_drops}} && ${{flutter}} pub get
  all:
    - ${{pub_get}}
    - ${{pub_get.packages}}
  packages:
    - cd ${{_packages_root}/base_isolate_encapsulation && ${{flutter}} pub get
    - cd ${{_packages_root}/roon_dev_utility && ${{flutter}} pub get
    - cd ${{_packages_root}/roon_flutter_widgets && ${{flutter}} pub get
    - cd ${{_packages_root}/short_background_op_manager && ${{flutter}} pub get
```

Running pub_get all or pub_get packages works fine.
Even with concurrency
Although the concurrent path without --print doesn't return control back to the terminal after running it.
