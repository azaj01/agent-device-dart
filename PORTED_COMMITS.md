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
