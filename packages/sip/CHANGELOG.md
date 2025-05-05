# 0.17.10 | 5.5.2025

## Fixes

- Issue where test output was empty when it shouldn't be

# 0.17.9 | 5.2.2025

## Enhancements

- Add env variables to `env` after sourcing the env file
- Improve test output formatting

# 0.17.7 | 5.2.2025

## Fixes

- Issue where env commands were not being resolved correctly

# 0.17.6 | 4.19.2025

## Enhancements

- Always show the cursor when the process is interrupted
  - Sometimes the cursor would not be visible when the process was interrupted and the cursor would remain hidden

# 0.17.5 | 4.12.2025

## Fixes

- Issue where a reference command that contains concurrency would loop indefinitely

# 0.17.4 | 4.7.2025

## Fixes

- Crash when a reference does not contain any commands to run

# 0.17.3 | 4.5.2025

## Fixes

- Issue where a command following a non-concurrent command would be skipped

# 0.17.2 | 4.3.2025

## Fixes

- Issue where env would not be resolved completely if there were no env commands
- Issue where concurrency commands resolution would fail when env configs were present

## Enhancements

- Improve "There's a new version available" message

# 0.17.0 | 3.27.2025

## Features

- Add support for defining env variables within `(env)`

# 0.16.3 | 3.26.2025

## Fixes

- Issue where a command that contains variables/flags would be skipped when following a concurrent command

## Enhancements

- Add `--print` flag to `sip run` command
  - Prints out the commands that would be run without executing them

# 0.16.2 | 3.21.2025

## Enhancements

- When running pub commands, ignore pubspecs within directories that start with a dot
- Add working directory to error output
- Add index of command to error output

# 0.16.1 | 3.11.2025

## Fixes

- Issue where concurrency commands could run sequentially, unintentionally

# 0.16.0 | 3.10.2025

## Features

- Scope concurrency to original scripts
- Add listener to watch for SIGINT signal to stop the process

# 0.15.2 | 3.4.2025

## Fix

- Fix issue where test directories were not identified correctly when parent directory starts with`test`

# 0.15.1 | 2.24.2025

## Features

- Add executables to variables to be used in commands

  ```yaml
  (executables):
    flutter: fvm flutter
    dart: fvm dart

  build_runner: "{dart} run build_runner build"
  ```

# 0.15.0 | 2.22.2025

## Features

- Add support to `sip pub constrain` command to constrain specific packages to a specific version
- Add support to `sip pub constrain` command to unpin (`--no-pin`)
  - e.g. `provider: 5.0.0` will be unpinned to `^5.0.0`

# 0.14.6 | 1.18.2025

## Features

- Don't exit with non-zero when no test directories are found

# 0.14.5 | 1.17.2025

## Features

- Flutter tests respect the `--bail` flag during `sip test` command
  - If a test fails, the command will stop running tests and exit with a non-zero exit code

# 0.14.4 | 1.3.2025

## Fixes

- Issue where formatting test output could result in an exception thrown

# 0.14.2 | 1.3.2025

## Enhancements

- Improve the output when running flutter tests
- Improve the output when running dart tests

# 0.14.1 | 12.17.2024

## Features

- Override `dart` and `flutter` executable by using `(executables)` within the `scripts.yaml file

```yaml
(executables):
  dart: fvm dart
  flutter: fvm flutter
```

## Enhancements

- Ignore build and dart tool directories when running pub commands

## Fixes

- Check for empty tests when no dart/flutter tests are found when targeting dart/flutter tests only

# 0.13.6 | 11.29.2024

## Fixes

- Bug where env reference commands may not be resolved
- Bug that did not remove concurrency symbols from env file commands

# 0.13.5 | 11.22.2024

## Features

- Check for dependencies when running `sip pub upgrade <packages>`
  - If the package is not found in the `pubspec.yaml` file, that `pubspec.yaml` file will be skipped

# 0.13.4+1 | 11.22.2024

## Features

- Pin versions of packages by providing the `--pin` flag to the `constrain` command
  - e.g. `sip pub constrain --pin` will pin all packages to their current versions

# 0.13.3 | 11.21.2024

## Features

- Constrain certain packages by providing their package names to the `constrain` command
  - e.g. `sip pub constrain analyzer test` will constrain only the `analyzer` and `test` packages

# 0.13.2 | 11.21.2024

## Features

- Support querying scripts from `sip list`
  - Usage: `sip list [query] [arguments]`
  - Searches for
    - Script keys that contain the query string
    - Aliases that match the query string
    - Descriptions that contain the query string

# 0.13.1 | 11.20.2024

## Fixes

- `sip update` should now update to the latest version properly

# 0.13.0 | 11.20.2024

## Features

- Pass packages to `sip pub upgrade` when provided
  - e.g. `sip pub upgrade analyzer test` will run `<dart|flutter> pub upgrade analyzer test`
- Create new `sip pub constrain` command
  - Constrains all dependency versions in the `pubspec.yaml` file
- Create new `sip pub deps` command
  - Lists all dependencies in the `pubspec.yaml` file by running `<dart|flutter> pub deps`
- Add `--unlock-transitive` flag to `sip pub upgrade` command
  - This will unlock all transitive dependencies when upgrading packages
- Create new `sip pub downgrade` command
  - Downgrades all dependencies in the `pubspec.yaml` file by running `<dart|flutter> pub downgrade`

## Enhancements

- Always include a space after the label when running scripts concurrently to format the output better

# 0.12.0+3 | 10/30/2024

## Features

- Run all Env commands at the start of all scripts
  - Skips this when there are no env commands to run
- Update check that the file to the env exists before running the command
  - Exits with 1 if the file does not exist
- Skip test directories that have no files to test when optimizing tests

# 0.11.0 | 9/26/2024

## Breaking Changes

- Remove test optimization for Flutter tests

# 0.10.0 | 9/25/2024

## Features

- Search for barrel file to include in optimized test files
  - This is to better support coverage reports
  - By including this import statement, files without tests will be included in the coverage report
  - The barrel file must be named after the project directory or package name and reside in the `lib` directory
    - eg. `domain/lib/domain.dart` or `lib/my_package.dart`

# 0.9.1 | 9/11/2024

## Breaking Changes

- Deprecate script_runner package, in favor of dart's processes for more control over running commands
  - This will allow for better control over running commands and better error handling

## Features

- Print the output when a script fails during concurrency

# 0.8.3 | 7/29/2024

## Fixes

- Change directory to project root before sourcing env files

# 0.8.2 | 7/26/2024

## Features

- Support multiple env files

  ```yaml
  my-script:
    (command): echo $MY_ENV_VAR
    (env):
      - .env
      - .env.local
  ```

# 0.8.1 | 7/26/2024

## Features

- Support env files for scripts

  ```yaml
  my-script:
    (command): echo $MY_ENV_VAR
    (env): .env
  ```

# 0.7.1 | 6/7/2024

## Enhancements

- Add new alias to clean command `pubspecs`
  - Existing: 'lock', 'locks', 'pubspec-locks'

## Fixes

- Exit clean command when no directories are found to clean

# 0.7.0 | 6/7/2024

## Breaking Changes

- Revert change to run dart and flutter commands separately
  - To continue running dart and flutter commands separately, use the `--separated` flag

# 0.6.1 | 6/3/2024

## Fixes

- Issue where exception was thrown if `bail` flag was not defined in `ArgParser`

# 0.6.0 | 5/8/2024

## Features

- Support running specific tests by providing a test file or directory

  - `sip test ./test/my_test.dart`
  - `sip test ./test`

- Create new `clean` command

  - Removes all `.dart_tool` and `build` directories in dart & flutter packages
  - Run `flutter clean` in flutter packages

- Increase retry time frame from 2s to 4s for `flutter pub get` command

# 0.5.1 | 5/6/2024

## Fixes

- An issue where some flutter test arguments were being duplicated

# 0.5.0 | 5/1/2024

## Breaking Changes

- Add `--no-pub` when testing Flutter packages

## Enhancements

- Update copy when testing packages to
  - Display Flutter test type
  - Display args
  - Update colors for better readability

## Features

- Speed up getting dependencies via an internal auto-retry mechanism
  - For whatever reason, dart/flutter will hang after dependencies are retrieved for a lengthy amount of time. SIP_CLI will now auto-retry if the `pub get` command has been running for too long

# 0.4.6 | 4/11/2024

- Downgrade args dependency to <2.5.0

# 0.4.5 | 4/10/2024

## Features

- Support different flutter test types to avoid clashing during tests
  - `TestWidgetsFlutterBinding`, `AutomatedTestWidgetsFlutterBinding`, `LiveTestWidgetsFlutterBinding` can be used to specify the types of tests to run and CANNOT be used together
  - SIP_CLI will create a new test file for each type of test to avoid clashing

# 0.4.4 | 3/25/2024

## Fixes

- Fix issue where tests were not run without passing an argument to the `sip test` command

# 0.4.3 | 3/18/2024

## Breaking Changes

- Remove `--ignore-lockfile-exit` flag from `sip pub get` command

# 0.4.2 | 3/15/2024

## Fixes

- Create alternative flags for the `--coverage` flags as they exist in both flutter and dart but accept different arguments
  - `--coverage` for dart is changed to `--dart-coverage`
  - `--coverage` for flutter is changed to `--flutter-coverage`

## Features

- Support running pub commands for dart or flutter packages only
- If the `--coverage` flag is provided in the `sip test` command, default values will be provided to dart and flutter
  - Dart: Coverage is enabled and sets the coverage directory to `coverage`
  - Flutter: coverage is enabled
- Add `--ignore-lockfile-exit` flag to `sip pub get` command
  - When using `--enforce-lockfile`, if the lockfile is not up to date, the command will exit with a non-zero exit code. When using `--ignore-lockfile-exit`, the command ignore the non-zero exit. Even if the lockfile is not up to date, the dependencies will still be retrieved.

## Enhancements

- Update copy for the `--version-check` flag

# 0.4.1 | 3/12/2024

## Enhancements

- Don't check for update after running `sip update`

# 0.4.0 | 3/12/2024

## Breaking Changes

- Rename `.optimized_test.dart` to `.test_optimizer.dart`
  - Helps avoid unintentionally running optimized tests
- Rename `--run` to `--scope` for the `sip test watch` command
- Rename `package` to `active` for improved comprehension regarding the test scope for the `sip test watch` command

## Features

- Create a new command to clean up optimized test files `sip test clean`

## Enhancements

- Wait for a max of 1 second to check for the latest version for `sip_cli`

# 0.3.0 | 3/12/2024

## Features

- Test Watch Mode
  - `sip test watch`
  - Listens for changes in the project and re-runs tests when changes are detected

## Enhancements

- Clean up test usage output

# 0.2.4 | 3/8/2024

## Enhancements

- Update logging for test directory
- Better handle test directories that do not contain tests
- Speed up recursive search for test directories using [`glob`](https://pub.dev/packages/glob)

# 0.2.3+1 | 3/8/2024

## Fix

- Fix issue where `--no-optimize` ran each test file individually
- Fix stopwatch stamp formatting

# 0.2.2 | 3/8/2024

## Features

- Support `--no-optimize` flag in `sip test` command
- Add `--quiet` flag to silence output from `sip` commands
  - This will even silence the output from the commands being run
- Add `sip update` command
  - This will update the `sip_cli` package to the latest version

## Fix

# 0.2.1 | 3/7/2024

## Enhancements

- Print first line of command before executing when running scripts non-concurrently

# 0.2.0+1 | 3/7/2024

## Breaking Change

- Remove `--disable-concurrency` in the sip run command
  - in favor of `--no-concurrent` flag
  - This is in efforts to keep the flag names consistent
- Dropping use of `sip_console` in favor of `mason_logger`

## Features

- Update logging to be more consistent
- Add stopwatch to print statements
- Handle non-null non-string values in script definitions
  - ints & bools for example
  - Maps are not supported however

## Enhancements

- Use stream controller instead of `Future.wait` to run concurrent commands
  - Better control over commands
  - The ability to bail faster on failure
- Drop use of get_it for dependency injection
  - This was overkill 😅
- Ensure that script exists before running with `--never-exit` flag

# 0.1.2+1 | 3/6/2024

## Features

- Add `--never-exit` flag to `sip run` command
  - This will prevent the command from ever exiting, even if a command fails
  - This is useful for running a command that will be restarted by another process
    - For example, build_runner will stop running whenever the project's dependencies change
  - Please use with Caution! There is a second delay between each command run to prevent a runaway process
  - The process can be stopped by pressing `ctrl+c`

# 0.1.1 | 3/5/2024

## Enhancements

- Add very_good_analysis for linting
- Fix lint warnings
- Restructure Readme

# 0.1.0 | 3/4/2024

## Breaking Changes

- Remove `run-many` command
  - Use `run` with the `--concurrent` flag instead

## Features

- Add `--concurrent` flag to `run` command
  - This will run all scripts in parallel, regardless of the concurrent symbol defined within the script
- Add `--disable-concurrency` flag to `run` command
  - This will run all scripts in serial, regardless of the concurrent symbol defined within the script
- Add `sip test` command
  - Runs projects tests
    - Can recursively search for `test` directories
    - Can run concurrent tests
    - Passes most dart & flutter args to the `test` command

## Enhancements

- Speed up recursive search for sub-packages using [`glob`](https://pub.dev/packages/glob)
- Update README
  - To include new `test` command
  - To remove `run-many` command
  - Spelling and grammar updates
- Better handle dependency injection

## Fixes

- Fix issue where `--help` was not printing for the `run` command

# 0.0.17 | 2/13/2024

## Features

- Handle removing multiple concurrent symbols
- This could happen if a script was defined with the concurrent symbol, and then was referenced in another script also using a concurrent symbol

## Enhancements

- Update readme
- chore: Update internal version file

# 0.0.16 | 2/13/2024

## Features

- Add parsing support for chained short flags (`sip run my-script -abc`)

# 0.0.15 | 2/12/2024

## Fixes

- Fix issue `--list` on `sip run` was not working

# 0.0.14 | 2/12/2024

## Fixes

- Fix issue where - and \_ chars were being ignored in variables

# 0.0.13 | 2/12/2024

## Features

- Allow any args to be provided in any order without the requirement of `--` before any "extra" args.
  - Before: `sip run-many my-script -- --arg1 --arg2`
  - After : `sip run-many my-script --arg1 --arg2`

# 0.0.12 | 2/12/2024

## Fixes

- Fix issue where flags where not being passed to referenced scripts

# 0.0.11 | 2/12/2024

## Fixes

- Handle when a script reference is not found

# 0.0.10 | 2/12/2024

## Features

- Support referencing variables within `(variables)`

## Enhancements

- Add extra line before printing the list of commands
- Update README

# 0.0.9 | 2/10/2024

## Features

- Declare when a script with fail with the `(bail):` key in `scripts.yaml`

## Fixes

- Fix issue where all commands were printing after running a group of concurrent commands

# 0.0.8 | 2/9/2024

## Fixes

- Fix issue where bail was not being respected and failing commands were not stopping the script

# 0.0.6 | 2/9/2024

## Fixes

- Fix issue when parsing debug option

# 0.0.5 | 2/9/2024

## Features

- Support individual concurrent commands with `(+)`
- Support defining variables in `scripts.yaml` to use in commands
- Support defining private scripts in `scripts.yaml` to use as references
- Add alias for `run-many` command (`r-m`, `run-m`)

## Enhancements

- Tighten key pattern matching
- Improve color output when listing scripts, lighten color for scripts without a command definition

## Fixes

- Handle `null` scripts

# 0.0.4 | 2/9/2024

- Add version constraints to dependencies to support adding `sip_cli` to flutter projects

# 0.0.3 | 1/30/2024

- Initial Release
