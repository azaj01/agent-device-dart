---
name: File mappings TS → Dart
description: Key upstream TypeScript file paths and their Dart equivalents in the port
type: project
---

Key file mappings between `agent-device/src/` and `packages/agent_device/lib/src/`:

| TS path | Dart path |
|---|---|
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
- iOS `simctl location set <lat>,<lon>` deferred — setIosSetting not yet ported to Dart

**AndroidUiNodeMetadata pattern (600e9565):**
- `readNodeAttributes` and `parseBounds` are private in TS after this refactor; the Dart port made them private too
- `androidUiNodes(xml)` is the public flat-iterator API; returns `Iterable<AndroidUiNodeMetadata>`
- `_readAndroidUiNodeMetadata(node)` is the private per-node builder used by both `androidUiNodes` and `parseUiHierarchyTree`

**FillDiagnosticNode inheritance pattern:**
- `AndroidFillVerificationNode extends FillDiagnosticNode` — don't redeclare parent fields; use `super.` params
- Non-nullable narrowing can't be enforced via field override in Dart; add a getter (e.g. `verificationRect`) for non-null access
- Context classes used as named params in public functions must be public to avoid `library_private_types_in_public_api` lint

**Why:** Used every porting session to locate the right files without re-searching.
**How to apply:** When given a TS file to port, look up its Dart equivalent here first.
