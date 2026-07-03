# Handoff — agent-device-dart benchmark & gesture verification

_Generated 2026-05-31. Working dir: `/Users/dominik/Projects/tmp/agent-device-dart` (branch `main`)._

## What this project is

A Dart port of the npm `agent-device` CLI (iOS/Android UI-automation for AI agents).
The active workstream is a **head-to-head benchmark** of the Dart port vs the upstream
npm CLI, driving the *same* app on the *same* simulator/emulator through both binaries.

- npm CLI: `node agent-device/bin/agent-device.mjs <cmd>` (upstream, in the `agent-device/` submodule)
- Dart CLI: `dist/agent-device <cmd>` (built via `make compile`)

## Reference artifacts (do not re-summarize — read these)

- **Plan**: `/Users/dominik/.claude/plans/optimized-meandering-yeti.md` — full benchmark design (3 axes: performance, accuracy, feature set).
- **Benchmark package**: `benchmark/` (tracked). Key files: `lib/cli_target.dart`, `lib/driver.dart`, `lib/apps.dart`, `lib/scenarios.dart`, `lib/snapshot.dart`, `lib/report.dart`, `bin/benchmark.dart`. README in `benchmark/README.md`.
- **Generated reports** (gitignored output): `benchmark/report/REPORT-{flutter-fixture-ios,flutter-fixture-android,expo-test-app-ios}.md` + matching `results-*.json` + `screenshots-*/`.
- **Runner staleness cache** (ported from npm): `packages/agent_device/lib/src/platforms/ios/runner_build_cache.dart` + test `…/test/platforms/ios/runner_build_cache_test.dart`.
- **Relevant commits**: `92fb78c` (richer benchmark flows), `a6cee41` (rebuild XCUITest runner on source change), `8ebefc4` (CI workspace fix), `85b4254` (CLI negative-positional + --json stdout purity).

## Most recent task — gesture verification (DONE, conclusive)

The user challenged a claim slated for a maintainer message: *"npm `gesture pan/rotate/fling`
no-op on React Native gesture-handler, while Dart's register."* Question was **"are we sure
gestures don't work?"**

**Verified YES — the claim stands.** Reproduced airtight on iOS sim
`9046550C-D9D6-4832-AFB6-8C0D73D90285`, app `com.callstack.agentdevicelab`, same coordinate,
same fresh baseline:

1. Full reset (reboot sim, kill npm daemon) → npm snapshot healthy (74 nodes).
2. npm relaunch app → fresh baseline reads `x 0 / fling 0 / all "no"` — **proves npm's
   snapshot is fresh, not a stale cache** (cache would have shown a prior value).
3. **npm** pan ×2 + rotate on that baseline → stays `x 0`, `"pan changed no"` (no-op).
4. **Dart** pan on the *same* baseline → `x 72`, `"pan changed yes"`; rotate → `rotate 30`,
   `"rotate changed yes"` (registers).

**Critical gotcha discovered**: the **first synthesized gesture after `open` no-ops on a cold
runner** until RN's gesture-handler warms up. This is what made an earlier isolated test look
like Dart failed too. Any future gesture test MUST warm up (a `press` or throwaway gesture)
before asserting — and give npm the *same* warm-up so the comparison is fair. npm still no-ops
after warm-up; Dart registers.

Gesture command arg forms (both CLIs): `gesture pan <x> <y> <dx> <dy>`,
`gesture rotate <degrees> <x> <y>`, `gesture fling <dir> <x> <y> <distance>`.
Status nodes on the test-app Home gesture lab: `gesture-change-status`,
`gesture-transform-status`, `gesture-fling-status`, target `gesture-target`.

## Open / next steps

1. **Maintainer message** — was drafted in conversation only; **not saved to any file**. It
   thanks the maintainer for `examples/test-app` and lists findings. The gesture finding is now
   verified. Recommended next action: fold the exact repro (reset pad → npm pan stays `x 0` →
   Dart pan moves to `x 72` on same baseline) into the message for credibility, then save it to
   a file / deliver it. User had asked to "create a kind message to agent-device maintainer with
   highlights."
2. **Uncommitted loose ends** (intentional, do not revert without asking):
   - `.gitignore` (M) — user removed the `benchmark/report/` ignore on purpose.
   - `agent-device` submodule (m) — `examples/test-app/app.json` has an added
     `"scheme": "agentdevicelab"` to fix a standalone-build crash. Lives inside the submodule.
3. **Other divergences surfaced by the benchmark** (pro-npm gaps in Dart): `diff`, `alert`, and
   text-grammar `wait` commands; npm's long-lived daemon is faster per-command. Pro-Dart:
   gesture+scroll synthesis drives RN where npm no-ops.

## Constraints / conventions (from user memory — follow exactly)

- **Git commits**: plain `git commit`, **no** `-c user.email/user.name` overrides.
- **No time estimates**: never put hour/day estimates in status or plan text.
- Commit/push **only when asked**; branch first if on the default branch. End commit messages
  with `Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>`.
- Sending anything to an external party (the maintainer message) is outward-facing — confirm
  with the user before delivering.

## Environment quick-reference

- iOS sim UDID: `9046550C-D9D6-4832-AFB6-8C0D73D90285`; test-app bundle `com.callstack.agentdevicelab`;
  Flutter fixture `com.example.agentDeviceFixtureApp`.
- Android: serial `emulator-5554`; Flutter fixture `com.example.agent_device_fixture_app`.
- Build Dart binary: `make compile` → `dist/agent-device`. Rebuild iOS runner: `make build-ios-runner`.
- If npm/iOS runner gets into a bad state (shallow ~12-node snapshots, daemon timeouts): full
  reset = `pkill -9 -f test-without-building; pkill -9 -f AgentDeviceRunner;
  pkill -f internal/daemon.js; rm -f ~/.agent-device/daemon.{json,lock}; simctl shutdown+boot`.

## Suggested skills for the next session

- `commit-porter` — if porting further upstream commits (e.g. the missing `diff`/`alert`/`wait`
  commands) from the `agent-device` submodule to Dart.
- `feature-port-verifier` — to independently verify any ported feature against upstream.
- `agent-device-troubleshooter` — for emulator/simulator/runner/daemon environment issues
  (exactly the shallow-snapshot / daemon-timeout class of problem hit during gesture verification).

---

# Handoff addendum — upstream port batch (paused 2026-07-02)

## Workstream

Porting upstream commits `4648051b..a4b35c42` (v0.18.0→0.18.2 era) selected in this session's
assessment. Registry: `PORTED_COMMITS.md` (rows appended at the bottom, from `305594f6b` on).
All changes are UNCOMMITTED in the working tree, on top of the pre-existing uncommitted
benchmark/gitignore changes.

## Done (ported + registry rows written)

1. `305594f6b` keyboard dismissal safety — Swift runner sync; `make build-ios-runner` green.
2. `657442260` keepalive noise — reassessed **n/a** (Dart runner never ported the keepalive
   timer; dead constant removed after porter added it).
3. `9dc07cc56` runner cache across version bumps — Dart `runner_build_cache.dart` no longer
   keys on packageVersion (+2 tests); Swift asset catalogs deleted; unit-test code gated
   behind `#if AGENT_DEVICE_RUNNER_UNIT_TESTS` (no Dart build passes the flag → tests
   compiled out of runtime builds, same as upstream). Runner build verified.
4. `903a35624` install timeout — named constant `iosDeviceInstallTimeoutMs`; kept **180s**
   (not upstream's 120s) because daemon-less the exec timeout is the whole end-to-end budget
   (upstream: 120s platform under 180s daemon-client `INSTALL_REQUEST_TIMEOUT_MS`).
5. `996d93e97` relaunch perf — discovered `BackendOpenOptions.relaunch` was previously
   accepted-but-ignored; real close-then-open implemented in `IosBackend.openApp` (runner kept
   hot on simulators; conservative teardown on device), 5s booted-memo in `devices.dart`
   (+8 tests), and CLI `open` gained the `--relaunch` flag (was unreachable before).
6. `6dc0aa550` single-call relaunch — `simctl launch --terminate-running-process` fast path
   (+7 launch-args tests). URL opens don't exist in the iOS Dart backend, so no exclusion
   needed today — see CAUTION in the registry row.

State: `dart analyze` clean (107 pre-existing infos), `dart test` 951/951 green,
`make build-ios-runner` green. NOT yet live-validated.

## Remaining (task list #7–#10)

7. Port `60d1bd176` — respect prepare timeout for runner health checks (#967).
8. Port `505e2af12` — opt-in exec command diagnostics (#1019) → `utils/exec.dart`.
9. Port `b67053e97` — runner idle stop (#1025) — ADAPT to daemon-less: persist lastUsedAt in
   the on-disk runner record (`ios_backend.dart` `_readRunnerRecord`/`_writeRunnerRecord`),
   enforce on reconnect; porter may conclude skipped if it doesn't hold together.
10. Live validation on iOS simulator + Android emulator: `make compile`, then on sim —
    keyboard dismiss (verify UNSUPPORTED_OPERATION message + no swipeDown side effects),
    `open --relaunch` timing (expect big drop; runner must survive), runner rebuild triggers
    once after Swift changes then caches (version bump must NOT invalidate), snapshot/press
    sanity; on emulator — regression only (open/snapshot/press; these ports are iOS-only).
    One iOS command at a time (see memory: concurrency causes misleading DEVICE_NOT_FOUND).

## Also assessed this session (registry NOT yet updated for these)

The other ~80 commits in the gap are n/a (daemon/TS refactor phases, web/CDP/cloud, docs,
version bumps). Deferred-with-interest, not yet decided: doctor command (#883, big),
agent-cost/--level Phase 4 series (native reimplementation, feature-set decision),
replay test reporters (#936/#959/#998). Registry rows for the n/a bulk still need appending.

## Porting conventions used

commit-porter subagents, one commit each, port semantics not patches, no git commits,
registry row per commit. Root `ios-runner/AgentDeviceRunner` is a SYMLINK into
`packages/agent_device/lib/src/native/ios-runner/` — edits land there.

## Validation results (2026-07-03, task #10 — DONE)

All 9 assessments/ports complete; live-validated on iPhone 16e sim `9046550C…` + `emulator-5554`.

- Unit gates: `dart analyze` clean (107 pre-existing infos), `dart test` 966/966, `make build-ios-runner` + `make compile` green.
- #957 keyboard dismissal: runner (fresh build, new code) refuses a field without safe controls with the exact new message; form untouched (no swipeDown side effects). NOTE: Dart iOS backend has no `setKeyboard` wiring (`keyboard dismiss` → UNSUPPORTED on iOS at CLI level; bbb1d363 only ported the Swift side) — validated via direct runner HTTP `keyboardDismiss`. Possible future work: wire CLI keyboard → runner.
- #1010+#1024 relaunch: `open --relaunch` 0.54s wall, exactly one `simctl list devices -j` and one `simctl launch --terminate-running-process`, runner record (port/PID) unchanged across relaunch.
- #900 cache: full runner relaunch with warm cache = 4.4s (no xcodebuild rebuild); the one rebuild after the Swift edits took ~30s as expected.
- #1025 idle stop: `AGENT_DEVICE_IOS_RUNNER_IDLE_STOP_MS=1000` + 2.5s gap → old runner killed (port probe dead), fresh launch; default bound adopts instantly (0.39s snapshot) and touches `lastSuccessfulRunnerResponseAtMs` in the record.
- #1019 exec trace: NDJSON written under `~/.agent-device/logs/default/<UTC day>/` (careful: UTC day dir), events carry durationMs + argsPrefix (≤6) + omittedArgCount.
- Android regression: open/snapshot/press/back/Form-Lab all fine on emulator-5554.

Review fixes made during validation (beyond the porter agents' work):
1. `run_cli.dart`: root diagnostics scope + flush — CLI previously never opened a scope, so ALL emitDiagnostic sites were dead in CLI runs.
2. `ios_backend.dart` `_resolveKind`: consume the booted memo (was seeded but never read).
3. `ios_backend.dart` `_touchRunnerRecord`: persist last-use on adoption — without it the idle stop could never fire across invocations.
4. CLI `open --relaunch` flag exposure + `iosDeviceInstallTimeoutMs` kept at 180s (see registry rows).
