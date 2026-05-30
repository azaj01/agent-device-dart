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

## Target apps

Two apps can be driven via `--app` (both reached purely through accessibility):

- `fixture` (default) — the Flutter fixture in `test_apps/agent_device_fixture_app`.
  Built and installed automatically.
- `test-app` — the Expo / React Native "Agent Device Tester" in
  `agent-device/examples/test-app` (`com.callstack.agentdevicelab`). It needs a
  heavyweight native RN build, so build it once out-of-band first:

  ```bash
  cd agent-device/examples/test-app
  pnpm install --ignore-workspace
  pnpm exec expo run:ios --configuration Release        # or: run:android
  ```

  The benchmark then verifies it is installed and drives it.

## Run

```bash
# Flutter fixture (default app)
dart run benchmark/bin/benchmark.dart --platform android --reps 5
dart run benchmark/bin/benchmark.dart --platform ios --udid <UDID> --reps 5

# Expo test-app (build it first, see above)
dart run benchmark/bin/benchmark.dart --platform ios --udid <UDID> --app test-app --reps 5
```

## Walkthrough coverage (accuracy axis)

Both apps exercise navigation, **text input** (`press` to focus + `type`, since
Dart's iOS backend has no coordinate `fill`), button sequences, toggles, and
observable state transitions — e.g. on the Flutter fixture: catalog search
filtering, urgent-only toggle, drill-in + mark-complete, and a `+3/-1`/reset
counter sequence; on the test-app: empty-submit validation errors → fill +
agree + submit → success, plus async diagnostics load.

## Output

Written to `benchmark/report/` (git-ignored):

- `REPORT-<platform>.md` — Markdown report with Unicode bar charts for latency,
  accuracy %, and feature coverage.
- `results-<platform>.json` — machine-readable results.

## Performance gotcha: rebuild the iOS runner

The biggest snapshot-latency factor we found was **not** the Dart code — it was a
**stale cached XCUITest runner build**. The CLI auto-builds the runner once into
`ios-runner/build/` and reuses it; it does not rebuild when the Swift source
changes. A stale runner drove `snapshot` at ~1600 ms; rebuilding from source
dropped it to ~440 ms (at parity with npm). The runner-internal snapshot work is
only ~170–230 ms — the rest is transport/process overhead.

If Dart snapshots look slow, rebuild the runner first:

```bash
make build-ios-runner            # booted simulator
make build-ios-runner UDID=<id>  # specific simulator
```

Measurement notes baked into this harness so the comparison stays honest:

- Latency is recorded **only for successful** invocations (a fast-failing command
  must never count as a fast call), with failures reported separately.
- `snapshot (isolated)` fires back-to-back after a warm-up (no interleaved
  commands invalidating the runner's accessibility cache); `snapshot (mixed)`
  reflects a realistic loop. Each row reports median, p95, σ, and n.

## Notes & caveats

- Each CLI runs its full suite back-to-back on the same device; the device is
  not interleaved per-command.
- The cold-open line measures session bootstrap + runner launch on a fresh
  state dir; the first-ever native runner *compile* is cached outside the state
  dir and is excluded.
- `find` has a genuinely different output contract between the two CLIs (Dart
  returns matched nodes; npm resolves to a tap coordinate), so accuracy uses
  `snapshot` as the cross-CLI primitive rather than `find`.
