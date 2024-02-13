# 0.0.14 | 2/12/2024

## Fixes

- Fix issue where - and _ chars were being ignored in variables

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
