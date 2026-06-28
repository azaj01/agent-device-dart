# Changelog

All notable changes to the Dart port of `agent-device` are documented here.
Per-upstream-commit disposition lives in [`PORTED_COMMITS.md`](./PORTED_COMMITS.md).

## 0.0.11

Closes the upstream **0.16.10 → 0.18.0** gap (179 commits triaged; see
[`PORT_GAP_0.16.10_to_0.18.0.md`](./PORT_GAP_0.16.10_to_0.18.0.md)). The bulk of
upstream churn in this window is out of scope for this mobile-only, daemon-less
port (Maestro, daemon internals, web/CDP, MCP, 0.18.0 TS refactors).

### Added

- **External / CI-signed iOS runner** — `--ios-xctestrun-file`,
  `--ios-xctest-derived-data-path`, and `--ios-xctest-env-dir` flags use a
  prebuilt `.xctestrun` artifact and skip the build entirely. The artifact is
  trusted as-is (no re-sign), and the env-injected copy can be redirected to a
  writable scratch dir for read-only artifacts. (upstream #806)
- `scroll --duration-ms` — honor a caller-provided scroll/swipe duration
  (0–10000ms) on both platforms, instead of a fixed default. (upstream #866)

### Changed

- iOS XCUITest runner Swift re-synced to upstream `4648051b` — adds the
  sequence/scroll fused runner commands, structured snapshot capture plans, a
  private-AX snapshot fallback (`RunnerAXSnapshotBridge`), shared flat-snapshot
  filtering, gesture stabilization, and synthesized-tap orientation rotation.

### Fixed

- Selector values now decode JSON-style escapes (`\n \t \r \uXXXX`, incl.
  surrogate pairs), not just escaped quotes. (upstream #711)
- iOS runner command failures caused by a crashed target app are reclassified
  to `IOS_TARGET_APP_CRASH` with an actionable hint, read from the runner log
  tail. (upstream #793, #797)
- Fail fast with an actionable hint when Developer Mode for Apple development
  tools is disabled (the runner would otherwise hang). (upstream #792)
- Block taps on covered/occluded snapshot targets via a generic geometric
  occlusion pass. (upstream #708)
- Recover Android snapshots from system-only / empty UI-automator helper
  output. (upstream #861)
