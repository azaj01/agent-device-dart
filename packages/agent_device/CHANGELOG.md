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
