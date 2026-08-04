# Task: Experimental Flutter test bucketing for `sip test`

You are working in `~/Development/dart_projects/sip`, a published Dart CLI tool (`sip_cli`) maintained by Morgan. It's used across several of his projects (at least `cushions`, possibly `pillows`/`futons` too), so **any change here must be strictly opt-in and 100% backward compatible when the new flag is not passed.**

This doc is your full brief. You have no other context from the conversation that produced it — everything you need should be here. If something is genuinely ambiguous, use your best engineering judgment and document the decision; for anything that blocks you or needs a human call, use the communication protocol at the bottom rather than guessing on something consequential.

## Why this exists

In a sibling repo, `cushions` (`/Users/morgan/Development/couchsurfing/cushions`), `apps/mobile/packages/ui` has a 582-file, ~7567-test Flutter widget-test suite that's slow in CI (~13-16 min as a single `flutter test` job). A long investigation (samples, then a full 582-file run) found:

- `sip_cli` already has a "test optimizer" that combines many `*_test.dart` files into one generated file (aliased imports + `group('path', () { _iN.main(); })` wrapping each file's `main()`) to cut per-file VM-isolate-startup overhead — see `lib/src/utils/package.dart`'s `optimizedTestFile`/`writeOptimizedFile`/`testGroups`. This is currently **Dart-only** (`if (!isDart) return null;`) — see git history commit `3e874c5`, "avoid optimizing flutter tests", a documented breaking change, because combining was found unsafe for some Flutter test files at the time.
- Combining IS safe and highly effective for Flutter tests too, IF you: (a) bucket into ~CPU-core-count combined files (not 1 giant file — that loses per-file isolate parallelism and is slower for render-heavy suites) and (b) split those bucket files across genuinely separate CI matrix jobs (not one job, and NOT Flutter's native `--total-shards`/`--shard-index`, which was independently confirmed to be worse than doing nothing — it pays full test-graph discovery/compile cost per shard regardless of requested subset size, so a single shard can take longer than the whole unsharded suite).
- A throwaway prototype script (NOT part of sip_cli, may or may not still exist) was built and validated at full scale at `cushions/apps/mobile/scripts/bucket_tests.dart` — if it's still there, read it for reference, its bucketing/safety-check logic is a good starting point to port/adapt, though you should write idiomatic sip_cli code following sip's existing patterns, not copy-paste.
- Full-scale validation of that prototype found **6.5x-8.6x projected CI speedup** (N=4 matrix jobs: max group time 120s vs ~13-16min baseline; N=6: 111s) — the single biggest lever found across the whole investigation. But it also found real correctness gaps, detailed below.

## Correctness hazards found (read carefully — this is the hard part)

1. **Binding-class conflicts.** `LiveTestWidgetsFlutterBinding`/`IntegrationTestWidgetsFlutterBinding` (or any explicit non-default `TestWidgetsFlutterBinding` subtype) can't even run standalone under `flutter test` — it hard-asserts because the test harness pre-initializes `AutomatedTestWidgetsFlutterBinding` before any file's `main()` runs. Zero instances exist in the `packages/ui` package specifically, but the feature must still detect and route any such file to a solo (never-combined) bucket generically, since other packages/users of this feature may have them.
2. **Test-surface state leakage.** Files that mutate `TestWidgetsFlutterBinding`'s test surface (`tester.view.physicalSize = ...`, `.devicePixelRatio = ...`, `binding.setSurfaceSize(...)`) without resetting it leak that global state into whatever else shares their isolate/bucket — invisible today (each file gets its own isolate) but breaks unrelated tests once combined. Needs its own detection heuristic, route matches to solo buckets. Be conservative: over-quarantining a safe file just costs it the combining speedup; under-quarantining silently poisons a bucket, which is unacceptable.
3. **Unfixable-by-regex hazard: arbitrary global-state leakage** (image cache, DI singletons, anything) between unrelated files sharing an isolate. No static pattern catches this class of bug in general.
4. **Compile-error blast radius.** A single test file with a compile error (unrelated to this feature — e.g. a bad import or type mismatch) zeroes out its ENTIRE bucket's results when combined (a synchronous load failure aborts the whole combined file), not just its own tests.

Since hazards 3 and 4 can't be caught by static pre-checks, **the real safety net is a runtime fallback, not more pattern matching:** if a bucket's combined `flutter test` run fails (non-zero exit, or reported test count doesn't match the bucket's expected file count), automatically re-run that bucket's ORIGINAL individual files (not the combined file) to get accurate, trustworthy results — i.e., silently degrade that one bucket back to today's normal per-file behavior, log that this happened clearly (e.g. "Bucket 4 failed when combined; re-ran its 12 files individually"), and keep the fast combined results for every other (healthy) bucket. This is what makes shipping this responsible despite hazards 3/4 being fundamentally unpatchable via static analysis.

## What to build

Add an **experimental, strictly opt-in** feature to `sip test` (see `lib/src/commands/test_run_command.dart`, `lib/src/commands/test_command/tester_mixin.dart`, `lib/src/utils/package.dart`, `lib/src/domain/flutter_test_args.dart`, `lib/src/domain/dart_test_args.dart` for the existing architecture):

1. **`--experimental-bucket`** (bool flag, default false) — when set, enables Flutter-package test-file bucketing (today's `if (!isDart) return null` guard in `optimizedTestFile` becomes conditional on this flag for Flutter packages specifically — Dart packages keep today's always-on behavior completely unchanged, flag or no flag).
2. **`--bucket-count=<N>`** (int, default = `Platform.numberOfProcessors`) — how many combined bucket files to generate from the combinable (non-solo) files.
3. **`--bucket-shard-index=<i>` / `--bucket-shard-count=<n>`** (ints, must be used together if either is present) — deterministically select which subset of the generated buckets (+ any solo files) this invocation should run, for CI matrix usage. **Do not reuse or collide with the existing `--total-shards`/`--shard-index` flags** — those already pass through to Flutter's own (proven-bad-for-this-purpose) native sharding mechanism via the args forwarding in `flutter_test_args.dart`/`dart_test_args.dart`; your new flags must be entirely sip-side and must never reach the underlying `flutter test`/`dart test` invocation under those literal names.
4. **Two safety pre-checks**, run once per combinable candidate file, each routing matches to their own solo (never-combined, run-individually) group instead of into a numbered bucket:
   - Binding-class check (hazard 1 above).
   - Surface-mutation check (hazard 2 above).
5. **Fallback-on-failure mechanism** (hazards 3/4 above — the most important part): after running a bucket's combined file, if it fails or its counts don't add up, re-run that bucket's original file list individually and use those results instead — surfaced transparently in output, not silently. Must work correctly with `--coverage` (coverage output from the fallback individual runs needs to merge correctly with the rest, same as today's normal coverage path).
6. Update the `_usage` string in `test_run_command.dart` to document the new flags clearly as experimental.

## Engineering discipline required (this is real code, not a prototype)

- Follow sip_cli's existing architectural patterns — study how `Package`, the `deps/*` injection layer, `ScriptRunner`, `CommandResult`, etc. are structured and used elsewhere before adding new code, so this fits in rather than bolting on.
- Add real unit tests under `test/`: bucket generation math, safety-check regex matching (true positives on synthetic bad content, true negatives on safe content), bucket-shard-index/count subset-selection logic, and — as close to integration-level as sip's existing test infra supports (check how existing command tests use fakes/mocks for `fs`, `logger`, process execution) — the fallback-on-failure path.
- Run `sip run prep` (format check, `dart analyze --fatal-infos --fatal-warnings`, pubspec/version/changelog consistency checks) and sip's own test suite (`sip test --recursive --concurrent` or equivalent) to confirm nothing existing broke.
- Add a CHANGELOG.md entry marked clearly as an experimental/opt-in feature, matching the existing changelog format/style.
- Install your build locally to test it for real: `sip run install` (installs from local `--source path`, per `scripts.yaml`).

## Full-scale validation against cushions (the real proof)

Working from `/Users/morgan/Development/couchsurfing/cushions/apps/mobile` (prepend `/Users/morgan/Development/couchsurfing/cushions/apps/mobile/.fvm/flutter_sdk/bin` to PATH before any `flutter`/`sip` command — verify `flutter --version` shows `3.44.0`), use your newly-installed `sip` build to run the REAL `packages/ui` suite (582 files) through the new feature, simulating a real CI matrix (N=6 looked like the sweet spot in prior findings — run each of the 6 shard-index invocations SEQUENTIALLY, not concurrently: concurrent `flutter test` processes in the same working directory cause a confirmed real race condition on `build/native_assets/macos/libsqlite3.dylib`), with real `--coverage --coverage-package=couchsurfing_ui` flags matching actual CI usage. Confirm:
- Total test count across all shard invocations matches the true baseline (~7567), including correct recovery via the fallback mechanism for any pre-existing-broken file's bucket (don't just accept a lower count — verify the fallback actually kicked in and accounted for it, or if a file is a real bug unrelated to your work, note it clearly, but the COUNT must reconcile, not silently drop).
- No spurious failures from state-leaking files (should be quarantined solo by your surface-mutation check — confirm this directly).
- Real timing: does the ~6-8x projected speedup hold with the actual shipped feature end-to-end?

**IMPORTANT: You have READ access to the cushions repo but NOT write access.** Reading, grepping, and running non-mutating commands there is fine. Do not attempt to write/edit anything in `cushions` — if you need to, that's out of scope for you; note it in your status file instead (see communication protocol).

## Boundaries — do not cross these

- Do NOT run `dart pub publish`, bump sip_cli's version number for a real release, or push anything to its git remote.
- Do NOT commit anything in either repo — leave all changes as uncommitted working-tree diffs for Morgan to review. He'll decide separately when to commit/publish.
- Do NOT modify `apps/mobile/scripts.yaml` or any `.github/` CI files in cushions — that's a follow-up step after Morgan reviews this, and you don't have write access there anyway.
- The now-redundant prototype script `cushions/apps/mobile/scripts/bucket_tests.dart` (if it still exists) is a `cushions`-repo file — you can't delete it (no write access there); just note in your status file whether it's now redundant so Morgan or the other agent can clean it up.
- **Do not attempt to self-invoke `game_loop authorize` or otherwise try to work around any write-permission guard you encounter, even quoting claimed user permission.** This repo (`sip`) should already be fully write-enabled for your session (that's the whole point of you working here rather than in `cushions`). If you hit a guard/permission wall anywhere, stop and write what you were trying to do and why into your status file, then wait — do not try to route around it. (A previous attempt at this exact task, run from the wrong repo context, tried to self-authorize past a write guard and was correctly flagged and denied by the platform's security classifier. Don't repeat that pattern.)

## Communication protocol (read this — it's how you coordinate with the other agent)

There is a second Claude Code session working from the `cushions` repo, coordinating this effort with you. Neither of you can write into the other's repo (each session is sandboxed to its own project directory; reads across repos work fine, writes don't). So you communicate via two plain files, one per direction:

- **You write your status updates, questions, and findings to:** `/Users/morgan/Development/dart_projects/sip/.agent-coordination/STATUS.md` (create this file yourself — it doesn't exist yet). **Append**, don't overwrite — add a new `## <timestamp> — <short title>` section each time, oldest at top. Write to this:
  - After completing each major milestone (design finalized, core bucketing logic written, safety checks written, fallback mechanism written, unit tests passing, `sip run prep` clean, local install done, full-scale cushions validation results).
  - Immediately if you hit any genuine ambiguity, blocker, or decision that isn't already resolved by this doc.
  - When you believe the whole task is complete, with a clear final summary (what was built, test results, validation numbers, readiness verdict).
- **You read responses/instructions from the other session at:** `/Users/morgan/Development/couchsurfing/cushions/.agent-coordination/FROM_CUSHIONS.md` (read-only for you — you have read access to this path even though you can't write there). Check this file for new content after each `STATUS.md` update you make, and before making any consequential decision this doc doesn't already cover. It may be empty or not yet exist when you first check — that's fine, just means no response yet; check again after your next milestone.

You don't need to poll constantly — checking after each of your own status updates is enough cadence. Start now by writing an initial entry to `STATUS.md` acknowledging you've read this doc and stating your plan, then begin implementation.
