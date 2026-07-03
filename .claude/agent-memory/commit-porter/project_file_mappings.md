---
name: File mappings TS → Dart
description: Key upstream TypeScript file paths and their Dart equivalents in the port
type: project
---

Key file mappings between `agent-device/src/` and `packages/agent_device/lib/src/`:

| TS path | Dart path |
|---|---|
| `utils/scroll-edge-state.ts` | `utils/scroll_edge_state.dart` |
| `utils/snapshot.ts` | `snapshot/snapshot.dart` |
| `utils/snapshot-tree.ts` | `snapshot/tree.dart` |
| `utils/snapshot-visibility.ts` | `snapshot/visibility.dart` |
| `utils/mobile-snapshot-semantics.ts` | `utils/mobile_snapshot_semantics.dart` |
| `utils/scrollable.ts` | `utils/scrollable.dart` |
| `utils/scroll-indicator.ts` | **not yet ported** — minimal `inferVerticalScrollIndicatorDirections` inlined into `utils/mobile_snapshot_semantics.dart` |
| `platforms/android/snapshot.ts` | `platforms/android/snapshot.dart` |
| `platforms/android/scroll-hints.ts` | `platforms/android/scroll_hints.dart` |
| `platforms/android/ui-hierarchy.ts` | `platforms/android/ui_hierarchy.dart` |
| `platforms/android/adb.ts` | `platforms/android/adb.dart` |

TS naming conventions → Dart:
- `camelCase.ts` → `snake_case.dart`
- TypeScript class fields are `final` by default in Dart port, except where mutation is needed (see RawSnapshotNode)
- `Map<number, T>` → `Map<int, T>`
- TS `undefined` optional fields → Dart nullable `?`

| `platforms/android/snapshot-content-recovery.ts` | `platforms/android/snapshot_content_recovery.dart` |
| `platforms/android/snapshot-helper-types.ts` | `platforms/android/snapshot_helper_types.dart` |
| `platforms/android/snapshot-helper-capture.ts` | `platforms/android/snapshot_helper_capture.dart` |
| `platforms/android/snapshot-helper-install.ts` | `platforms/android/snapshot_helper_install.dart` |
| `platforms/android/snapshot-helper-artifact.ts` | `platforms/android/snapshot_helper_artifact.dart` (simplified — no remote fetch) |
| `platforms/android/snapshot-helper.ts` | barrel — all symbols accessible from the individual files above |
| `platforms/android/snapshot-types.ts` | `platforms/android/snapshot_types.dart` |
| `platforms/android/perf-frame-analysis.ts` | `platforms/android/perf_frame_analysis.dart` |
| `platforms/android/perf-frame-parser.ts` | `platforms/android/perf_frame_parser.dart` |
| `platforms/android/perf-frame.ts` | `platforms/android/perf_frame.dart` |
| `platforms/ios/perf-xml.ts` | `platforms/ios/perf_xml.dart` |
| `platforms/ios/perf-frame.ts` | `platforms/ios/perf_frame.dart` |
| `platforms/ios/perf.ts` | `platforms/ios/perf.dart` |
| `platforms/ios/devicectl.ts` | `platforms/ios/devicectl.dart` |
| `platforms/android/multitouch-helper.ts` | `platforms/android/multitouch_helper.dart` |
| `android-multitouch-helper/` (APK source) | `lib/src/native/android-multitouch-helper/` |

Notes:
- `roundOneDecimal` lives in `perf_utils.dart` (not just `perf_frame_analysis.dart`). When importing both, use `show` to avoid ambiguous-import errors.
- `perf_frame_analysis.dart` re-exports `roundOneDecimal` from `perf_utils.dart` via `export '../perf_utils.dart' show roundOneDecimal`.
- iOS `perf_xml.dart` uses `XmlElement` from the `xml` package (not a custom XmlNode). All helpers take `XmlElement?` and `Iterable<XmlNode>`.
- iOS `resolveIosDevicePerfTarget` lives in `perf.dart` (upstream puts it there too). It calls `listIosDeviceApps` + `listIosDeviceProcesses` from `devicectl.dart`.
- `IosDeviceProcessInfo` (executable: file:// URL + pid) is defined in `devicectl.dart`.

| `platforms/app-resolution-cache.ts` | `platforms/app_resolution_cache.dart` |
| `platforms/android/app-lifecycle.ts` | `platforms/android/app_lifecycle.dart` |
| `platforms/ios/apps.ts` (MVP subset) | `platforms/ios/app_lifecycle.dart` |

**Dart iOS app_lifecycle.dart deviations from TS apps.ts:**
- Takes `String udid` everywhere, not `DeviceInfo` struct — `AppResolutionCacheScope` variant field is omitted
- macOS branch of `resolveIosApp` not ported (no macOS module yet)
- `resolveIosApp` is new in this file as of commit 2c73e39b port; callers currently use bundleId directly

| `commands/snapshot-unchanged.ts` | `snapshot/unchanged.dart` |
| `daemon/wait-current-surface.ts` | `runtime/wait_current_surface.dart` |
| `alert-contract.ts` | types inlined into `backend/options.dart` (`AlertPlatform`, `AlertSource`, constants inlined into `alert.dart`) |
| `platforms/android/alert-detection.ts` | `platforms/android/alert_detection.dart` |
| `platforms/android/alert.ts` | `platforms/android/alert.dart` |
| `daemon/android-system-dialog.ts` | `platforms/android/system_dialog.dart` |
| `platforms/android/app-parsers.ts` | `platforms/android/app_parsers.dart` |
| `platforms/android/fill-verification.ts` | `platforms/android/fill_verification.dart` |
| `platforms/fill-diagnostics.ts` | `platforms/fill_diagnostics.dart` |

**Wait current surface pattern (d268b79a):**
- Upstream wraps `DaemonResponse` at response boundary; Dart enriches `AppError` inline in `wait()` polling loop
- Surface inspection uses `captureSnapshot(interactiveOnly: true, compact: true)` — distinguished from polling calls by checking both flags
- `isWaitTimeoutMessage` uses `contains('timed out')` (not a regex) to match the Dart timeout format
- `_normalizeType` is duplicated locally (private); not exported from processing.dart

**Snapshot unchanged detection pattern (dea6c3b1):**
- TS has a `snapshotCommand` runtime-command layer above the backend; Dart ports this logic directly into `AgentDevice.snapshot()`
- `forceFull` is not passed to `BackendSnapshotOptions` — it's session-layer only
- `SnapshotNode.focused` is not yet in the Dart port; omit from comparable key in `_buildComparableKey`
- The comparable key uses `StringBuffer` (no `dart:convert` import needed) instead of `JSON.stringify`
- CLI flag changes (`snapshotForceFull`, `withoutUnchanged`) not ported — no CLI layer in Dart port

| `platforms/fill-diagnostics.ts` | `platforms/fill_diagnostics.dart` |
| `platforms/android/fill-verification.ts` | `platforms/android/fill_verification.dart` |
| `utils/location-coordinates.ts` | `utils/location_coordinates.dart` |
| `platforms/setting-state.ts` | `platforms/setting_state.dart` |

**Location coordinates pattern (a9064254):**
- TS `requireLocationCoordinates(options: Partial<LocationCoordinates>)` → Dart `requireLocationCoordinates(double? latitude, double? longitude)` — flat params, no options object
- TS `PermissionSettingOptions` renamed to `SettingOptions` and gained lat/lon — not ported (type not in Dart)
- Emulator detection uses `serial.startsWith('emulator-')` (Dart has no DeviceInfo in this call path)
- iOS `simctl location set <lat>,<lon>` and `simctl privacy grant/revoke location` ported in follow-up (see `setSetting` stack wiring commit)

**setSetting stack wiring (gap from a9064254 deferred work):**
- `Backend.setSetting(ctx, setting, state, [options])` added as default-unsupported method
- `AndroidBackend.setSetting` delegates to `setAndroidSetting(serial, setting, state, ...flatOptions)`
- `IosBackend.setSetting` handles `location` setting: state `set` → `xcrun simctl location <udid> set <lat>,<lon>`; state `on/off` → `xcrun simctl privacy <udid> grant/revoke location <bundleId>`; all other settings throw `unsupported`
- `AgentDevice.setSetting(setting, state, {latitude, longitude, permissionTarget, permissionMode})` — named params collected into options map
- `SettingsCommand` CLI: 2 positionals → programmatic set; 0-1 positionals → open settings (existing behavior preserved)

**AndroidUiNodeMetadata pattern (600e9565):**
- `readNodeAttributes` and `parseBounds` are private in TS after this refactor; the Dart port made them private too
- `androidUiNodes(xml)` is the public flat-iterator API; returns `Iterable<AndroidUiNodeMetadata>`
- `_readAndroidUiNodeMetadata(node)` is the private per-node builder used by both `androidUiNodes` and `parseUiHierarchyTree`

**FillDiagnosticNode inheritance pattern:**
- `AndroidFillVerificationNode extends FillDiagnosticNode` — don't redeclare parent fields; use `super.` params
- Non-nullable narrowing can't be enforced via field override in Dart; add a getter (e.g. `verificationRect`) for non-null access
- Context classes used as named params in public functions must be public to avoid `library_private_types_in_public_api` lint

**ScrollEdgeState porting pattern (b0e19c9d):**
- `ScrollEdge` is a `typedef String` (no union/enum needed)
- `ScrollEdgeTarget` is a plain class with `const empty` factory
- `isScrollableNodeLike` in Dart takes named params `(type:, role:, subrole:)` — call sites must destructure the node
- `isNodeVisibleInEffectiveViewport` in Dart requires a pre-built `byIndex` map as 3rd param; `scroll_edge_state.dart` builds it via `buildSnapshotNodeMap`
- `runScrollEdgePasses<T>` returns a Dart named record `({int passes, T? result})` — callers use `.passes` and `.result`
- `formatScrollEdgeMessage` takes `double?` for amount (TS uses `number | undefined`)
- Scroll-to-edge wired into `AgentDevice.scroll()` via `_resolveScrollTarget` + `runScrollEdgePasses`; wires `backend.captureSnapshot` directly (no daemon `interactor.snapshot` call)

**Android ANR recovery pattern (dcc74218):**
- TS `SessionState` (device.id, appBundleId, recording, name) → Dart `AndroidSystemDialogSession` (plain class with deviceId, appBundleId, recording, sessionName)
- `recording` flag in Dart is derived from on-disk recorder record (`_readAndroidRecorder(serial) != null`)
- TS dispatch wiring (interaction.ts, interaction-touch.ts, request-generic-dispatch.ts) maps to `AndroidBackend` methods because `AndroidBackend` is the Dart dispatch layer for Android
- `_withAndroidAnrGuard(ctx, command, action)` helper wraps before+after checks; returns warning String? or null
- `AndroidSnapshotOptions` does NOT have `interactiveOnly`/`compact` top-level — use `snapshot: SnapshotOptions(interactiveOnly: false, compact: false)` nested
- Sealed class `_DialogButtonTapResult` with `_DialogButtonTapOk` / `_DialogButtonTapFailed` variants; extension on sealed for field access
- `getAndroidBlockingDialogFocus` exported from `app_lifecycle.dart` via `export 'app_parsers.dart' show AndroidBlockingDialogFocus`

**Gesture dispatch pattern (47b981c8):**
- TS dispatch goes through `Interactor` interface (daemon layer) → `createAndroidInteractor` / iOS `iosRunnerOverrides`; Dart goes directly through `Backend` subclass overrides (AndroidBackend, IosBackend)
- Android `pan`/`fling` → `swipeAndroid` (adb input swipe); Android `pinch`/`rotateGesture`/`transformGesture` → multitouch helper APK via `adb shell am instrument`
- iOS `pan`/`fling` → `drag` runner command; `rotateGesture` → `rotateGesture` runner command; `transformGesture` → `transformGesture` runner command
- CLI gesture commands live in `gesture_cmds.dart` as `GestureCommand` with subcommands (not inlined into `simple_action_cmds.dart`)
- `BackendRotateGestureOptions.centerX/centerY` (not `center: Point`) — flat fields because rotate may omit center
- AdbProvider touch-injector override (`resolveAndroidTouchInjector`) not ported — no provider injection layer in Dart
- `@visibleForTesting` helpers `parseAndroidMultitouchHelperManifestForTest` + `parseAndroidMultitouchHelperOutputForTest` expose internal parsers for tests

**iOS log predicate pattern (67aa89af):**
- `buildAppleLogPredicate(bundleId, executableName?)` → `_buildAppleLogPredicate(bundleId, [executableName])` private top-level function in `ios_backend.dart`
- `_resolveIosSimulatorExecutableName({udid, appBundleId})` uses `simctl get_app_container` + `plutil -extract CFBundleExecutable raw` to resolve the binary name
- Both `startLogStream` and `readLogs` now call `_resolveIosSimulatorExecutableName` before building predicates
- Daemon `app-log-ios.ts` functions (startIosSimulatorAppLog etc.) live in Dart inside `ios_backend.dart` inline logic — no separate app-log file
- `core/launch-console.ts` constants (LAUNCH_CONSOLE_IOS_SIMULATOR_ONLY_MESSAGE, LAUNCH_CONSOLE_DIRECT_APP_ONLY_MESSAGE) → not a separate file in Dart; validations not ported (no dispatch/CLI layer)

**iOS launch console pattern (67aa89af):**
- `BackendOpenOptions.launchConsole` (String?) added to `options.dart`
- `openIosApp(udid, bundleId, {launchConsole})` in `app_lifecycle.dart` — `--console-pty` flag added to `simctl launch`; combined stdout+stderr written to logPath
- Timeout handling: `ExecOptions(allowFailure: true, timeoutMs: 25000)` — on `AppError` with matching `details['timeoutMs']`, flush captured output (timeout is graceful for console capture)
- `_joinProcessOutput` helper avoids double-newline between stdout and stderr
- `ios_backend.dart openApp` passes `options?.launchConsole` to `openIosApp`

**iOS runner Swift file update pattern (ea217931):**
- The iOS runner Swift files (`RunnerTests+Models.swift`, `RunnerTests+CommandExecution.swift`, `RunnerTests+Interaction.swift`) are bundled under `lib/src/native/ios-runner/AgentDeviceRunner/AgentDeviceRunnerUITests/`
- The runner uses `PBXFileSystemSynchronizedRootGroup` in its Xcode project — new source files dropped in the directory are picked up automatically; no pbxproj update needed
- When upstream adds new command types to the runner, update all three Swift files: Models (CommandType enum + Command struct fields), CommandExecution (switch cases), Interaction (implementation functions)
- `RunnerTests+CommandExecution.swift` cases use distinct local variable names for outcome/timing to avoid Swift shadowing warnings (e.g., `rotateOutcome`, `rotateTiming`, `transformOutcome`, `transformTiming`)
- `RunnerSynthesizedGesture.h/.m` pattern: ObjC class, bridging header import; the runner's `transformGesture()` Swift function computes radius from `interactionRoot(app:).frame` internally; Dart caller does NOT send radius

| `daemon/snapshot-presentation/tree.ts` | `snapshot/presentation_tree.dart` |
| `daemon/snapshot-presentation/ios/index.ts` + `ios/actions.ts` + `ios/noise.ts` + `ios/rows.ts` + `ios/scroll.ts` | `snapshot/ios_presentation.dart` (merged into one file) |
| `utils/repeated-nav-subtree.ts` | `utils/repeated_nav_subtree.dart` |
| `utils/snapshot-label-signals.ts` | helpers kept private in `repeated_nav_subtree.dart` (no separate file) |

**iOS presentation pipeline wiring pattern (0bc1b1e9):**
- `presentIosInteractiveSnapshot` called in `IosBackend.captureSnapshot()` when `options?.interactiveOnly == true && options?.raw != true`
- `_shouldPresentIosInteractiveSnapshot(options)` helper encapsulates the condition
- Upstream daemon `snapshot-capture.ts` wiring: `backend === 'xctest' && flags?.snapshotInteractiveOnly === true && flags.snapshotRaw !== true`
- `mergeReplacement` in Dart uses named parameters instead of a `Partial<RawSnapshotNode>` spread object
- `collectDescendants` uses depth-based forward scan (not parentIndex traversal)
- `normalizeType` was already made public in `processing.dart` as of commit `5671ce9`

| `utils/snapshot-occlusion.ts` | `snapshot/snapshot_occlusion.dart` (new in 2014cb68 port) |
| `utils/rect-center.ts` | inlined in `snapshot/presentation_tree.dart` (`areRectsApproximatelyEqual`) + `interaction_targeting.dart` (`_areRectsApproximatelyEqual`) |
| `commands/interaction-targeting.ts` | `commands/interaction_targeting.dart` |
| `commands/interaction-resolution.ts` | not ported (daemon command dispatch layer) |
| `utils/snapshot-lines.ts` | `snapshot/lines.dart` |

**Occlusion annotation pattern (2014cb68):**
- `annotateCoveredSnapshotNodes` walks nodes in presentation order; only overlay-like types (tabbar, toolbar, navigationbar, sheet, dialog, etc.) can be covers — generic containers (CollectionView etc.) cannot
- `isSnapshotNodeInteractionBlocked(node)` checks `node.interactionBlocked != null` — currently only `'covered'` is used
- `interactionBlocked: String?` added to `RawSnapshotNode` (non-final, mutable like `presentationHints`)
- `ActionableTouchResolutionReason.covered` added — early-exits `resolveActionableTouchResolution` when node is already blocked
- Covered ancestors are skipped in the hittable-ancestor climb; covered children are skipped in same-rect descendant walk
- Daemon `find.ts` wiring (`interactiveMatchScore` + `dispatchFocusForFindMatch`) NOT ported — daemon-less port has no find handler
- `interaction-resolution.ts` covered-error surface NOT ported — no runtime command dispatch layer in Dart port

**Android snapshot content-recovery pattern (df490ee8):**
- New `snapshot_content_recovery.dart` mirrors `snapshot-content-recovery.ts` 1:1
- `AndroidUiNodeMetadata` gained `windowType` (from `window-type` XML attr) — used by recovery classifier to identify window-root nodes
- `_pruneAndroidCoveredSubtrees` now takes `_AndroidTreePruneState` (replaces bare `Map<AndroidUiHierarchy, bool>`) for the rename to `actionableContentMemo`
- `_canCoverSibling` split into `_hasOwnAgentVisibleContent` (own label/id/hittable, no recursion) + `_hasActionableDescendant` (only `hittable` counts in subtree, not labels)
- Recovery integration in `snapshot.dart`: after building the helper capture record, call `classifyAndroidHelperContentRecovery`; if non-null, call `_recoverAndroidHelperContentUnavailable` which emits a diagnostic, calls `_resetAndroidSnapshotHelperRuntime` (force-stop + 200ms delay), then falls through to `_captureStockUiHierarchy`
- Upstream uses `DeviceInfo` object; Dart uses `String serial` throughout — the recovery helper takes `serial` not `device`
- TS integration tests with mock ADB not ported (no mock-command infra in Dart test suite); pure-function recovery classifier unit-tested instead

**Booted memo pattern (996d93e97):**
- Upstream: `simulator.ts` has `SIMULATOR_BOOTED_MEMO_TTL_MS = 5000`, private `simulatorBootedMemo: Map<string, number>`, key is `${device.id}|${device.simulatorSetPath ?? ''}`
- Dart port: memo lives in `devices.dart` as `_simulatorBootedMemo: Map<String, int>`, key is udid only (MVP has no simulatorSetPath)
- Public API: `simulatorBootedMemoTtlMs`, `readSimulatorBootedMemo(udid)`, `markSimulatorBooted(udid)`, `clearSimulatorBootedMemo(udid)`, `resetSimulatorBootedMemoForTests({nowMs})`
- Clock seam: `_nowMsOverride: int Function()?` in `devices.dart` — injectable in tests via `resetSimulatorBootedMemoForTests(nowMs: () => virtualNow)`
- `listAppleSimulators` seeds memo for every Booted simulator it encounters; callers that launch apps call `markSimulatorBooted` after success

**Relaunch path in ios_backend.dart (996d93e97):**
- `IosBackend.openApp` now handles `options.relaunch == true`
- Simulator relaunch: `closeIosApp` (no runner teardown) + seed memo → then `openIosApp` + seed memo
- Device relaunch: `shutdownRunnerFor` + `terminateIosDeviceProcess` → then `launchIosDeviceProcess`
- Prior to this commit, `BackendOpenOptions.relaunch` existed but was completely unused in `IosBackend`

**Collapsed simulator relaunch (6dc0aa550):**
- `openIosApp` gained `terminateRunningApp: bool = false` — adds `--terminate-running-process` to simctl launch args
- `_buildIosSimulatorLaunchArgs` (private) adds the flag after `--console-pty` (if any) but before the device ID — mirrors upstream flag ordering in `buildIosSimulatorLaunchArgs` (TS)
- `buildIosSimulatorLaunchArgs` exposed as `@visibleForTesting` public function (private wrapper kept for internal use) — seam for flag-ordering unit tests
- `ios_backend.dart openApp`: `collapseSimulatorRelaunch = options?.relaunch == true && kind == 'simulator'`; when true, skip separate `closeIosApp` and pass `terminateRunningApp: true` to `openIosApp`
- Upstream has 3 exclusions (URL opens, clearAppState, openPositionals.length===1); Dart has none — URL opens don't reach this layer, and `clearAppState` is not in `BackendOpenOptions`
- 7 new unit tests in `test/platforms/ios/app_lifecycle_launch_args_test.dart` test flag ordering directly on `buildIosSimulatorLaunchArgs`

**Idle-stop pattern (b67053e97):**
- Upstream uses an in-process `setTimeout` (in the daemon's long-lived process) — Dart cannot port this directly because the port is daemon-less
- Adaptation: enforce idle bound at reconnect time inside `_liveRunner` (ios_backend.dart) — before adopting a retained runner, call `isRunnerSessionIdleExpired(session, idleStop)` and if expired, stop+clear the runner and return null (triggers fresh launch)
- `lastSuccessAt` already round-trips through the runner record JSON (`lastSuccessfulRunnerResponseAtMs`) since the `dfd5c712` port
- `resolveRunnerIdleStopDuration([env])` accepts optional env override map for unit-test isolation (Dart `Platform.environment` is read-only)
- Idle-stop check goes BEFORE `isAlive` probe: "too old → don't probe" mirrors upstream's timer ordering vs readiness preflight
- Pure-function seams `isRunnerSessionIdleExpired` + `resolveRunnerIdleStopDuration` in `runner_client.dart` — testable without live runner

**Why:** Used every porting session to locate the right files without re-searching.
**How to apply:** When given a TS file to port, look up its Dart equivalent here first.
