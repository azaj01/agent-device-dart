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

The port covers Phases 0–8 and 10 of the upstream feature set. Remaining:

- **Phase 9** — macOS and Linux desktop platform backends
- **Phase 11** — React Native metro integration (may become Flutter-specific)
- Daemon mode (Phase 6B) — deferred; direct execution covers all current use cases

For the full porting history and design decisions, see [`PORTING_PLAN.md`](./PORTING_PLAN.md).
