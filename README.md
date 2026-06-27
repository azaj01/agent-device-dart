# agent-device (Dart)

Dart port of [`agent-device`](https://github.com/callstackincubator/agent-device) — the device automation CLI for AI agents. Lets coding agents run real iOS and Android apps, inspect accessibility snapshots, interact with UI elements, and collect screenshots, video, logs, and performance metrics.

Ships as both:

- a **CLI** (`agent-device` / `ad`) for day-to-day shell use, and
- a **Dart library** (`package:agent_device`) you can import into any Dart / Flutter project to drive devices programmatically via `AgentDevice.open(...)`.

## Key differences from the TypeScript package

|                  | TypeScript (`agent-device`)                          | Dart (`agent_device`)                                |
| ---------------- | ---------------------------------------------------- | ---------------------------------------------------- |
| Runtime          | Node.js >= 22                                        | Dart SDK >= 3.11 or compiled binary                  |
| Install          | `npm i -g agent-device`                              | `dart pub global activate agent_device`              |
| Architecture     | Long-lived daemon process (HTTP/socket RPC)          | Direct execution per command (no daemon)             |
| Programmatic API | `createAgentDevice()` + dynamic `bindCommands`       | Typed `AgentDevice` class with concrete methods      |
| Platform support | iOS, Android, macOS, Linux, tvOS                     | iOS, Android (macOS/Linux planned)                   |
| React Native     | Metro companion, remote config, DevTools bridge      | Not ported (Flutter-native alternative planned)      |
| Native runners   | Same Swift XCUITest runner + Android snapshot helper | Same Swift XCUITest runner + Android snapshot helper |

## What's the same

- CLI surface: same subcommands, flags, JSON envelope shape, exit codes
- `.ad` replay scripts with parametrization and self-healing selectors
- Accessibility snapshot model, selector DSL, ref targeting (`@e3`)
- iOS runner protocol (auto-builds the Swift XCUITest project on first use)
- Android snapshot helper APK (auto-installs on first use)
- Video recording, log capture, CPU/memory/FPS perf sampling

## Getting started

See the [package README](./packages/agent_device/README.md) for install instructions, CLI quickstart, and library API examples.

## Porting status

The port covers Phases 0–8 and 10 of the upstream feature set, and tracks
upstream behavior through **0.18.0** (commit `4648051b`). Remaining:

- **Phase 9** — macOS and Linux desktop platform backends
- **Phase 11** — React Native metro integration (may become Flutter-specific)
- Daemon mode (Phase 6B) — deferred; direct execution covers all current use cases
- Web / `agent-browser` / `agent-cdp` — out of scope (mobile-only port)
- Maestro compatibility layer — out of scope

For the full porting history and design decisions, see [`PORTING_PLAN.md`](./PORTING_PLAN.md).
Per-upstream-commit disposition is tracked in [`PORTED_COMMITS.md`](./PORTED_COMMITS.md);
the 0.16.10 → 0.18.0 gap analysis is in [`PORT_GAP_0.16.10_to_0.18.0.md`](./PORT_GAP_0.16.10_to_0.18.0.md).

### Using a prebuilt (CI-signed) iOS runner

To skip building the XCUITest runner — e.g. in CI with a pre-signed artifact —
pass an externally built `.xctestrun`:

```
agent-device snapshot \
  --ios-xctestrun-file /path/to/Build/Products/AgentDeviceRunner_*.xctestrun \
  --ios-xctest-derived-data-path /path/to/Build/Products \
  --ios-xctest-env-dir "$RUNNER_TEMP/ad-xctest"   # writable scratch for read-only artifacts
```

The artifact is trusted as-is (no rebuild / re-sign). The legacy
`AGENT_DEVICE_IOS_RUNNER_BUILD_DIR` env override remains supported.
