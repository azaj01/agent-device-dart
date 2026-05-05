# agent-device (Dart)

Device automation CLI for AI agents to interact with iOS and Android devices. This is a Dart port of the TypeScript [`agent-device`](https://github.com/callstackincubator/agent-device) CLI.

Ships as both:

- a **CLI** (`agent-device` / `ad`) for day-to-day shell use, and
- a **Dart library** (`package:agent_device`) you can import into any Dart / Flutter project to drive devices programmatically via `AgentDevice.open(...)`.

See more in the [package README](./packages/agent_device/README.md).

---

## Porting progress - Still missing / roadmap

**Phase 9 — desktop platforms** _(not started)_

- macOS (`macos-helper` Swift binary + AX API bridge)
- Linux (`atspi-dump.py`)

**Phase 10 follow-ups** _(observability core + streaming + install is shipped)_

- Android pinch multi-touch (runner gap, not a Dart gap)
- `record --hide-touches` overlay (TS does it as an ffmpeg post-pass
  driven by the runner's gesture-event log — sizeable separate port)
- iOS install from URL sources / nested archives (TS supports trusted
  GitHub Actions + EAS artifact URLs and `.zip`/`.tar.gz` containers
  around the `.app`/`.ipa`; current Dart port handles local paths only)

**Phase 11 — React Native / metro integration** _(not started)_

- `metro.ts` / `metro-companion.ts` / `remote-config*.ts` / `remote-connection-state.ts` port (~1500 LOC of HTTP client + runtime-hint injection). Lets `.ad` scripts bootstrap against a running metro dev server so the launched app loads your current un-bundled JS.
- If the target is **Flutter apps** instead of React Native, this turns
  into a Dart-specific design (VM Service / `flutter attach` /
  hot-reload) rather than a port.

**Phase 12 — polish & release** _(in progress)_

- ✅ `dart compile exe` standalone binary (`make compile` → `dist/agent-device`)
- ✅ Shell completions: `agent-device completion bash|zsh|fish`
- ✅ pub.dev dry-run passes (MIT-licensed; `publish_to: none` stays
  in until you actually want to publish)
- Byte-for-byte CLI output diff against the Node CLI on a `.ad` corpus

For the full porting history, design decisions, and phase-by-phase
changelog see [`PORTING_PLAN.md`](./PORTING_PLAN.md).
