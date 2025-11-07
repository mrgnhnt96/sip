# TODO

## Fix

- [ ] If terminal is not wide enough, test failures are not shown
- [ ] when providing a path to test, it should print out the paths that are being tested
  - [ ] Don't test files that don't end in `_test.dart`
- [ ] Get feedback from James as to why he keeps a separate document to keep track of his scripts. What would make sip easier to track scripts in?

## Features

- [ ] Adopt syntax like GHA
  - `{$key:to:command}` -> `${{ key.to.command }}`
- Clean up how env config is handled
  - Files are not being sourced
  - `env` commands are not being resolved properly
  - Resolving env vars is OVERLY complex
- Create VSCode extension
  - Support embedded bash language
    - Syntax highlighting
    - Completions
    - Linting
    - Formatting
- Add analytics (lukehog)
