# Port gap analysis: upstream `041b4822` → `4648051b` (0.16.10 → 0.18.0)

179 new upstream commits since the last ported boundary. Classified by 3 parallel
agents reading real diffs against the daemon-less Dart port's scope (iOS XCUITest
runner + Android adb/uiautomator; no daemon, Maestro, web/CDP, MCP, perf-harness).

## Bucket A — iOS Swift runner re-sync (handle as ONE end-state sync, like `0ef1010`)

The Dart port's XCUITest Swift runner is frozen at the ~0.16.10 sync point. It is
missing 5 new Swift files + 1 ObjC bridge and many behavioral changes. Re-sync the
`AgentDeviceRunnerUITests/RunnerTests+*.swift` end-state, preserving port-specific
host-app scaffolding (`AgentDeviceRunnerApp.swift`, `ContentView.swift`,
`RunnerBSDSocketServer.swift`, UITests `Assets.xcassets`, bridging header).

New files to add: `RunnerTests+SequenceExecution.swift`, `RunnerTests+ScrollGesture.swift`,
`RunnerTests+SnapshotCapturePlan.swift`, `RunnerTests+AXSnapshotFallback.swift`,
`RunnerTests+FlatSnapshotFiltering.swift`, `RunnerAXSnapshotBridge.h`, `RunnerAXSnapshotBridge.m`.

Commits folded into this sync: `74007018` `aa5b07fa` `76cee982` `5c083eac` `aa741b47`
`16312d07` `3780ca6e` `e6e2baf3` `3a02e514` `cba020de` `fa8cce37` `931cbba1` `945a780c`
`93a69981` `d14dfab4` `5c83fe4e`(swift part) `09339e12`(swift part).

NOTE `5a676235`/`ced61ce3` are runner *build* changes (.m app refactor, sandboxing
flag); the Dart port intentionally keeps a `.swift` host app — evaluate, don't blindly copy.

## Bucket B — Dart-side independent behavioral ports (unit-testable)

| Commit | What | Dart target |
|--------|------|-------------|
| `c89719f7` | decode escaped selector values (`\n \t \r \uXXXX`); Dart `_unquote` only handles `\" \'` | `selectors/parse.dart` |
| `2014cb68` | block taps on covered/occluded snapshot nodes (generic geometric occlusion) | `commands/interaction_targeting.dart` (+ new occlusion helper) |
| `09339e12` | honor caller scroll duration; iOS `scroll()` hardcodes 250ms | `core/scroll_gesture.dart`, `platforms/ios/ios_backend.dart` |
| `df490ee8` | recover Android snapshots from system-only / empty helper output | `platforms/android/snapshot.dart` (+ recovery helper) |
| `4f0886d1`+`8de4dddd` | iOS runner crash diagnostics classification | `platforms/ios/runner_client.dart` (+ diagnostics helper) |
| `c4950a94` | detect disabled Developer Tools mode before runner startup | `platforms/ios/runner_client.dart` |
| `2e02f767` | validate batch steps through command contracts | `cli/commands/batch_cmd.dart` / `replay/batch.dart` |
| `3f6363c9` | route replay path commands correctly | `cli/` router / `replay_cmd.dart` |

## Bucket C — scope-judgment / lower priority (deferred unless requested)

- Perf features: `81448c8f` (perf metrics/frames grammar), `a35c444d` (memory),
  `f8704f46` (iOS xctrace), `f0d1674c`+`c7c9db74` (Android native perfetto/simpleperf).
  Dart has its own `benchmark/` + `perf_*.dart`; these add platform perf collection.
- `48c121d5`+`1da6fd51` debug-symbols workflow command.
- `73dc7f88` recording export-quality / max-size flags.
- `350cd0c1`(+`d14dfab4`) external prebuilt xctest runner artifact.

## Out of scope (n/a / skip) — the large majority

Maestro (all), daemon internals (sessions/leasing/proxy/RPC/recording-backends/state-dir),
web + agent-browser + agent-cdp/CDP, MCP server/registry, 0.18.0 TS type/registry/AppleOS
refactors, CI, docs, version & dependency bumps. Also n/a despite plausible subjects:
`bf21540b`/`dd5c0be0`/`5be101c2`/`d291e4c5` (target the Android provider-native-touch path
or persistent helper *session* — neither exists in the command-scoped Dart port).
