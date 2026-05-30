# agent-device benchmark

Head-to-head benchmark of the **Dart port** (`dist/agent-device`) against the
**upstream npm CLI** (`agent-device/bin/agent-device.mjs`), driving the *same*
Flutter fixture app on the *same* booted simulator/emulator.

It works because both CLIs automate apps purely through OS-level accessibility
(the same Swift XCUITest runner on iOS, the same Android snapshot-helper APK),
so they are app-agnostic and can be compared like-for-like. The harness only
times subprocess calls to each binary and parses their shared `--json`
envelope — it is a neutral referee that favours neither implementation.

## Three axes

- **Performance** — steady-state latency (median/p95 over `--reps` repetitions)
  for `snapshot`, `screenshot`, `perf`, `appstate`, `press`, plus process
  startup (`--version`) and a one-off cold `open`.
- **Accuracy** — a deterministic walkthrough of all six fixture screens that
  asserts expected accessibility identifiers and state transitions against the
  oracle in `lib/oracle.dart` (mirrors the fixture app's `fixture_ids.dart`).
  Interactions use coordinate taps derived from each CLI's own snapshot, so the
  command stream is identical on both sides.
- **Feature set** — a command-parity matrix probed by invoking
  `<cli> <command> --help` on each built binary.

## Prerequisites

1. `make compile` — builds `dist/agent-device`.
2. npm CLI built: `cd agent-device && pnpm install && pnpm build` (ships a
   prebuilt `dist/` already).
3. `dart pub get` at the repo root (workspace resolves this package).
4. A booted device:
   - Android: an emulator/device visible to `adb devices`.
   - iOS: a booted simulator (`xcrun simctl list devices booted`).
5. `node`, `flutter`, `adb`/`xcrun` on `PATH`.

The fixture app is built and installed automatically if not already present.

## Run

```bash
# Android (auto-detects a single emulator, or pass --serial)
dart run benchmark/bin/benchmark.dart --platform android --reps 5

# iOS (auto-detects a single booted sim, or pass --udid)
dart run benchmark/bin/benchmark.dart --platform ios --udid <UDID> --reps 5
```

## Output

Written to `benchmark/report/` (git-ignored):

- `REPORT-<platform>.md` — Markdown report with Unicode bar charts for latency,
  accuracy %, and feature coverage.
- `results-<platform>.json` — machine-readable results.

## Notes & caveats

- Each CLI runs its full suite back-to-back on the same device; the device is
  not interleaved per-command.
- The cold-open line measures session bootstrap + runner launch on a fresh
  state dir; the first-ever native runner *compile* is cached outside the state
  dir and is excluded.
- `find` has a genuinely different output contract between the two CLIs (Dart
  returns matched nodes; npm resolves to a tap coordinate), so accuracy uses
  `snapshot` as the cross-CLI primitive rather than `find`.
