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
