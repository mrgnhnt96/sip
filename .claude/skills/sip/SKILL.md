---
name: sip
description: >-
  Work on the sip_cli codebase (commands, scripts.yaml parsing, scoped_deps
  providers, arg parsing, test reporting). Use when editing lib/src/commands,
  lib/src/domain, boolean_flags.dart, or the sip ai templates.
---

# sip

Read [AGENTS.md](../../../AGENTS.md) at the repo root for the full guide.

`sip_cli` is one Dart package publishing one executable. No codegen, no
mono-repo.

## Do

- Treat `dart test` as the reference; `sip test` is a parsing layer over it
- Add commands as `const` classes with `Future<ExitCode> run([List<String>])`,
  then register them in the `switch (args.path)` in `lib/sip_runner.dart` and
  in its `_usage`
- Take collaborators from `lib/src/deps/` (`fs`, `logger`, `args`, …); test
  with `testScoped` + `MemoryFileSystem`
- Add every new boolean flag to `booleanFlagNames` in
  `lib/src/domain/boolean_flags.dart`
- Update `lib/src/commands/ai/ai_templates.dart` when `scripts.yaml` semantics
  change
- Compile to a scratch path (`dart compile exe bin/sip.dart -o /tmp/sip_dev`)
  to try the CLI

## Don't

- Construct a `FileSystem` or `Logger` directly — it breaks provider overrides
- Return `ExitCode.usage` for a command that failed — that claims the CLI was
  invoked wrongly; `software` is the honest fallback
- Use `${{ a:b }}` in a `scripts.yaml` — only dots resolve
- Write `(bail):` with no value and expect bail; it parses as `false`
- Run `sip run install` casually — it overwrites the global sip install
