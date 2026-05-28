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

**Why:** Used every porting session to locate the right files without re-searching.
**How to apply:** When given a TS file to port, look up its Dart equivalent here first.
