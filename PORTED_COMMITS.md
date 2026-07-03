# Ported Commits Registry

Tracks which upstream `agent-device` (TypeScript) commits have been ported to the Dart codebase.

**Status values:**
- `ported` — changes implemented in the Dart port
- `pending` — applicable but not yet ported
- `skipped` — intentionally deferred (with reason)
- `n/a` — not applicable (version bumps, docs-only, daemon refactors, RN/Metro, MCP, skills, Windows-only)

## Registry

| Upstream | Title | Status | Dart commit | Notes |
|----------|-------|--------|-------------|-------|
| `bb245675` | fix: improve android snapshot freshness (#430) | ported | (Phase 3) | Platform slice in Phase 3; daemon session cache deferred |
| `d6b8b12a` | docs: improve agent discoverability for observability (#431) | n/a | — | Docs/skills only |
| `2062bffc` | feat: parametrise .ad replay scripts (#433) | ported | `55e00774` | Full `${VAR}` substitution, env directives, namespace reservation |
| `22936fd6` | fix: use artifacts route for daemon downloads (#434) | n/a | — | Daemon HTTP route |
| `b0813cad` | feat: add react devtools passthrough (#435) | n/a | — | RN-specific |
| `18cbc6ce` | fix: use sh fences for .ad scripts in replay-e2e docs (#436) | n/a | — | Website docs |
| `5cea4dd0` | feat: pass through GitHub Actions artifact install sources (#437) | n/a | — | Daemon/remote-config |
| `6c7e8323` | fix: support remote Android React DevTools tunnel (#438) | n/a | — | RN-specific |
| `4ddd29cb` | feat: add Metro reload command (#440) | n/a | — | RN Metro; Phase 11 |
| `f926d2c9` | feat: add cloud remote auth flow (#443) | n/a | — | Cloud remote-config |
| `36454794` | feat: export observability helpers (#444) | n/a | — | NPM export boundary |
| `adf1d06a` | refactor: avoid duplicate packet metadata (#445) | n/a | — | TS internal refactor |
| `53750084` | refactor: finish companion tunnel naming (#446) | n/a | — | RN companion |
| `2e2b9af8` | chore: drop hosted runtime entrypoints (#448) | n/a | — | TS package boundary |
| `f07e82e3` | chore: add fallow quality gate (#449) | n/a | — | TS tooling |
| `8be5fa21` | test: deduplicate CLI capture helpers (#450) | n/a | — | TS test refactor |
| `5a3cf943` | refactor: reduce fallow baseline noise (#451) | n/a | — | TS tooling |
| `40fe5e23` | fix: improve cloud remote auth UX (#452) | n/a | — | Cloud auth |
| `7c5b7670` | feat: add skillgym tests (#453) | n/a | — | skillgym |
| `d77a9211` | feat: add Android snapshot helper (#454) | ported | `a1f2c02` | Java APK + capture/install/artifact; remote download deferred |
| `83042cc4` | fix: preserve scoped Android snapshot refs (#456) | n/a | — | All changes are in daemon layer (session-snapshot.ts, snapshot-runtime.ts, handlers) + output.ts rendering which has no Dart equivalent; Dart port has no daemon or formatSnapshotText |
| `d1f5d919` | 0.13.3 | n/a | — | Version bump |
| `5260ac8e` | fix: harden Node runtime cleanup (#457) | n/a | — | Node daemon lifecycle |
| `2b23d69a` | docs: refresh README positioning (#458) | n/a | — | Docs |
| `fcabdc92` | docs: make agentic workflows a README heading (#459) | n/a | — | Docs |
| `994ee781` | fix: avoid killing stopped iOS runner (#460) | ported | (Phase 8B) | `_isProcessAlive` check in runner_client.dart |
| `d1a76410` | chore: update version guidance to >=0.14.0 | n/a | — | Docs |
| `60bbc5a6` | 0.14.0 | n/a | — | Version bump |
| `140fe338` | docs: replace bulky skills with versioned CLI help (#352) | n/a | — | Skills/docs |
| `4f4bf7b0` | perf: cache successful device readiness checks (#465) | n/a | — | Daemon cache |
| `8301f824` | perf: cache safe device hot paths (#463) | n/a | — | Daemon cache |
| `999b4751` | fix: resolve security alerts (#464) | n/a | — | npm security |
| `2c73e39b` | perf: cache app resolution (#466) | ported | `e56128f` | AppResolutionCache + Android/iOS wiring; macOS cache deferred (no macOS module); iOS scope omits variant (Dart uses plain udid, not DeviceInfo) |
| `6c368bf7` | docs: update agent-device guidance (#467) | n/a | — | Docs |
| `3fee9d6d` | fix: cache Android snapshot helper installs (#470) | ported | `773e6f1` | In-memory install-check cache |
| `bbb1d363` | fix: handle iOS keyboard Done dismiss controls (#469) | ported | `694e2ad` | — |
| `a9e8d902` | 0.14.1 | n/a | — | Version bump |
| `6a2bf9f6` | feat: export batch orchestration helpers (#472) | n/a | — | NPM export boundary |
| `dab81673` | 0.14.2 | n/a | — | Version bump |
| `f7c8f451` | build: upgrade skillgym to 0.6.0 (#473) | n/a | — | skillgym |
| `0c7e48d7` | feat: add Android frame health perf metrics (#474) | ported | `a22d989` | perf_frame_analysis/parser/frame + 23 tests |
| `cff8bd81` | feat: add iOS frame perf sampling (#477) | ported | `6299f90` | perf_xml, perf_frame (iOS), xctrace delta; 9 tests |
| `72ba612e` | fix: centralize Android adb execution (#478) | n/a | — | TS refactor; Dart already centralises via adb.dart |
| `fea7a5b7` | feat: expose daemon embedding and Android ADB APIs (#480) | n/a | — | Daemon/NPM boundary |
| `8aa4abe4` | feat: expand android adb provider boundary (#481) | n/a | — | NPM boundary |
| `78aab2a3` | feat: add android adb transfer provider APIs (#483) | n/a | — | Daemon handlers + NPM boundary |
| `d2b3d3fc` | fix: stop companion retrying invalid registrations (#484) | n/a | — | RN companion |
| `af73a101` | 0.14.3 | n/a | — | Version bump |
| `6a55d489` | fix: tunnel remote ios react devtools (#486) | n/a | — | RN DevTools |
| `1eeab43c` | 0.14.4 | n/a | — | Version bump |
| `dc4a1625` | fix: require explicit bridge lease for devtools tunnel (#487) | n/a | — | RN companion |
| `7ea8d9ee` | feat: discover cloud config during connect (#488) | n/a | — | Cloud remote-config |
| `7d47c679` | fix: persist remote react devtools companion (#489) | n/a | — | RN companion |
| `10fd2925` | fix: stabilize remote DevTools and install workflow (#490) | n/a | — | RN DevTools |
| `0fcb1d56` | 0.14.7 | n/a | — | Version bump |
| `a9064254` | feat: support precise location settings (#491) | ported | `10f51e8` | Android `adb emu geo fix` + coordinate utilities ported; iOS `simctl location set` + `privacy grant/revoke location` added in follow-up (see notes); SettingOptions rename skipped (type not in Dart); flat named params used instead of options object |
| `d2a3742c` | fix: enable tvOS compilation for XCUITest runner (#492) | ported | `1ed2e6e` | RunnerTests+TvRemote.swift |
| `076f0c07` | chore: upgrade skillgym to 0.8.0 (#493) | n/a | — | skillgym |
| `25d72895` | feat: add MCP discovery router (#494) | n/a | — | MCP server |
| `5df37ec9` | fix: improve android fill verification diagnostics (#495) | ported | `813b123` | fill_verification.dart + fill_diagnostics.dart; files landed in the f71371eb port commit as prior uncommitted work |
| `2ebb9aa4` | docs: improve agent discovery onboarding (#496) | n/a | — | Docs |
| `600e9565` | refactor: share android hierarchy metadata (#497) | ported | `813b123` | AndroidUiNodeMetadata + androidUiNodes() in ui_hierarchy.dart; readNodeAttributes/parseBounds restored as public aliases; input_actions.dart delegates to fill_verification.dart; landed in same commit as f71371eb port |
| `8a1e1955` | docs: trim stale internal docs (#498) | n/a | — | Docs |
| `23dc6a8f` | fix: keep MCP registry description valid (#499) | n/a | — | MCP |
| `af5db7f8` | 0.14.8 | n/a | — | Version bump |
| `274eeb5d` | refactor: route process spawning through exec helpers (#504) | n/a | — | TS refactor; Dart already uses exec.dart |
| `3966c5e1` | fix: hide adb console windows on Windows (#503) | n/a | — | Windows-only |
| `9b559299` | fix: preserve iOS tab button tap centers (#508) | ported | `b5ed594` | interaction_targeting.dart |
| `517b5198` | docs: clarify agent-device binary resolution (#511) | n/a | — | Docs |
| `0117eded` | refactor: make touch target resolution policy explicit (#510) | ported | `b5ed594` | interaction_targeting.dart |
| `336bf17a` | 0.14.9 | n/a | — | Version bump |
| `89f35945` | 0.14.9 | n/a | — | Version bump |
| `fceaab95` | refactor: clarify command architecture (#512) | n/a | — | Daemon command architecture |
| `bc7cf47b` | refactor: add command definition foundation (#513) | n/a | — | Daemon command definitions |
| `8a6d6c14` | refactor: split request handler chain (#514) | n/a | — | Daemon request router |
| `78dc4263` | test: collocate dispatch interaction press coverage (#515) | n/a | — | TS test reorganisation |
| `8968b4bd` | refactor: add capture selector command definitions (#516) | n/a | — | Daemon command definitions |
| `9743fc8c` | refactor: split xctestrun product resolution (#517) | n/a | — | TS module split; Dart has own resolution |
| `24bc75bf` | refactor: collocate session lifecycle command metadata (#518) | n/a | — | Daemon session metadata |
| `801c2ae0` | fix: improve rn agent-device stability guidance (#519) | n/a | — | RN docs |
| `2e04edd8` | fix: prevent runner XCTest attachment bloat (#520) | ported | `1ed2e6e` | xctestplan with keepNever |
| `4666d58f` | refactor: simplify command route catalog (#521) | n/a | — | Daemon CLI router |
| `d12d27de` | docs: clarify agent-device shell resolution (#522) | n/a | — | Docs |
| `80895aed` | refactor: extract request execution scope (#523) | n/a | — | Daemon request scope |
| `13f30dd4` | refactor: share daemon runtime collaborators (#524) | n/a | — | Daemon runtime |
| `204a320e` | perf: fast-path macos device resolution (#525) | n/a | — | macOS; Phase 9 |
| `4553f7a3` | refactor: split platform interactors (#526) | n/a | — | Daemon interactors |
| `e4e05ece` | refactor: add command definition codecs (#527) | n/a | — | Daemon codecs |
| `1987198f` | refactor: split session recording modules (#528) | n/a | — | Daemon recording |
| `03207d9d` | fix: improve Android helper snapshot stability (#529) | ported | `b5ed594` | android_helper_snapshot_presentation.dart |
| `7e14decc` | fix: improve Android text entry stability (#540) | ported | `b5ed594` | IME ownership, fill verification, input_ownership.dart |
| `83efe544` | fix: default apps listing to user-installed (#541) | ported | `b5ed594` | `--all` flag; default user-installed |
| `59d28e84` | refactor: add provider-first device lab tests (#542) | n/a | — | TS test infra |
| `d67e9886` | fix: ios press idle timeout (#543) | ported | `1ed2e6e` | Swift runner quiescence skip |
| `c1550721` | fix: collapse Android snapshot row noise (#545) | ported | `b5ed594` | Row-noise collapse in presentation module |
| `d268b79a` | fix: report blockers on wait timeout (#546) | ported | (see note) | `wait_current_surface.dart` + `agent_device.dart` wait() enrichment; 4 tests. Deviations: Dart wait() is a direct polling loop (not daemon response wrapping), so surface enrichment happens inline on timeout rather than via response-level interception. `isWaitTimeoutMessage` regex adapted to match Dart error format (`contains('timed out')`). |
| `dea6c3b1` | fix: compact unchanged snapshot output (#547) | ported | `d7d725e` | `SnapshotUnchanged` type, `presentationKey` on `SnapshotState`, `unchanged.dart`, `forceFull` param; no CLI layer; `focused` field omitted from comparable key (not yet in Dart `SnapshotNode`) |
| `8f722c3c` | docs: guide bounded react devtools profiling (#548) | n/a | — | RN docs |
| `5c6c89e7` | docs: update PR guidance (#550) | n/a | — | Docs |
| `068d4c5d` | chore: remove `ensure-simulator` lifecycle command (#552) | ported | `b5ed594` | Command + module deleted |
| `60f36eff` | feat: add screenshot no-stabilize flag (#553) | ported | `b5ed594` | `--no-stabilize` flag |
| `b5cd1c49` | fix: handle busy Android RN snapshots (#554) | ported | `b5ed594` | Busy-state hints in snapshot errors |
| `41508d29` | fix: make mcp discovery-only (#556) | n/a | — | MCP |
| `094c2907` | perf: speed up iOS replay runner (#557) | ported | `1ed2e6e` | Direct selector tap, fast foreground guard |
| `4491efde` | 0.15.0 | n/a | — | Version bump |
| `840bef56` | fix: tighten env var surface (#560) | ported | `1ed2e6e` | Swift runner env var guards |
| `896adcc6` | feat: add maestro replay compatibility (#561) | pending | — | Superseded by `a5fffc6e` |
| `f71371eb` | fix: handle platform alerts (#562) | ported | (see note) | `alert_detection.dart` + `alert.dart` (Android); `handleAlert` overrides in `AndroidBackend` + `IosBackend`; `BackendAlertInfo` expanded with `source`/`platform`/`packageName`; `ui_hierarchy.dart` gains `packageName` field; `snapshot.dart` gains `helperWaitForIdleTimeoutMs`/`includeHiddenContentHints`. Deviations: iOS `handleAlert` delegates to runner and parses response inline (no daemon-level loop); `AndroidAlertResult` sealed class hierarchy instead of union type; daemon-level `snapshot-alert.ts` refactor not ported (no daemon layer in Dart). |
| `b0e19c9d` | perf: improve recording and interaction flows (#563) | ported | `10f51e8` | `scroll_edge_state.dart` (analyzeScrollEdgeState, captureScrollEdgeState, runScrollEdgePasses, formatScrollEdgeMessage); scroll-to-edge wired into AgentDevice.scroll() ('top'/'bottom'); 19 tests. Daemon-layer recording changes + RN overlay command not ported. Committed alongside `a9064254` port due to prior session. |
| `dfd5c712` | perf: speed up hot iOS taps (#572) | ported | (see note) | `lastSuccessAt` field + `shouldPreflightMutatingRunnerCommand`; Dart had no uptime preflight so the skip logic is infrastructure-only; serialized as `lastSuccessfulRunnerResponseAtMs` |
| `67aa89af` | feat: add iOS repro evidence capabilities (#573) | ported | `9a051bc` | `_buildAppleLogPredicate` + `_resolveIosSimulatorExecutableName` in ios_backend.dart; `launchConsole` in BackendOpenOptions + openIosApp + `--console-pty` launch capture in app_lifecycle.dart. Deviations: daemon-client/dispatch/CLI flag changes not ported (no daemon/CLI layer in Dart); daemon reset-on-timeout change (shouldResetDaemonAfterRequestTimeout) not ported. |
| `cd55a6a5` | fix: harden iOS simulator recording cleanup (#575) | ported | `f908873` | simctl recordVideo for simulator + SIGINT→SIGTERM→SIGKILL escalation + pgrep fallback |
| `47b981c8` | feat: add gesture command coverage (#576) | ported | `4f3e3ae` | `multitouch_helper.dart` (pinch/rotate/transform via APK), `BackendPan/Fling/RotateGesture/TransformGestureOptions` in options.dart, Backend.pan/fling/rotateGesture/transformGesture defaults, AndroidBackend overrides (pan/fling→swipeAndroid, pinch/rotate/transform→multitouch helper), IosBackend overrides (pan/fling→drag runner cmd, rotateGesture→rotateGesture runner cmd, transformGesture→transformGesture runner cmd), AgentDevice.pan/fling/rotateGesture/transformGesture, GestureCommand CLI umbrella (pinch/pan/fling/rotate/transform subcommands), 12 unit tests. Deviations: no daemon/interactor layer; AdbProvider touch-injector override not ported; _resolveDurationMs clamping simplified; auto-build of helper APK from source not supported. |
| `0bc1b1e9` | fix: simplify iOS interactive snapshots (#578) | ported | `05fd6f3` | `presentation_tree.dart` (shared tree utils) + `ios_presentation.dart` (noise/actions/rows/scroll merged into one file) + `repeated_nav_subtree.dart` (new rect-overlap algorithm); wired into `IosBackend.captureSnapshot()`; 16 tests. Deviations: 5 upstream TS files merged into 1 Dart file; `snapshot-label-signals.ts` helpers kept private in `repeated_nav_subtree.dart`; upstream android-helper changes already landed in prior port (5671ce9). |
| `5b63b9b4` | fix: make swift helper cache builds concurrent-safe (#579) | pending | — | Filesystem lock for swift cache |
| `168de53b` | fix: improve Android snapshot fidelity (#580) | ported | `5671ce9` | Replaces bottom-nav/duplicate-email passes with: markRectlessScrollableDescendantsForRemoval (hidden content hints), markUnlabeledActionRowsForPromotion (label promotion), markRepeatedActionRowDescendantsForRemoval (child control collapse). Adds isRectContainedBy, visibleNodeLabel, isScrollableNode, findAncestor. findNearestHittableAncestor refactored to use findNearestAncestor in processing.dart. 5 new unit tests. Deviations: no file split into submodules (kept in single file); daemon/screenshot-overlay-android layer and output.ts renderSnapshotDisplayLines changes not ported (no Dart equivalent); snapshot-processing.ts changes for SnapshotState node lookup not ported (Dart uses List not array index). |
| `6617d523` | 0.15.1 | n/a | — | Version bump |
| `a5fffc6e` | feat: add Maestro YAML replay compatibility (#581) | pending | — | Full Maestro compat; supersedes `896adcc6` |
| `bda96f1b` | fix: allow inventory selectors with session locks (#583) | n/a | — | Daemon lock policy only; Dart has no `applyRequestLockPolicy` — explicit selectors are always honored in `openAgentDevice()`, `DevicesCommand` already bypasses session state entirely |
| `c72cf0e1` | fix: clarify Android gesture transform behavior (#584) | ported | `bdb16e4` | Gesture timeout 15s→45s; `_kNoFinalResult`/`_kReportedFailure` internal codes; `_parseOutput` uses specific codes; `_runGesture` catch distinguishes reported failure (→COMMAND_FAILED), no-final-result (→generic error), and other AppError (rethrow). Java APK changes not ported (upstream Java layer). Test updated: NO_FINAL_RESULT and REPORTED_FAILURE codes asserted directly on parse function. |
| `93b04b2c` | docs: simplify README overview (#585) | n/a | — | Docs |
| `ea217931` | feat: support ios transform gesture (#586) | ported | `5cd3e07` | RunnerSynthesizedGesture.h/.m (ObjC private XCTest synthesis); bridging header import; RunnerTests+Models adds rotateGesture/transformGesture command types and dx/dy/degrees/velocity fields; RunnerTests+CommandExecution adds case handlers; RunnerTests+Interaction adds rotateGesture/transformGesture/transformGestureRadius/performCoordinateRotateGesture. No pbxproj update needed (PBXFileSystemSynchronizedRootGroup auto-picks up files). ios_backend.dart unchanged (already sends correct payload). Deviations: command-schema.ts description change not ported (no Dart equivalent); runner Swift files had not been updated since 47b981c8 port so rotateGesture/transformGesture infrastructure added here. |
| `bbe7c06f` | feat: auto-reverse Android localhost opens (#590) | ported | `9de97be` | `androidLocalhostReverseEndpoint` + `_ensureAndroidLocalhostReverse` in app_lifecycle.dart; 7 URL-parsing unit tests. Deviation: no AndroidPortReverseManager (not yet ported) — runs `adb reverse` via `runCmd` directly. Dart Uri.parse strips IPv6 brackets so `[::1]` removed from hostname set. |
| `87f087ca` | fix: capture Android snapshot timeout evidence (#591) | ported | `d02260c` | snapshot_timeout_evidence.dart + android_backend.dart hook; overlay-ref annotation always 'unavailable' (daemon session-snapshot not ported) |
| `dcc74218` | fix: recover Android app-owned ANRs (#592) | ported | `c2f6696` | system_dialog.dart (new), app_parsers.dart+app_lifecycle.dart extended, android_backend.dart wired; session state as AndroidSystemDialogSession; recording flag from on-disk recorder record |
| `819d7dc8` | feat: expose structured MCP command tools (#593) | n/a | — | MCP server only |
| `25c7ade7` | test: remove 151 unit tests fully covered by integration tests (#595) | n/a | — | TS test infra |
| `9a6bb6f7` | 0.15.2 | n/a | — | Version bump |
| `136d313a` | build: enable noUncheckedIndexedAccess (#600) | n/a | — | TS tooling |
| `ee57e1b1` | fix: improve Maestro test suite replay (#601) | skipped | — | Maestro (out of scope) |
| `2212062d` | 0.16.0 | n/a | — | Version bump |
| `af206140` | 0.16.1 | n/a | — | Version bump |
| `7a2428e5` | ci: reduce duplicated runner work (#602) | n/a | — | CI |
| `233df070` | ci: skip platform smoke for docs-only PRs (#604) | n/a | — | CI |
| `b2a39d23` | ci: gate PR preview builds (#603) | n/a | — | CI |
| `5083d045` | ci: stop waiting for preview pages build (#607) | n/a | — | CI |
| `46784f2e` | fix: internalize xml parsing (#606) | n/a | — | Dart uses `package:xml` |
| `0bbb06eb` | refactor: vendor png codec (#609) | n/a | — | Dart has own png util / `image` |
| `99e97c87` | feat: stream replay test progress (#605) | pending | — | Replay progress streaming (low priority) |
| `0dead15c` | fix: improve maestro text tap targets (#610) | skipped | — | Maestro (out of scope) |
| `34713df1` | 0.16.2 | n/a | — | Version bump |
| `ab760b6c` | fix: apply app icon to iOS UI test runner (#611) | n/a | — | Dart port ships its own Assets.xcassets |
| `e1b8686e` | fix: hint sparse snapshot fallback (#614) | n/a | — | Output-formatting layer (no Dart equivalent) |
| `9a026bf2` | 0.16.3 | n/a | — | Version bump |
| `d087a62d` | fix: improve Maestro Android reliability and snapshot speed (#612) | skipped | — | Maestro (out of scope) |
| `c78ccea5` | 0.16.4 | n/a | — | Version bump |
| `434bf70a` | fix: stabilize Maestro React Navigation flows (#618) | skipped | — | Maestro/RN (out of scope) |
| `f74f4e0f` | 0.16.5 | n/a | — | Version bump |
| `14bbcf4f` | docs: map Maestro compatibility debt (#621) | n/a | — | Docs |
| `0932ad56` | ci: publish MCP registry metadata (#627) | n/a | — | CI/MCP |
| `5d68483f` | test: add Maestro provider integration guards (#620) | skipped | — | Maestro (out of scope) |
| `3283e5e3` | ci: skip core CI for docs-only PRs (#619) | n/a | — | CI |
| `3522aa32` | fix: chunk long Android recordings (#617) | n/a | — | All daemon record-trace handlers (chunked-upload orchestration); daemon-less port records to a single file |
| `7909290a` | refactor: share Maestro target matching primitives (#622) | skipped | — | Maestro (out of scope) |
| `ea69ebd4` | refactor: converge Maestro input handling (#623) | skipped | — | Maestro (out of scope) |
| `10fc86f1` | refactor: converge Maestro gesture handling (#624) | skipped | — | Maestro (out of scope) |
| `7f2c2b72` | refactor: converge Maestro assertion waits (#625) | skipped | — | Maestro (out of scope) |
| `10501b0c` | fix: preserve remote config for interaction commands (#616) | n/a | — | Daemon remote-config |
| `ae73b77b` | refactor: narrow Maestro flow runtime bridge (#626) | skipped | — | Maestro (out of scope) |
| `dc37f869` | feat: expose iOS launch args for open (#598) | ported | (Step 4) | `BackendOpenOptions.launchArgs` → `openIosApp`/`_buildIosSimulatorLaunchArgs` (sim, appended after bundle id) + `launchIosDeviceProcess` (devicectl); `open --launch-args` CLI multi-option |
| `b7ca4fbc` | feat: forward --launch-args to adb shell am start on Android (#599) | ported | (Step 4) | `openAndroidApp(launchArgs:)` appends `...?launchArgs` to all 5 `am start` paths (deep-link, intent, package+activity, primary, resolved-component); no UNSUPPORTED guard existed to remove |
| `8e1f8a9f` | perf: lazy load daemon handlers and report bundle size (#608) | n/a | — | Daemon internals |
| `ece193e7` | fix: improve React Navigation Maestro reliability (#628) | skipped | — | Maestro/RN (out of scope) |
| `3cb126ea` | fix: avoid iOS edge lane for in-page swipes (#631) | pending | — | Targets swipe-preset lane logic not yet ported to `scroll_gesture.dart` |
| `1bdd9eeb` | 0.16.6 | n/a | — | Version bump |
| `efc0b213` | 0.16.7 | n/a | — | Version bump |
| `45cfad5c` | feat: e2e command perf benchmark harness + nightly CI (#630) | n/a | — | Dart port has its own `benchmark/` harness + CI |
| `a8bec058` | perf(ios): make get text ~80x faster for non-editable elements (#632) | n/a | — | Dart `getAttr('text')` already returns snapshot text directly; no slow `readTextAt` re-read path exists |
| `73c057a4` | perf+fix(ios): faster text entry + fix fill mis-navigation (#633) | ported | `0ef1010` | Swift `RunnerTests+Interaction.swift` synced in Step 1 end-state sync |
| `fa4e2d5e` | fix(ios): pinch via two-finger synthesis (#634) | ported | `0ef1010` | Swift synced in Step 1 |
| `2068f604` | fix: improve ios selector reads and maestro reliability (#636) | ported | `0ef1010` | Swift `+Interaction`/`+TvRemote` synced in Step 1; daemon/Maestro parts n/a |
| `b09e7d37` | fix: preserve iOS AX snapshot failures (#639) | ported | `0ef1010` | Swift `+Snapshot`/`+CommandExecution`/`+Models` synced in Step 1; `runner-session.ts` n/a (daemon) |
| `096785b7` | fix: clean up recording stop and snapshot traversal (#640) | pending | — | iOS presentation traversal (`tree.ts`→`presentation_tree.dart`/`ios_presentation.dart`); Swift part synced in Step 1 |
| `66ec92f8` | fix: retry no-op maestro taps (#644) | skipped | — | Maestro (out of scope) |
| `5492cf46` | refactor(ios): single CommandTraits table for runner command classification (#642) | ported | `0ef1010` | Swift synced in Step 1 |
| `4f8e0af8` | fix: improve maestro test output (#647) | skipped | — | Maestro (out of scope) |
| `5d2b2ed5` | fix: harden react native overlay dismissal (#641) | skipped | — | RN (out of scope) |
| `eb3ca302` | fix: normalize maestro loading ellipsis (#648) | skipped | — | Maestro (out of scope) |
| `3785a175` | fix(ios): unify multi-touch gestures on two-finger synthesis + hinted unsupported errors (#645) | ported | `0ef1010` | Swift synced in Step 1 |
| `9e653720` | fix: resolve test-app dependabot alerts (#649) | n/a | — | Deps |
| `2546ca31` | fix: dismiss RN overlays in Maestro compat (#650) | skipped | — | Maestro/RN (out of scope) |
| `37618c98` | 0.16.8 | n/a | — | Version bump |
| `d5c94b02` | fix: improve maestro test output (#652) | skipped | — | Maestro (out of scope) |
| `4d016db3` | refactor(ios): extract the text-entry engine into RunnerTests+TextEntry.swift (#651) | ported | `0ef1010` | New Swift file synced in Step 1 |
| `ef3c5121` | fix: align Maestro assertVisible timeout (#653) | skipped | — | Maestro (out of scope) |
| `be5081d4` | 0.16.9 | n/a | — | Version bump |
| `25d5a2a7` | fix: bound iOS simulator app termination (#654) | n/a | — | Dart `closeIosApp` already bounds terminate at 15s |
| `b1aaa3a4` | chore: update glama mcp metadata (#655) | n/a | — | MCP metadata |
| `e96de318` | fix: stabilize android perf harness setup (#657) | n/a | — | Perf harness (Dart has own) |
| `cbe725d4` | refactor(ios): gesture-response factory + performGesture wrapper in CommandExecution (#659) | ported | `0ef1010` | Swift synced in Step 1 |
| `3f65124e` | refactor: add iOS runner lifecycle protocol (#658) | n/a | — | Daemon-oriented runner-session lifecycle (daemon-less port keeps FileMutex model) |
| `daaf71a6` | refactor(ios): safely(tag:default:) wrapper (#660) | ported | `0ef1010` | Swift synced in Step 1 |
| `57cd3f3a` | perf: recover iOS runner responses by status (#661) | n/a | — | Daemon status-recovery; daemon-less port serializes via FileMutex (runner-side journal/status synced in Step 1, client recovery not needed) |
| `f2ef6887` | docs(ios): idleTimeout guardrail notes (#664) | n/a | — | Docs |
| `3ae2472d` | fix: keep iOS runner status transport visible (#663) | n/a | — | Daemon status transport (see `57cd3f3a`) |
| `7e30a830` | fix: tune iOS runner response retention (#665) | n/a | — | Daemon response retention (see `57cd3f3a`) |
| `7f035f34` | fix: reduce ios runner invalidation after status recovery (#666) | n/a | — | Daemon status-recovery tuning (see `57cd3f3a`) |
| `66119e21` | perf: adapt ios runner uptime preflight (#662) | n/a | — | Daemon runner-session preflight (daemon-less port uses tolerant `isAlive`) |
| `3847f71c` | perf: avoid android hierarchy probe for scroll (#671) | n/a | — | Dart `scrollAndroid` already uses cheap `getAndroidScreenSize`; no hierarchy-probe path exists |
| `6247a3d4` | 0.16.10 | n/a | — | Version bump |
| `0313262a` | docs: clarify physical device signing help (#672) | n/a | — | Docs |
| `6f637d0e` | fix: filter covered Android snapshot surfaces (#675) | ported | (Step 3) | `ui_hierarchy.dart`: parse `visible-to-user`/`drawing-order`; `_pruneAndroidInvisibleSubtrees` + `_pruneAndroidCoveredSubtrees` (≥90% area occlusion by higher drawing-order sibling w/ agent-visible content) wired into `parseUiHierarchyTree`; negative-bounds regex fix. 4 unit tests. Dart uses in-place `removeWhere` (immutable node, growable children) vs upstream reassign. |
| `041b4822` | feat: add iOS runner prepare command (#673) | n/a | — | Daemon session-prepare handler (pre-warms runner in the long-lived daemon); daemon-less port already launches/reuses the runner on first command. No Swift/runner-protocol change. Optional thin `prepare` CLI nicety deferred. |
| `2014cb68` | fix: harden covered snapshot targets (#708) | ported | — | New `snapshot_occlusion.dart`: `annotateCoveredSnapshotNodes` + `isSnapshotNodeInteractionBlocked`. Added `interactionBlocked: String?` field to `RawSnapshotNode`/`SnapshotNode`. `interaction_targeting.dart`: `covered` reason added to `ActionableTouchResolutionReason`; early-exit on blocked node; skip blocked hittable ancestors; skip blocked same-rect children. `lines.dart`: `presentationHints` now emitted before the `summarizeTextSurfaces` guard (mirrors upstream). `unchanged.dart`: `interactionBlocked` + `presentationHints` added to comparable presentation. 10 unit tests. Dropped: daemon `find.ts` `interactiveMatchScore` / `dispatchFocusForFindMatch` wiring (daemon-less port has no find handler); `interaction-resolution.ts` `resolveInteractionTarget` refactor + covered error surface (no runtime command dispatch in daemon-less port). |
| `df490ee8` | fix: recover Android snapshots from system-only helper output (#861) | ported | (0.18.0 gap) | New `snapshot_content_recovery.dart`: `classifyAndroidHelperContentRecovery` classifies empty/system-only/content-poor helper output. `ui_hierarchy.dart`: added `windowType` to `AndroidUiNodeMetadata` (from `window-type` attr); refactored `_pruneAndroidCoveredSubtrees` to use `_AndroidTreePruneState` + split `hasOwnAgentVisibleContent` / `hasActionableDescendant` (tightens cover-qualification: descendants only count if hittable, not labeled). `snapshot.dart`: added `appBundleId` to `AndroidSnapshotOptions`; wired content-recovery check after helper capture; added `_recoverAndroidHelperContentUnavailable` + `_resetAndroidSnapshotHelperRuntime` (force-stop + delay). 12 unit tests for recovery classifier + 1 new `parseUiHierarchy` test. Dropped: upstream test cases that invoke full `snapshotAndroid` with mock ADB (no mock-command infra in Dart port test suite); `examples/test-app` dep bumps (RN, not ported). |
| `491ad7e9` | fix: improve session ownership and recovery guidance (#674) | n/a | — | Daemon session guidance |
| `6946c2f1` | fix: allow fresh session device binding (#677) | n/a | — | Daemon session binding |
| `74007018` | perf: speed up iOS swipes and harden runner cache (#676) | ported | (ios-runner-sync-1) | `RunnerSynthesizedGesture.h/.m`: `synthesizeSwipeWithApplication:x:y:x2:y2:durationMs:` + `synthesizeTapWithApplication:x:y:`; `+CommandExecution`/`+Interaction`/`+Models` updated; daemon runner-cache changes n/a |
| `86687feb` | fix: restore snapshot request timeout (#680) | n/a | — | Daemon snapshot request timeout |
| `4eeec609` | 0.16.11 | n/a | — | Version bump |
| `86db7e83` | fix: align iOS runner cache target metadata (#682) | n/a | — | Daemon runner cache |
| `3a930717` | docs: update public documentation links (#684) | n/a | — | Docs |
| `1881f6f2` | 0.16.12 | n/a | — | Version bump |
| `7ab99986` | fix: stabilize Maestro post-gesture snapshots (#681) | skipped | — | Maestro (out of scope) |
| `bf21540b` | refactor: consolidate android gesture backend selection (#689) | n/a | — | Daemon Android gesture backend selection; Dart port uses direct adb/multitouch helper |
| `ad7b3864` | feat: cache iOS runner artifacts during prepare (#688) | n/a | — | Daemon runner artifact cache |
| `6babdfb6` | 0.16.13 | n/a | — | Version bump |
| `36012a9e` | fix: update docs router dependency (#691) | n/a | — | Docs dependency |
| `7d7b4676` | fix: retry iOS runner prepare launch (#692) | n/a | — | Daemon runner prepare retry |
| `f2424f9d` | refactor: centralize daemon command registry (#693) | n/a | — | Daemon command registry |
| `aa5b07fa` | fix: keep iOS runner hot across app closes (#700) | ported | (ios-runner-sync-1) | `RunnerTests+Alert.swift`, `+Snapshot.swift` updated (AX snapshot recovery, snapshot freshness after app close); `RunnerTests.swift` change (remove `maxSnapshotElements`/`fastSnapshotLimit`) NOT ported (Dart keeps these fields) |
| `86971990` | fix: scope runner diagnostics to sessions (#704) | n/a | — | Daemon runner diagnostics |
| `81448c8f` | feat: add perf metrics and frames commands (#703) | n/a | — | Daemon perf metrics; Dart has own perf harness |
| `76cee982` | fix: stabilize iOS runner navigation taps (#702) | ported | (ios-runner-sync-1) | `RunnerSynthesizedGesture.h`: `interfaceOrientationForApplication:` declaration; docs/ADR changes n/a |
| `5c083eac` | fix: harden iOS replay runner prewarm (#705) | ported | (ios-runner-sync-1) | `RunnerTests+Transport.swift`: COMMAND_ACCEPTED / COMMAND_COMPLETED / COMMAND_FAILED NSLog entries; daemon/client prewarm changes n/a |
| `aa741b47` | fix: recover depth-limited iOS snapshots after AX failures (#706) | ported | (ios-runner-sync-1) | `+Snapshot.swift`: depth-limited AX recovery retry logic |
| `31ce5903` | feat: add replay test sharding (#707) | n/a | — | Replay sharding (out of scope) |
| `c89719f7` | fix: decode escaped selector values (#711) | ported | (0.18.0 gap) | `selectors/parse.dart`: `_simpleEscapeReplacements` map (`\n \t \r \\`), `\uXXXX` unicode escape; 4 unit tests in `parse_test.dart`. Port of `selectors-parse.ts` escape logic. |
| `35f54a86` | fix: resolve Maestro taps from regular snapshots (#709) | ported | (ios-runner-sync-1) | `+Snapshot.swift` updated (Maestro snapshot compat); `RunnerTests.swift` removes `maxSnapshotElements`/`fastSnapshotLimit` — NOT ported (Dart keeps these); Maestro daemon parts skipped |
| `fe728814` | 0.17.0 | n/a | — | Version bump |
| `c2b29d56` | fix: stabilize Maestro replay on iOS (#713) | skipped | — | Maestro (out of scope) |
| `49e59d65` | feat: record replay test videos (#712) | skipped | — | Replay test harness; Dart has own recording |
| `39e46825` | refactor: deepen runner disposal (#714) | n/a | — | Daemon runner-session lifecycle |
| `500f4f30` | refactor: deepen replay test attempt module (#715) | n/a | — | Daemon replay internals |
| `16312d07` | fix: use XCTest drag for iOS swipes (#716) | ported | (ios-runner-sync-1) | `RunnerTests+CommandExecution.swift`: synthesized swipe now routes to coordinate drag; daemon dispatch/series changes n/a |
| `1de7e73e` | refactor(types): consolidate duplicated types (#717) | n/a | — | TS type consolidation |
| `22fba871` | feat: add shutdown command (#718) | n/a | — | Daemon shutdown; Dart port already has shutdown |
| `0f7187f5` | fix: scope source daemon state by worktree (#719) | n/a | — | Daemon state dir |
| `ab202681` | refactor(types): tuple ownership, LogBackend rename (#720) | n/a | — | TS type refactor |
| `a544dc15` | refactor(types): NormalizedRect/NormalizedPoint aliases (#721) | n/a | — | TS type aliases |
| `64557755` | ci: enforce lint and formatting (#732) | n/a | — | CI |
| `4f95ca88` | fix(daemon): timing-safe token comparison, daemon.json hardening (#731) | n/a | — | Daemon security; no Dart equivalent |
| `8baeb367` | docs: document daemon trust model (#733) | n/a | — | Docs |
| `b8172e3d` | perf(daemon): offload PNG decode to worker thread (#734) | n/a | — | Daemon worker thread |
| `a7efcd46` | chore(fallow): align local runs with CI diff gate (#735) | n/a | — | TS tooling |
| `aa8a3500` | test(maestro): cover runtime target resolution (#736) | skipped | — | Maestro (out of scope) |
| `87d6d0ee` | test: cover artifact transfer characterization (#740) | n/a | — | Daemon artifact tests |
| `b1d62a36` | test: cover daemon-client lifecycle characterization (#739) | n/a | — | Daemon lifecycle tests |
| `69d296cd` | test: cover daemon HTTP server edge cases (#738) | n/a | — | Daemon HTTP tests |
| `963ffc25` | refactor: move daemon-shared contracts out of commands (#741) | n/a | — | Daemon refactor |
| `a0522c7b` | docs: document issue label workflow (#742) | n/a | — | Docs |
| `712b675c` | refactor: extract daemon artifact client (#744) | n/a | — | Daemon artifact client |
| `b30292d8` | refactor(types): deepen type consolidation (#743) | n/a | — | TS type refactor |
| `582710e0` | docs: add agent tightening pass guidance (#746) | n/a | — | Docs |
| `2dea65e7` | fix: render optimized MCP command output by default (#748) | n/a | — | MCP |
| `c3224950` | test: cover least-tested parsing modules (#749) | n/a | — | TS test coverage |
| `b2e4ace1` | fix: focus booted iOS simulators with Device Hub (#750) | n/a | — | Device Hub; daemon-managed simulator focus |
| `a89d68dd` | feat: export replays to maestro yaml (#751) | skipped | — | Maestro/replay (out of scope) |
| `f661efd2` | refactor: extract daemon progress parsing (#753) | n/a | — | Daemon internals |
| `19cdec10` | 0.17.2 | n/a | — | Version bump |
| `5462d516` | chore(daemon): takeover notice, dev state-dir pruning (#754) | n/a | — | Daemon state |
| `ded6a167` | fix: use full-screen reference frame for recording touch overlays (#765) | n/a | — | Daemon recording overlay; no Dart equivalent |
| `462db525` | perf(ios): skip runner uptime preflight after recent healthy mutations (#763) | n/a | — | Daemon runner-session preflight; already ported via `dfd5c712` |
| `3780ca6e` | perf(ios): fuse scroll frame resolution and drag into one runner command (#760) | ported | (ios-runner-sync-1) | Swift `scroll` runner command (fused frame+drag); daemon plumbing n/a |
| `e6e2baf3` | perf(ios): add lifecycle-safe runner sequence command for hot press series (#764) | ported | (ios-runner-sync-1) | Swift `sequence` runner command; daemon/dispatch layer n/a |
| `93f104aa` | fix: make Device Hub simulator launch opt-in (#766) | n/a | — | Device Hub |
| `c3d50f7a` | docs: add agent PR readiness checklist (#769) | n/a | — | Docs |
| `bef5cf32` | chore: lint raw child process imports (#770) | n/a | — | TS tooling |
| `3a02e514` | refactor(ios): consolidate series batching onto sequence command (#768) | ported | (ios-runner-sync-1) | Swift wire changes synced (doubleTap sequence step, tapSeries/dragSeries kept for wire compat with annotation); daemon retirement of sender functions n/a |
| `86941579` | perf(ios): anchor recording gesture clock from runner response stamps (#762) | ported | (ios-runner-sync-1) | `stampingCurrentUptimeMs` extension; `+CommandExecution`/`+CommandJournal`/`+Models`/`+Transport` updated; daemon record-trace anchoring n/a |
| `f8704f46` | feat: add Apple xctrace perf profiling (#755) | n/a | — | Daemon perf profiling; Dart has own `perf_xml.dart` harness |
| `a35c444d` | feat: add perf memory diagnostics (#759) | n/a | — | Daemon memory perf; out of scope |
| `cba020de` | fix: add iOS private AX snapshot fallback (#758) | ported | (ios-runner-sync-1) | New `RunnerAXSnapshotBridge.h/.m` (ObjC private AX API bridge) + `RunnerTests+AXSnapshotFallback.swift` + bridging header updated |
| `dfc5dba0` | refactor: split daemon client facade (#773) | n/a | — | Daemon client refactor |
| `3f6363c9` | fix: route replay path commands correctly (#778) | n/a | — | Replay routing (daemon + Maestro) |
| `3b94b364` | docs: add JPMorgan Chase to readme users (#782) | n/a | — | Docs |
| `60e4fe01` | docs: narrow delay-ms text entry guidance (#781) | n/a | — | Docs |
| `0425df2b` | refactor: bundle snapshot capture annotations (#777) | n/a | — | Daemon snapshot annotation refactor |
| `385c1dd6` | fix(daemon): use snapshot quality for sparse handling (#779) | n/a | — | Daemon sparse snapshot handling |
| `fa8cce37` | refactor(ios): snapshot capture plans with a structured quality verdict (#783) | ported | (ios-runner-sync-1) | New `RunnerTests+SnapshotCapturePlan.swift` (SnapshotQuality, SnapshotBackendKind, runSnapshotCapturePlan chain); major `+Snapshot` update; daemon snapshot pipeline n/a |
| `931cbba1` | refactor(ios): share snapshot filter predicates (#780) | ported | (ios-runner-sync-1) | New `RunnerTests+FlatSnapshotFiltering.swift` (FlatSnapshotFilterNode/Decision); `+AXSnapshotFallback` and `+Snapshot` updated to share predicates |
| `fa1c1d55` | refactor: localize command surface modules (#772) | n/a | — | Daemon command surface refactor |
| `48c121d5` | feat: add debug symbols workflow (#756) | n/a | — | Debug symbols (out of scope) |
| `f0d1674c` | feat: add Android native perf profiling (#757) | n/a | — | Android native perf; Dart port out of scope |
| `c7c9db74` | refactor: split Android native perf collector (#788) | n/a | — | Android native perf collector |
| `1da6fd51` | refactor: split debug symbols workflow modules (#787) | n/a | — | Debug symbols |
| `c9255639` | fix: avoid focusing booted iOS simulators (#790) | n/a | — | Device Hub simulator focus |
| `4142daa0` | docs: update internal agent guidance (#789) | n/a | — | Docs |
| `5c83fe4e` | fix: improve daemon diagnostics and remove compact snapshots (#786) | ported | (ios-runner-sync-1) | Swift `compact` flag made no-op in `+Models`/`+AXSnapshotFallback`/`+CommandExecution`/`+FlatSnapshotFiltering`/`+Snapshot`; Dart port retains `compact` field for wire compat (no-op, default false); daemon diagnostics n/a |
| `dd5c0be0` | fix: relax Android snapshot helper session timeout (#796) | n/a | — | Daemon persistent helper session |
| `96534e86` | fix: stream replay suite progress (#795) | skipped | — | Replay progress streaming (out of scope) |
| `4f0886d1` | fix: improve iOS runner crash diagnostics (#793) | ported | (0.18.0 gap) | New `runner_failure_diagnostics.dart`: `enrichRunnerFailureFromLog` reads the runner log tail (64 KB) and reclassifies AX-runtime/CoreText + target-app crashes to `IOS_TARGET_APP_CRASH` with an actionable hint + `runnerFailureReason`; wired into `ios_backend.dart` `_sendOrThrow`. New `AppErrorCodes.iosTargetAppCrash`. 4 unit tests. |
| `8de4dddd` | fix: tighten ios runner crash classification (#797) | ported | (0.18.0 gap) | `runner_failure_diagnostics.dart`: tightened regexes for AX crash patterns; co-ported with `4f0886d1` |
| `c4950a94` | fix: detect disabled Developer Tools mode for iOS runner (#792) | ported | (0.18.0 gap) | `runner_client.dart`: `_verifyDeveloperModeForIosRunner` runs `DevToolsSecurity -status` (allowFailure, 2s timeout) as a preflight in `launch()` before build/launch; when output matches "developer mode is currently disabled" throws `AppError(COMMAND_FAILED, "Developer mode is disabled for Apple development tools")` with a `sudo DevToolsSecurity -enable` hint + `devToolsSecurityStatus` detail. **Verified live on iOS sim** (runner correctly blocked with the hint). Dropped: the disposal-side `simctl terminate` of stale simulator runner apps (daemon-cleanup specific). |
| `1ce2e971` | 0.17.3 | n/a | — | Version bump |
| `945a780c` | fix: stabilize iOS runner gestures (#800) | ported | (ios-runner-sync-1) | `+AXSnapshotFallback`, `+CommandExecution`, `+Models`, `+SequenceExecution`, `+Snapshot` updated; dispatch/interactions.ts changes n/a |
| `98376b93` | fix: report snapshot timing diagnostics (#798) | n/a | — | Daemon snapshot timing |
| `0034a767` | fix: align Maestro test discovery order (#801) | skipped | — | Maestro (out of scope) |
| `778349a9` | fix: stabilize Android Maestro replay reliability (#799) | skipped | — | Maestro (out of scope) |
| `991f4c70` | fix: match Maestro directory test order (#802) | skipped | — | Maestro (out of scope) |
| `71db11b7` | 0.17.4 | n/a | — | Version bump |
| `93a69981` | fix: rotate synthesized iOS taps into native screen space (#804) | ported | (ios-runner-sync-1) | `RunnerSynthesizedGesture.h/.m`: `interfaceOrientationForApplication:` + rotation math; `+Interaction`: coordinate rotation for synthesized tap/transform |
| `a6bb8653` | fix: stabilize Android Maestro replay interactions (#805) | skipped | — | Maestro (out of scope) |
| `9e165114` | perf: optimize rslib startup build (#803) | n/a | — | TS build tooling |
| `204be34d` | 0.17.5 | n/a | — | Version bump |
| `0b499f22` | chore: update stale callstackincubator references | n/a | — | Docs/chore |
| `350cd0c1` | feat(ios): support external xctest runner artifact (#806) | ported | (0.18.0 gap) | New CLI flags `--ios-xctestrun-file` / `--ios-xctest-derived-data-path` / `--ios-xctest-env-dir` (base_command). Ambient `IosRunnerLaunchOverrides` consumed by `runner_client.dart` `launch()`: when an external `.xctestrun` is set, use it directly + skip the build/cache path entirely (trusts a CI-signed artifact as-is); products dir defaults to the artifact's dir or the derived-data override; `prepareXctestrunWithEnv` gained an `outputDir` so the env-injected copy can land in a writable scratch dir for read-only artifacts. Verified live on sim (external runner used w/o rebuild, env-dir written, missing-file → INVALID_ARGS). 3 unit tests. Note: the Dart port already supported a prebuilt products dir via `AGENT_DEVICE_IOS_RUNNER_BUILD_DIR`; these flags add file-level + read-only-artifact ergonomics for CI. |
| `feb5309e` | fix: classify external xctest runner flags (#810) | n/a | — | Daemon xctest runner flags |
| `d14dfab4` | fix(ios): support no-op xctest runner startup (#807) | skipped | — | `NOOP_STARTUP` guard in `RunnerTests.swift`; Dart port keeps its own `RunnerTests.swift` (BSD socket server, `fastSnapshotLimit`, `maxSnapshotElements`); no-op path not needed in daemon-less port |
| `d29b86d7` | fix: report maestro ios runner setup failures (#809) | skipped | — | Maestro (out of scope) |
| `afd41302` | feat: improve maestro test reporter (#811) | skipped | — | Maestro (out of scope) |
| `f9a9662f` | 0.17.6 | n/a | — | Version bump |
| `188715b4` | feat: add web platform vocabulary (#824) | n/a | — | Web platform |
| `833479e0` | feat: add semantic web provider seam (#825) | n/a | — | Web platform |
| `73dc7f88` | feat(recording): align quality and max-size controls (#816) | ported | (ios-runner-sync-1) | `recording-overlay.swift`: `--quality medium|high` + `ExportQuality` enum; `recording-resize.swift`: `quality: Int` replaces `maxSize: Int`; daemon/CLI flags n/a; `RunnerTests+ScreenRecorder.swift` NOT synced (Dart uses `quality: Int?` not `maxSize:`, already a prior deviation) |
| `87a6ac7c` | feat: bridge web provider to agent-browser (#826) | n/a | — | Web platform |
| `bc5726e8` | test: cover web provider scenario (#827) | n/a | — | Web platform |
| `cb28f686` | fix: align web snapshot and capability support (#828) | n/a | — | Web platform |
| `47fadf69` | fix: clean daemon-owned ios runner leases (#829) | n/a | — | Daemon runner lease management |
| `d3955d51` | chore: remove test-only dead exports (#836) | n/a | — | TS exports |
| `3ac96d21` | fix: preserve web backend setup hint (#835) | n/a | — | Web platform |
| `d05cfc72` | feat: manage web backend setup (#833) | n/a | — | Web platform |
| `c6fd3dc9` | test: add live web platform smoke (#832) | n/a | — | Web platform |
| `02481e8b` | docs: document minimal web support (#831) | n/a | — | Docs |
| `f2dd620f` | docs: mention web in README tagline (#837) | n/a | — | Docs |
| `467e174b` | test: improve SkillGym guidance coverage (#839) | n/a | — | skillgym |
| `d7beb527` | feat: expose web network dump through agent-browser (#838) | n/a | — | Web platform |
| `a8fb2a37` | docs: document multi-worktree Metro workflow (#841) | n/a | — | Docs |
| `e6b40dc6` | docs: simplify CLI help flag scoping (#840) | n/a | — | Docs |
| `b3b8c90f` | 0.17.7 | n/a | — | Version bump |
| `bf8d952e` | fix: speed up web snapshots (#842) | n/a | — | Web platform |
| `c2814842` | fix: use native web ref interactions (#843) | n/a | — | Web platform |
| `19f73c8f` | ci: fix iOS simulator boot timeout (#845) | n/a | — | CI |
| `d47cd301` | feat: add agent-device proxy command (#844) | n/a | — | Daemon proxy |
| `51eaa7fd` | 0.17.8 | n/a | — | Version bump |
| `180a74b6` | refactor: share daemon HTTP contract helpers (#846) | n/a | — | Daemon HTTP |
| `2e02f767` | fix: validate batch steps through command contracts (#848) | n/a | — | Daemon batch validation |
| `7739b71a` | refactor: centralize command family facets (#849) | n/a | — | Daemon command facets |
| `0b840d95` | chore: add worktree include config (#853) | n/a | — | Dev tooling |
| `091c7dbc` | refactor: deepen runner command traits (#847) | n/a | — | Daemon command traits refactor |
| `5a84507b` | docs: add selector capture reliability contract (#858) | n/a | — | Docs |
| `b2030289` | refactor: migrate command families to facets (#854) | n/a | — | Daemon facets |
| `a179e1e0` | docs: add README articles and videos (#855) | n/a | — | Docs |
| `8a348210` | test: guard Maestro swipe stabilization flag (#860) | skipped | — | Maestro (out of scope) |
| `e97e2542` | refactor: unify selector capture runtime (#857) | n/a | — | Daemon selector capture |
| `c9748a9a` | refactor: extract daemon selector capture runtime (#859) | n/a | — | Daemon internals |
| `09339e12` | fix: honor scroll duration across platform plumbing (#866) | ported | (0.18.0 gap) | `scroll_gesture.dart`: `normalizeScrollDurationMs` validator (0–10000) + `scrollDurationMaxMs`. Threaded `durationMs` through `BackendScrollOptions` → runtime `scroll()` → CLI `--duration-ms` flag. iOS `ios_backend.dart` scroll: sends the synthesized `drag` (`synthesized:true` + `durationMs`) only when a duration is requested, else native drag (mirrors upstream fused `.scroll`). Android `scrollAndroid`: `durationMs` param → `input swipe` (default 300) + returned. `RunnerTests+CommandExecution.swift` `.scroll` durationMs wiring synced. **Verified live on Android** (default 300, honors 120, rejects >10000). 4 unit tests. daemon/client scroll-command refactor n/a. |
| `ba825d8d` | fix: use desktop scroll events on macOS (#863) | ported | (ios-runner-sync-1) | Swift `desktopScroll` runner command (`desktopScrollAt`, `desktopScrollWheelDeltaEvents`); `+Models`/`+CommandExecution`/`+Interaction`/`+CommandJournal`/`+ScrollGesture` updated; macOS daemon plumbing n/a |
| `5be101c2` | fix: clean up Android snapshot helper sessions (#862) | n/a | — | Daemon persistent helper session management; Dart port runs helper APK per-command |
| `d8e6bb7a` | fix: add web viewport control and screenshot aliases (#865) | n/a | — | Web platform |
| `63e68cd5` | 0.17.9 | n/a | — | Version bump |
| `ced61ce3` | fix: disable nested sandboxing for ios runner builds (#869) | n/a | — | iOS runner build script; Dart port uses `make build-ios-runner` which has no nested sandbox issue |
| `f253d50a` | fix: resolve web find locators (#870) | n/a | — | Web platform |
| `fa1b0b7c` | docs: configure agent skill conventions (#871) | n/a | — | Docs |
| `19417f0a` | fix: avoid copying pnpm node_modules into worktrees (#872) | n/a | — | Dev tooling |
| `c142514c` | docs: clarify agent-device QA mental model (#875) | n/a | — | Docs |
| `56d8e390` | test: migrate Android recording sizing coverage (#876) | n/a | — | TS test coverage |
| `24cb2b62` | fix: refine Apple provider pressure reporting (#877) | n/a | — | Daemon runner pressure reporting |
| `98c0b1d3` | test: migrate test app to expo dev client (#881) | n/a | — | RN test app |
| `8c49d54f` | fix: clarify proxy runner ownership (#882) | n/a | — | Daemon proxy |
| `be1e1c99` | feat: add cdp command agent-cdp passthrough (#873) | n/a | — | CDP/agent-cdp |
| `053bbace` | 0.17.10 | n/a | — | Version bump |
| `8c2b1ade` | feat: support agent-cdp remote bridge sessions (#878) | n/a | — | CDP |
| `c16a8d5e` | docs: clarify agent-device help entrypoint (#884) | n/a | — | Docs |
| `2d6fc982` | refactor: tighten daemon output helpers (#892) | n/a | — | Daemon output |
| `a9069692` | refactor: model recording backends (#893) | n/a | — | Daemon recording backends |
| `8f92572a` | feat: expose web screen recording (#891) | n/a | — | Web platform |
| `a8223253` | feat: add integrated device leasing (#890) | n/a | — | Daemon device leasing |
| `78ca8fb9` | 0.18.0 | n/a | — | Version bump |
| `93d5275e` | refactor: type-safe recording backends + exhaustive capability gating (#894) | n/a | — | Daemon recording backends |
| `5a676235` | perf: reduce Apple runner build overhead (#898) | ported | (ios-runner-sync-1) | `+Interaction.swift`: `#if os(iOS)` / `#else` guard for `pressKeyboardReturn` non-iOS path; `AgentDeviceRunnerApp.m` not ported (Dart keeps `.swift` host app); `project.pbxproj` not modified (PBXFileSystemSynchronizedRootGroup auto-sync); build scripts n/a |
| `d16f01cb` | refactor: derive platform allow-lists from canonical device tuples (#895) | n/a | — | TS type refactor |
| `22a9b2fe` | feat: add AppleOS discriminant to the device model (#896) | n/a | — | TS device model; Dart has own device model |
| `cd00ff86` | refactor: validate JSON-RPC at the MCP/HTTP boundary (#897) | n/a | — | MCP/daemon |
| `fc81c9ed` | refactor: derive replay metadata platforms from canonical selectors (#899) | n/a | — | Daemon replay |
| `9b79e210` | refactor: remove shallow re-export modules and a dead branch (#901) | n/a | — | TS exports |
| `fbec5cf6` | refactor: collapse duplicated batch-step validation to one schema (#902) | n/a | — | Daemon batch |
| `d291e4c5` | refactor: extract shared Android instrumentation-helper (#903) | n/a | — | Daemon Android helper |
| `91d1b4c1` | refactor: dedup daemon handler capability/session/recordAction boilerplate (#904) | n/a | — | Daemon handlers |
| `29e19b8e` | docs: add ADR 0008 (command descriptor) + ADR 0009 (Apple consolidation) (#905) | n/a | — | Docs |
| `4648051b` | feat: command-descriptor registry (additive, parity-tested) — Phase 1 step 1 (#906) | n/a | — | Daemon command descriptor registry; no Dart equivalent |
| `305594f6` | fix: avoid unsafe iOS keyboard dismissal (#957) | ported | `276d432` | `RunnerTests+Interaction.swift`: removed `keyboard.swipeDown()` early-dismiss path; removed `tapKeyboardReturnControl(allowCoordinateFallback:true)` fallback; widened toolbar search from `app.toolbars.buttons` to `app.descendants(matching: .button)`; dropped `allowCoordinateFallback` param + coordinate fallback body from `tapKeyboardReturnControl`. `RunnerTests+CommandExecution.swift` + `ios-runner/RUNNER_PROTOCOL.md`: error message updated to "Unable to dismiss the iOS keyboard without a safe native dismiss control". TS/docs/CLI changes n/a. No Dart lib changes needed (no old message in Dart). |
| `657442260` | fix: reduce iOS runner keepalive log noise (#1017) | n/a | — | Dart runner never ported the XCTest idle-keepalive timer (`testCommand` was restructured around the BSD-socket path before it landed), so there is no keepalive log noise to reduce. Upstream path renamed `ios-runner/` → `apple-runner/`; Dart mirror still at `ios-runner/`. |
| `9dc07cc56` | perf: reuse Apple runner cache across version bumps (#900) | ported | `276d432` + `5cdda51` | **Slice 1 (cache keying):** `comparableEquals` in `runner_build_cache.dart` no longer compares `packageVersion` — cache survives version bumps as long as `schemaVersion`, `sourceFingerprint`, and `deviceKind` match. 2 new tests (version-agnostic reuse, schemaVersion invalidation). **Slice 2 (runner slimming):** deleted `AgentDeviceRunner/Assets.xcassets` (AccentColor.colorset, AppIcon.appiconset, Logo.imageset, PoweredBy.imageset) and `AgentDeviceRunnerUITests/Assets.xcassets` (AppIcon.appiconset); removed `ASSETCATALOG_COMPILER_GENERATE_SWIFT_ASSET_SYMBOL_EXTENSIONS` from 2 project-level configs and `ASSETCATALOG_COMPILER_APPICON_NAME`/`ASSETCATALOG_COMPILER_GLOBAL_ACCENT_COLOR_NAME` from 4 target configs in `project.pbxproj`; removed `hasContent` computed property from `FlatSnapshotFilterNode`; removed `repairReadinessTimeout` from `TextEntryTiming`. **Slice 3 (unit-test gating):** added `#if AGENT_DEVICE_RUNNER_UNIT_TESTS` / `#endif` guards around Swift unit-test sections in `RunnerTests+AXSnapshotFallback.swift`, `+CommandExecution.swift`, `+CommandJournal.swift`, `+FlatSnapshotFiltering.swift`, `+Interaction.swift`, `+ScrollGesture.swift`, `+SequenceExecution.swift`, `+Snapshot.swift`, `+SnapshotCapturePlan.swift` (9 files). **Slice 4 (prewarm/progress/concrete simulator):** n/a — all daemon-only (prewarm during boot, `emitRequestProgress` build message, concrete simulator destination); Dart port has no daemon layer. Build script Swift-flag split (`RUNNER_RUNTIME_SWIFT_FLAGS`/`RUNNER_UNIT_TEST_SWIFT_FLAGS`) not ported — Makefile `build-ios-runner` target does not pass `OTHER_SWIFT_FLAGS`. |
| `903a35624` | fix: extend iOS physical install timeout (#964) | ported | `e04cf77` | Added `iosDeviceInstallTimeoutMs = 180000` and `iosDevicectlTimeoutMs = 60000` constants to `devicectl.dart`; `installIosDeviceApp` now uses `iosDeviceInstallTimeoutMs` (was an unnamed hardcoded 180000). Kept 180s rather than upstream's platform-layer 120s: upstream runs the 120s exec timeout under a 180s daemon-client install budget (`INSTALL_REQUEST_TIMEOUT_MS`); daemon-less, the exec timeout is the whole budget, so 180s preserves upstream's end-to-end behavior. `runIosDevicectl` already took a named `timeoutMs` param so no signature change needed (upstream added an `options` wrapper object, but Dart's named-param shape is equivalent). `daemon-client.ts` `INSTALL_REQUEST_TIMEOUT_MS` not ported — Dart has no daemon layer. 2 new constant-value unit tests in `devicectl_parse_test.dart`. |
| `996d93e97` | perf: cut iOS open --relaunch from 11s to 2.85s (#1010) | ported | `dc186ba` | **Piece 1 (runner hot on simulator relaunch):** `IosBackend.openApp` now handles `options.relaunch == true` — simulator path: closes app via `closeIosApp` (no runner teardown) + seeds booted memo; device path: calls `shutdownRunnerFor` + `terminateIosDeviceProcess` (conservative teardown preserved). Prior to this, `relaunch` was present in `BackendOpenOptions` but entirely unused in `IosBackend`. **Piece 2 (5s booted memo in devices.dart):** Added `simulatorBootedMemoTtlMs = 5000`, `readSimulatorBootedMemo`, `markSimulatorBooted`, `clearSimulatorBootedMemo`, `resetSimulatorBootedMemoForTests` to `devices.dart`. `listAppleSimulators` seeds the memo for any Booted simulator it sees. Clock seam `_nowMsOverride` makes the memo testable without `fake_async`. 8 new unit tests in `simulator_booted_memo_test.dart`. **Piece 3 (skip session-device re-resolve):** N/A — daemon-only (`refreshSessionDeviceIfNeeded`/`getRunnerSessionSnapshot`); Dart port has no daemon session layer and `_resolveKind` is already cached per-process via `_IosKindCache`. **Piece 4 (tvOS provider test update):** N/A — no matching integration test in Dart port. **Drift:** `fake_async` added as dev dep (was already transitive). Dart MVP omits `simulatorSetPath` from memo key (single default set). Follow-up in same port: CLI `open` gained the `--relaunch` flag (was backend/replay-only — CLI users could not reach the relaunch path); unused `fake_async` dev dep removed. Validation follow-up: `readSimulatorBootedMemo` had zero consumers (memo was seeded but never read); wired it into `_resolveKind` (fresh Booted memo ⇒ simulator, skip `simctl list` + `devicectl list`). Verified live: `open --relaunch` now spawns exactly one `simctl list devices -j` (was two), 0.54s wall. |
| `6dc0aa550` | perf: collapse iOS simulator relaunch into one simctl launch call (#1024) | ported | `dc186ba` | **`app_lifecycle.dart`:** Added `terminateRunningApp` param to `openIosApp` and private `_buildIosSimulatorLaunchArgs`; `--terminate-running-process` flag inserted after `--console-pty` (if any) but before the device ID, matching upstream flag ordering. Exposed `buildIosSimulatorLaunchArgs` as `@visibleForTesting` to allow flag-ordering unit tests without running simctl. **`ios_backend.dart` (`openApp`):** Added `collapseSimulatorRelaunch` boolean (true when `relaunch==true` and kind is `simulator`); simulator relaunch now skips the separate `closeIosApp` call and instead passes `terminateRunningApp: true` to `openIosApp`. Device path unchanged (conservative teardown preserved). **Tests:** 7 new tests in `test/platforms/ios/app_lifecycle_launch_args_test.dart` covering plain launch, `--console-pty`, `launchArgs`, `terminateRunningApp`, flag ordering, and combined flags. **Drift:** Upstream has three exclusions — URL relaunches, `--clear-app-state`, and `openPositionals.length === 1`; the Dart backend layer has no URL-open path and no `clearAppState` option, so the fast path applies to all simulator relaunches without extra guards. The URL-relaunch regression test and `--clear-app-state` test from upstream have no Dart equivalent (both conditions are structurally impossible in the Dart port). `terminateRunningApp` threading through dispatch-context → interactor is n/a (no daemon layer). CAUTION for future work: if/when iOS URL opens land (`simctl openurl`), the collapse MUST exclude URL relaunches (upstream review finding: a deep-link open never launches the app, so the terminate has nothing to attach to — keep close-then-open there). |
| `60d1bd176` | fix: respect prepare timeout for runner health checks (#967) | n/a | — | No prepare-deadline concept in the daemon-less port. Upstream's fix threads a shared `Deadline` through the multi-phase `prepareIosRunner` daemon handler (ensureRunnerSession → health check uptime call → optional rebuild), so each phase's timeout becomes `min(phase_timeout, remaining_budget)`. The Dart port has no daemon request envelope, no `PREPARE_REQUEST_TIMEOUT_MS`, no `prepareIosRunner` function, and no `buildTimeoutMs`/`healthTimeoutMs`/`startupTimeoutMs` parameters — `_runner()` in `ios_backend.dart` calls `IosRunnerClient.launch()` with a single fixed `startupTimeout` and uses `isAlive` probes on cached sessions. There is no overall prepare budget to thread. The daemon-side constants extracted to `request-timeouts.ts` and the `session.ts` refactor are also n/a. |
| `505e2af12` | feat: add opt-in exec command diagnostics (#1019) | ported | `8e3376c` | `diagnostics.dart`: added `flushOnSuccess` to `DiagnosticsScopeOptions`/`_DiagnosticsScope`/`DiagnosticsMetadata`; added `DiagnosticsScopeUpdate` + `updateDiagnosticsScope()`; `flushDiagnosticsToSessionFile` flushes when `flushOnSuccess` is true. `exec.dart`: added `_execDiagnosticArgLimit=6`, `_ExecTraceContext` class, `_createExecTraceContext()`/`_createDisabledExecTraceContext()`, `_emitExecCommandDiagnostic()`, `_parseBooleanLiteral()` helper; `runCmd`/`runCmdStreaming` wired to emit foreground completion via `_runCmdAsync`; `runCmdBackground` emits spawn + completion events. `exec_test.dart`: 3 new tests (debug-scope foreground trace, background bounded trace, silent-when-not-enabled). Drift: Dart `Platform.environment` is read-only so the "silent" test uses scope absence rather than env var deletion; `AGENT_DEVICE_EXEC_TRACE` env var path is present but cannot be toggled in tests without a process restart — the background-trace test uses a `debug: true` scope instead of the env var. `cli-help.ts` documentation string change not ported (no CLI help layer in Dart). `args.test.ts` help-text assertion not ported (same reason). Validation follow-up: wired a root diagnostics scope into `run_cli.dart` (`withDiagnosticsScope` around command execution + flush in `finally`) — without it no CLI invocation ever had a scope, so exec tracing (and all pre-existing `emitDiagnostic` sites) were silently dead in the CLI. Verified live: `AGENT_DEVICE_EXEC_TRACE=1` writes exec_command NDJSON to `~/.agent-device/logs/<session>/<utc-day>/`. |
| `b67053e97` | fix: bound retained iOS runner lifetime with an idle stop (#1025) | ported | `dc186ba` | Adapted for daemon-less port. Upstream uses an in-process `setTimeout` timer (5 min, `AGENT_DEVICE_IOS_RUNNER_IDLE_STOP_MS` override); daemon-less port has no long-lived process to run a timer, so enforcement happens at reconnect time inside `_liveRunner` in `ios_backend.dart`: before adopting a retained runner (in-proc cache or disk record), `isRunnerSessionIdleExpired` checks if `lastSuccessAt` is older than the idle bound — if so, stop/kill the runner and clear the record rather than adopting it (mirroring the upstream timer's outcome). `lastSuccessAt` already round-trips through the runner record JSON as `lastSuccessfulRunnerResponseAtMs` (from `dfd5c712` port). Added `runnerRetainedIdleStopDefault` (5 min, same value as upstream), `resolveRunnerIdleStopDuration` (env-var parser, accepts 0 to disable), `isRunnerSessionIdleExpired` (pure-function seam), and `_stopIdleRunner` helper to `runner_client.dart` / `ios_backend.dart`. New `_IosRunnerCache.pop` call before idle-stop ensures the in-proc cache is cleared. Idle-stop check runs BEFORE the `isAlive` probe so "too old → don't even probe" mirrors upstream's timer ordering vs the readiness preflight. 12 new unit tests in `runner_idle_stop_test.dart`. Drift: no in-process timer (daemon-less); session-close path does NOT call an equivalent of `scheduleIosRunnerIdleStop` (there is no daemon session-close handler) — enforcement is purely at next-reconnect. `cancelIosRunnerIdleStop` not needed (no timers). Review follow-up: added `_touchRunnerRecord` — the on-disk record was only written at launch (null `lastSuccessAt`), so the idle bound could never fire across invocations; each successful adoption now touches + persists the timestamp (idle bound measures the gap between CLI invocations, mirroring upstream timer reset on `ensureRunnerSession`), and launch seeds the clock. |
