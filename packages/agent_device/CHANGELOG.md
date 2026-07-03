## 0.0.12

Ports the actionable slice of the upstream 0.18.0 → 0.18.2 gap (102 commits
triaged; the bulk — command-descriptor/PlatformPlugin refactors, daemon
internals, web/CDP, cloud providers — is out of scope for this mobile-only,
daemon-less port). See PORTED_COMMITS.md for the per-commit registry.

**Performance (iOS)**

- `open --relaunch` now works and is fast: the flag was previously accepted
  but ignored (and not exposed on the CLI). Simulators relaunch via a single
  `simctl launch --terminate-running-process` call, the XCUITest runner stays
  hot across the relaunch, and a 5s booted-memo removes repeat
  `simctl list devices -j` spawns — 0.54s wall on an iPhone 16e simulator,
  with exactly one device listing per invocation. Real devices keep the
  conservative runner teardown. (#1010, #1024)
- The cached runner build no longer rebuilds on package version bumps
  (content fingerprint only), and the runner app dropped its asset catalogs +
  compiles unit-test code out of runtime builds. Warm-cache runner relaunch:
  ~4.4s. (#900)

**Reliability (iOS)**

- Keyboard dismissal in the Swift runner no longer swipes the keyboard down
  or falls back to coordinate taps (both could trigger unintended UI
  actions); only safe native dismiss controls are used, with a clear
  `UNSUPPORTED_OPERATION` otherwise, and the dismiss-control search now spans
  all buttons, not just toolbars. (#957)
- Retained runner lifetime is bounded: a runner idle past 5 minutes (env
  `AGENT_DEVICE_IOS_RUNNER_IDLE_STOP_MS`, `0` disables) is stopped and
  relaunched at the next reconnect instead of being adopted. (#1025)
- The physical-device install timeout is a named constant keeping the 180s
  end-to-end budget (upstream splits 120s exec under a 180s daemon budget;
  daemon-less, the exec timeout is the whole budget). (#964)

**Observability**

- Opt-in exec diagnostics: `AGENT_DEVICE_EXEC_TRACE=1` (or `--debug`) records
  every external command spawn (duration, exit path, first 6 args) to the
  per-invocation diagnostics log. The CLI now opens a root diagnostics scope,
  which also un-deadens all pre-existing diagnostic events (screenshot
  fallbacks, fill verification) in CLI runs. (#1019)

**Triaged as not applicable**

Runner keepalive log tuning (#1017 — the keepalive timer was never ported),
prepare-deadline threading (#967 — no daemon request envelope), and the
daemon/web/cloud refactor campaign (~80 commits).

## 0.0.11

Closes the upstream 0.16.10 → 0.18.0 gap (179 commits triaged; the bulk —
Maestro, daemon internals, web/CDP, MCP, the 0.18.0 TypeScript refactors — is
out of scope for this mobile-only, daemon-less port).

**New Capabilities (ported from agent-device)**

- External / CI-signed iOS runner: `--ios-xctestrun-file`,
  `--ios-xctest-derived-data-path`, and `--ios-xctest-env-dir` use a prebuilt
  `.xctestrun` artifact and skip the build entirely. The artifact is trusted
  as-is, so a pre-signed device runner is reused without re-signing, and the
  env-injected copy can land in a writable scratch dir for read-only artifacts.
  (#806)
- `scroll --duration-ms`: honor a caller-provided scroll/swipe duration
  (0–10000 ms) on both platforms instead of a fixed default. (#866)

**Bug Fixes**

- Selector values now decode JSON-style escapes (`\n \t \r \uXXXX`, including
  surrogate pairs), not just escaped quotes. (#711)
- Block taps on covered/occluded snapshot targets via a geometric occlusion
  pass, wired into the iOS and Android snapshot pipelines. (#708)
- iOS runner command failures caused by a crashed target app are reclassified
  to `IOS_TARGET_APP_CRASH` with an actionable hint, read from the runner log
  tail. (#793, #797)
- Fail fast with an actionable hint when Developer Mode for Apple development
  tools is disabled (the runner would otherwise hang). (#792)
- Recover Android snapshots from system-only / empty UI-automator helper
  output. (#861)
- iOS `adjustSlider` corrected after the runner re-sync (the runner field is
  `sliderSteps`, distinct from the sequence command's `steps` array).

**Internal**

- iOS XCUITest runner Swift re-synced to upstream `4648051b`: sequence/scroll
  fused runner commands, structured snapshot capture plans, a private-AX
  snapshot fallback, shared flat-snapshot filtering, gesture stabilization, and
  synthesized-tap orientation rotation.
- The `DevToolsSecurity` developer-mode preflight is cached per process (one
  check per session instead of per cold runner launch); the covered-node
  occlusion search is memoized.

## 0.0.10

**Bug Fixes**

- Android snapshot now uses the bundled prebuilt helper APK directly. Its manifest carried a placeholder `"sha256": "local-build"` that failed validation, so the helper was silently discarded — falling back to an on-device auto-build (which fails in many environments) and then to a flaky `uiautomator dump`. Snapshots are now faster and far more reliable on Android, with no build toolchain required.
- `find type=<T>` now matches a node's type (e.g. `type=Button`). Previously `type` was not a recognized selector key, so the expression fell through to a literal-substring search and silently returned no matches; it now aliases `role`.

## 0.0.9

**Reliability / Bug Fixes**

- Concurrent commands sharing a session no longer fail with `FileSystemException: lock failed … errno 35`. The session-store advisory lock used the non-blocking `FileLock.exclusive`, so two overlapping `ad` invocations collided instead of waiting. Introduced a `FileMutex` (intra- and cross-process) that queues with bounded retry; concurrent commands now serialize cleanly.
- iOS commands without `--platform` no longer fail with a misleading `DEVICE_NOT_FOUND` that listed only Android devices. The CLI now auto-detects the backend across platforms, so `--serial <udid>` and `--device "<name>"` resolve regardless of platform. The resolved platform is remembered in the session so repeat commands skip re-enumeration and keep the fast path.
- `DEVICE_NOT_FOUND` now lists devices from every platform with platform labels and a clearer hint, instead of only the default backend's devices.
- iOS runner no longer "churns": `isAlive` tolerates a busy single-threaded runner (longer probe timeout + retries) instead of false-negatively declaring it dead and relaunching. Runner (re)launch is serialized per device with a cross-process lock and a double-check, so concurrent invocations don't each spawn their own `xcodebuild`.
- iOS runner commands serialize per device on that same lock, so overlapping commands queue rather than colliding on the single-command-at-a-time runner.

**Internal**

- New `FileMutex` lock primitive (`utils/file_mutex.dart`), used by the session store and the iOS runner launch/command paths.
- `CommandSessionRecord` gained a `devicePlatform` field (remembered alongside `deviceSerial`).
- `version.dart` is regenerated from `pubspec.yaml` as part of `make compile`, so the embedded `ad --version` can no longer drift from the published version.

## 0.0.8

**New Capabilities (ported from agent-device)**

- iOS transform gesture support and full `gesture` command coverage — `pan` / `pinch` / `rotate` / `fling` / `transform` driven through real multi-finger XCUITest synthesis
- iOS repro-evidence capabilities (#573)
- Precise location settings, with `setSetting` wired through the full stack (iOS location + Android) (#491)
- Auto-reverse `adb` localhost port forwards when opening URLs on Android
- Platform alert handling (`alert` accept/dismiss/text)
- Scroll-to-edge support and iOS `scroll` support
- Bundled pre-built Android multitouch helper APK (no on-device build needed)

**Performance**

- iOS: rebuild the XCUITest runner only when its source actually changes, using a content-fingerprint staleness cache (`runner_build_cache.dart`). Mirrors upstream's distribution staleness detection and eliminates the stale-build slowdown that made `snapshot` ~4× slower; restores parity with upstream.
- Skip device enumeration when both `--serial` and `--platform` are pinned (~300ms faster per command on Android)
- Direct iOS selector tap/fill optimization and faster hot iOS taps
- Cache app resolution

**Bug Fixes**

- CLI: accept negative-number positionals (e.g. `gesture pan` offsets) instead of misparsing them as short flags; keep `--json` stdout clean of progress/info lines (now routed to stderr)
- Android: clarify gesture transform behavior (#584); improve snapshot fidelity (#580); recover from app-owned ANRs; preserve scoped snapshot refs (#456); `finishSafely` in the snapshot-helper APK
- iOS: simplify interactive snapshots; compact unchanged-snapshot output
- Report blockers on `wait` timeout

**Tooling**

- Added a head-to-head benchmark harness (`benchmark/`) that drives the same app on the same iOS simulator / Android emulator through both this port and the upstream npm `agent-device`, measuring latency, command-level accuracy, and feature parity.

## 0.0.7

**Bug Fixes**

- reuse existing runner build products before auto-building
- add missing focused/selected params to Swift SnapshotNode calls
- increase default startup timeout for iOS runner client
- increase timeout for scenario detail flow test to 150 seconds

**Ported from agent-device:**

Bug Fix

- iOS runner build path (`runner_client.dart`): Fixed `_ensureXctestrun` to return the correct `productsDir` after auto-build. Previously it built to `projectRoot/build/Build/Products` but then looked for the xctestrun in the original CWD-relative path. Now it returns both the template and the resolved products dir as a record.

Upstream Ports (5 areas, 12 commits)

Swift Runner (4 commits merged)

- Quiescence skip for RN/Flutter apps (`performWithQuiescenceSkippedIfSupported`)
- XCTest attachment bloat prevention (`.xctestplan` with `keepNever`)
- Replay performance: direct selector tap, fast foreground guard, keyboard-avoiding drag, extracted `executeTypeCommand`
- New `RunnerTests+TvRemote.swift` split-out
- All slider additions preserved

Touch Target Resolution Policy (new `interaction_targeting.dart`)

- SEMANTIC_TOUCH_ROLE_FRAGMENTS list prevents tab buttons from resolving to overly broad parent containers
- Integrated into `AgentDevice.resolveTarget()` with 10 unit tests

Android Snapshot Presentation (new `android_helper_snapshot_presentation.dart`)

- Collapses zero-area nodes, duplicate rows, bottom-nav noise
- 547 lines ported with 8 unit tests

Small Features

- screenshot --no-stabilize flag for faster capture loops
- apps command defaults to user-installed, --all for system apps
- Removed ensure-simulator command (upstream dropped it)

Android Stability

- Input ownership tracking (new `input_ownership.dart`) with IME detection
- Fill verification with settled state + stricter matching
- Busy RN snapshot detection with enriched timeout errors

## 0.0.6

**Features**

- add slider increment and decrement support for ios
- **ios**: slider control with vertical + horizontal support - experimental
- **android**: slider support via adb input swipe - experimental

**Refactor**

- deduplicate native assets via symlinks

## 0.0.5

**Features**

- add update command

## 0.0.4

**Features**

- add Android frame health perf metrics (port of 0c7e48d7)
- add iOS frame perf sampling (port of cff8bd81)

## 0.0.3

**Features**

- sort devices by boot status in \_listAllPlatforms method

**Bug Fixes**

- handle iOS keyboard Done dismiss controls (port of bbb1d363)
- set application debuggable to false in AndroidManifest.xml
- Cache Android helper installs (port of 3fee9d6d)

## 0.0.2

**Features**

- **find**: enhance find command to support selector DSL, locator tokens, and substring queries

**Bug Fixes**

- implement retry logic for Android UiAutomation conflicts

**Refactor**

- migrate to cli_logger

## 0.0.1 (preview)

Initial Dart port of `agent-device` (TS upstream). There are some changes to the upstream API to adjust it to the Dart workflow. The main differences are:

- no device session
- slight differences in the API
- way of bundling the native executables with the package
