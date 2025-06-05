# TODO

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
