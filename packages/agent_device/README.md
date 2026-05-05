# agent_device

Agent-driven CLI and Dart library for mobile UI automation, accessibility snapshots, network/log/perf observability, video recording, and `.ad` replay scripts on iOS and Android.

Dart port of [`agent-device`](https://github.com/callstackincubator/agent-device) CLI.

Ships as both:

- a **CLI** (`agent-device` / `ad`) for day-to-day shell use, and
- a **Dart library** (`package:agent_device`) you can import into any Dart / Flutter project to drive devices programmatically via `AgentDevice.open(...)`.

## Install

```bash
# CLI (global activation)
dart pub global activate agent_device

# Library (add to pubspec.yaml)
dart pub add agent_device
```

The CLI installs two executables: `agent-device` and `ad` (short alias).

## How it works

`agent_device` talks to real iOS simulators/devices and Android
emulators/devices through their native toolchains:

- **iOS**: an XCUITest runner (Swift) launched via `xcodebuild
test-without-building`. Auto-built from bundled source on first use.
- **Android**: `adb` for interactions + a bundled snapshot helper APK
  (13 KB Java instrumentation) that provides multi-window accessibility
  snapshots. Auto-installed on first use.

No emulator images, test frameworks, or additional SDKs are required
beyond Xcode (iOS) and Android SDK (Android).

## CLI quickstart

```bash
# List all connected/booted devices
ad devices

# Capture the accessibility tree
ad snapshot --platform ios --serial <UDID>

# Interact
ad open com.example.myapp --platform android
ad tap 200 400
ad type "hello world"
ad click 'text="Submit"'
ad swipe 200 600 200 200

# Assertions
ad is visible 'text="Welcome"'
ad is hidden 'id=loadingSpinner'
ad wait visible 'text="Done"' --timeout 10000

# Replay an .ad script
ad replay flow.ad --platform ios

# Record video with chapter markers per step
ad replay flow.ad --record recording.mp4

# Frame perf (jank, dropped frames, percentiles)
ad perf --metric fps --platform android

# Update to the latest version
ad update
```

Every command supports `--json` for machine-readable output and
`--verbose` for diagnostic logging.

## Library usage

```dart
import 'package:agent_device/agent_device.dart';

void main() async {
  // Open a session on a connected device
  final device = await AgentDevice.open(
    backend: const IosBackend(),
    selector: const DeviceSelector(serial: 'BOOTED-UDID'),
  );

  // Launch an app and capture the UI tree
  await device.openApp('com.example.myapp');
  final snap = await device.snapshot();
  for (final node in (snap.nodes ?? []).whereType<SnapshotNode>()) {
    print('@${node.ref} [${node.type}] ${node.label ?? ""}');
  }

  // Interact via selectors
  await device.tapTarget(
    InteractionTarget.selector('text="Sign In"'),
  );
  await device.typeText('user@example.com');

  // Assert visibility with viewport-aware checks
  final result = await device.isPredicate(
    'visible',
    InteractionTarget.selector('id=welcomeBanner'),
  );
  print('visible: ${result.pass}');

  // Record video with chapters (for test suites)
  final recorder = TestRecorder(device, '/tmp/test.mp4');
  await recorder.start();
  recorder.chapter('login flow');
  // ... test steps ...
  await recorder.stop(); // injects MP4 chapters via ffmpeg

  await device.close();
}
```

`AgentDevice` is a typed façade over the abstract `Backend` — instead of TS's dynamic `bindCommands`, Dart gets concrete methods on the façade and `IosBackend` / `AndroidBackend` subclasses fill in what each platform supports. Everything else inherits an `UNSUPPORTED_OPERATION` default so partial support is honest.

### Key classes

| Class                           | Purpose                                                          |
| ------------------------------- | ---------------------------------------------------------------- |
| `AgentDevice`                   | Main facade — open sessions, capture snapshots, interact, assert |
| `IosBackend` / `AndroidBackend` | Platform implementations                                         |
| `DeviceSelector`                | Filter devices by serial, name, or platform                      |
| `InteractionTarget`             | Target a node by `@ref`, selector expression, or x/y coordinates |
| `TestRecorder`                  | Record video with chapter markers in Dart test files             |
| `BackendSnapshotResult`         | Snapshot result with typed node tree                             |

### Selector DSL

Target nodes using a concise selector language:

```dart
// By accessibility identifier
InteractionTarget.selector('id=loginButton')

// By label text (quote spaces)
InteractionTarget.selector('text="Sign In"')

// Compound selectors
InteractionTarget.selector('role=button text="Submit"')

// Fallback chains (try first, then second)
InteractionTarget.selector('id=submit || text="Submit"')

// By @ref from a previous snapshot
InteractionTarget.ref('@e5')
```

## .ad replay scripts

Text-based scripts for repeatable UI flows:

```
context platform=ios
open com.example.myapp
snapshot -i
click 'text="Get Started"'
wait visible 'id=onboardingComplete' 10000
type "Jane Doe"
screenshot ./screenshots/onboarding.png
```

Run with `ad replay flow.ad` or `ad test flows/` (runs all `.ad` files in a directory).

Supported actions in the replay runner: `open`, `close`, `home`, `back`, `app-switcher`, `rotate`, `type`, `swipe`, `scroll`, `longpress`, `pinch`, `click`/`press`/`tap`, `fill`, `find`, `get`, `is`, `wait`, `snapshot`, `screenshot`, `record start/stop`, `appstate`, `apps`, `clipboard`, `keyboard`, `settings`, `alert`, `boot`, `install`, `push`, `trigger-app-event`. Selector-backed steps (`click`/`fill`/`get`/`is`/`wait`) can auto-heal with `--replay-update`: on failure a fresh snapshot is taken, the selector is re-resolved against the current tree, the step retried, and the script file rewritten with the healed selector.

#### Parameters

`.ad` scripts support `${VAR}` interpolation in positional args, flag
values, and runtime hints. Sources, in **decreasing** precedence:

1. `agent-device replay -e KEY=VALUE` (or `--env KEY=VALUE`, repeatable)
2. `AD_VAR_*` shell env (e.g. `AD_VAR_APP=prod` exposes `${APP}`)
3. File-local `env KEY=VALUE` directives at the top of the `.ad` file
4. Built-ins: `${AD_PLATFORM}`, `${AD_SESSION}`, `${AD_FILENAME}`,
   `${AD_DEVICE}`, `${AD_ARTIFACTS}`

Use `${VAR:-default}` for a fallback and `\${...}` to escape. Unresolved references fail loudly with `file:line`. The `AD_*` namespace is reserved — only built-ins may use it. `replay --replay-update` cannot yet round-trip env directives or interpolation tokens, so it refuses those scripts.

## Native assets

The package bundles two native helpers that are managed automatically:

**Android snapshot helper** (13 KB APK) — provides multi-window accessibility snapshots via `adb shell am instrument`. Captures system UI (status bar, keyboard) alongside the app, unlike stock `uiautomator dump`. Auto-installed on the device on first snapshot.

**iOS XCUITest runner** (~200 KB source) — Swift project built via `xcodebuild build-for-testing` on first use. Provides snapshot, tap, swipe, type, record, and other interactions through an HTTP bridge to the simulator/device. Build output is cached in `ios-runner/build/`.

Both are resolved automatically — no manual build steps required.

## Environment variables

| Variable                              | Purpose                                                          |
| ------------------------------------- | ---------------------------------------------------------------- |
| `AGENT_DEVICE_STATE_DIR`              | Override state directory (default: `~/.agent-device/`)           |
| `AGENT_DEVICE_VERBOSE`                | Set to `1` for diagnostic logging (same as `--verbose` CLI flag) |
| `AGENT_DEVICE_ANDROID_SNAPSHOT_DEBUG` | Set to `1` for Android snapshot diagnostics                      |
| `AGENT_DEVICE_IOS_RUNNER_DEBUG`       | Set to `1` for iOS runner HTTP diagnostics                       |
| `AGENT_DEVICE_IOS_RUNNER_BUILD_DIR`   | Override iOS runner build products path                          |
| `AD_RECORD_TESTS`                     | Set to a directory path to enable video recording in tests       |

### Physical iOS device prerequisites

To drive a paired iPhone (`--platform ios --serial <UDID>`) the runner needs to be trusted **on the device itself**, one-time:

1. **Enable Developer Mode** — `Settings → Privacy & Security → Developer Mode → On`, then reboot the phone.
2. **Trust the runner certificate** — after the first `xcodebuild build-for-testing -destination "generic/platform=iOS"` installs `AgentDeviceRunner.app`, open it once from the home screen. You'll hit an "Untrusted Developer" sheet; go to `Settings → General → VPN & Device Management`, tap your developer profile, and trust it.
3. **Keep the phone unlocked** during test runs.

If any of those are missed you'll see a `COMMAND_FAILED` with hint "The UI test runner failed to enable automation mode …".

The runner is intentionally cached across CLI invocations (under`~/.agent-device/ios-runners/<udid>.json`) so subsequent commands skip the ~14s xcodebuild cold-start. To dismiss the on-device "Automation Running" overlay, run:

```bash
agent-device runner stop                  # active session's device
agent-device runner stop --serial <UDID>  # specific device
agent-device runner stop --all            # every cached runner
```

Every command takes `--platform ios|android`, `--serial <udid|id>`, `--session <name>`, and emits either human-readable text or `--json`. Session state (which device + which app) persists across invocations under `~/.agent-device/sessions/` so `open` in one shell and `tap` in another both land on the same device.

## Supported features

| Capability                                                         | Android                                        | iOS simulator                       | iOS device (devicectl)                                                      |
| ------------------------------------------------------------------ | ---------------------------------------------- | ----------------------------------- | --------------------------------------------------------------------------- |
| `devices`                                                          | ✅                                             | ✅                                  | ✅                                                                          |
| `snapshot` (accessibility tree)                                    | ✅                                             | ✅ (XCUITest runner)                | ✅                                                                          |
| `screenshot` → PNG                                                 | ✅                                             | ✅ (simctl)                         | ✅                                                                          |
| `tap` / `longpress` / `swipe`                                      | ✅                                             | ✅                                  | ✅                                                                          |
| `fill` / `type` / `focus`                                          | ✅                                             | ✅                                  | ✅                                                                          |
| `scroll` (direction + amount)                                      | ✅                                             | ✅                                  | ✅                                                                          |
| `pinch` (scale + optional center)                                  | ❌ (runner gap)                                | ✅                                  | ✅                                                                          |
| `home` / `back` / `app-switcher`                                   | ✅                                             | ✅                                  | ✅                                                                          |
| `rotate portrait \| landscape-…`                                   | ✅                                             | ✅                                  | ✅                                                                          |
| `open <app>` / `close [app]`                                       | ✅                                             | ✅ (simctl)                         | ✅ (devicectl)                                                              |
| `apps` / `appstate`                                                | ✅                                             | ✅                                  | ✅ (apps only)                                                              |
| `clipboard` get / `--set <text>`                                   | ✅                                             | ✅ (simctl pbpaste/pbcopy)          | ❌                                                                          |
| `press` / `find` / `get` / `is` / `wait` — selector/@ref targeting | ✅                                             | ✅                                  | ✅                                                                          |
| `ensure-simulator <name>`                                          | n/a                                            | ✅                                  | n/a                                                                         |
| `logs --since 30s --out <path>` (one-shot)                         | ✅ (logcat -T)                                 | ✅ (simctl log show)                | ❌ (use `--stream` instead — Apple has no host-side `log show` for devices) |
| `logs --stream --out <path>` / `logs --stop`                       | ✅ (logcat --pid + cross-invocation PID cache) | ✅ (simctl log stream predicate)    | ✅ (idevicesyslog via libimobiledevice)                                     |
| `record start` / `record stop`                                     | ✅ (screenrecord + pull)                       | ✅ (XCUITest runner + sandbox pull) | ✅ (runner + `devicectl copy from` — needs device trust + Developer Mode)   |
| `perf [--metric cpu\|memory\|fps]`                                 | ✅ (dumpsys + gfxinfo framestats)              | ✅ (simctl spawn ps)                | ✅ (xctrace 2× 1s + delta — true CPU%, Core Animation frames)               |
| `network <logPath>` (HTTP from logs)                               | ✅ (cross-line Android enrichment)             | ✅                                  | ✅                                                                          |
| `install` / `uninstall` / `reinstall`                              | ✅ (apk + aab)                                 | ✅ (.app + .ipa)                    | ✅ (.app + .ipa via devicectl — needs signed bundle)                        |
| `replay <script.ad>` / `test <glob>`                               | ✅                                             | ✅                                  | ✅                                                                          |
| Self-healing replay (`--replay-update`)                            | ✅                                             | ✅                                  | ✅                                                                          |
| Per-step artifacts + auto log-dump on failure                      | ✅                                             | ✅                                  | ❌ (needs logs)                                                             |

## Architecture

```
bin/agent_device.dart                CLI entry point (dispatches to cli/run_cli.dart)
│
├── lib/src/cli/                     args-backed commands
│   ├── commands/*.dart              one file per top-level command
│   └── run_cli.dart                 CommandRunner wiring + buildCliRunner()
│
├── lib/src/runtime/                 typed façade (library API) + session store
│   ├── agent_device.dart            AgentDevice.open(...) and per-action methods
│   ├── file_session_store.dart      ~/.agent-device/sessions/<name>.json
│   └── paths.dart                   state-dir resolution
│
├── lib/src/replay/                  .ad script layer
│   ├── script.dart                  parser + serializer + context header
│   ├── replay_runtime.dart          dispatch table + heal + artifact dumper
│   └── heal.dart                    selector re-resolution
│
├── lib/src/selectors/               @ref + DSL (`id=foo`, `role=Button label="OK"`)
├── lib/src/snapshot/                accessibility-tree types + ref attach
├── lib/src/diagnostics/             log_stream_record + network_log (HTTP extractor)
├── lib/src/backend/                 abstract Backend + options / results / capabilities
│
├── lib/src/platforms/android/       adb + screenrecord + logcat + snapshot/input
│                                    + apk/aab install_artifact
│
└── lib/src/platforms/ios/
    ├── runner_client.dart           XCUITest bridge (HTTP POST /command, BSD socket
    │                                on physical devices over CoreDevice tunnel)
    ├── ios_backend.dart             Backend subclass (simctl + runner + devicectl)
    ├── devicectl.dart               physical-device list / launch / install / uninstall
    ├── simctl.dart                  buildSimctlArgs helper
    ├── ensure_simulator.dart        find-or-create + boot
    ├── install_artifact.dart        .app + .ipa (single-app or hint-resolved multi-app)
    ├── app_lifecycle.dart, devices.dart, perf.dart, screenshot.dart
```

The XCUITest runner source is bundled at `lib/src/native/ios-runner/AgentDeviceRunner/`
(also at `ios-runner/AgentDeviceRunner/` in the repo development layout) —
a small Swift project Dart shells out to via `xcodebuild
test-without-building`. See `RunnerBSDSocketServer.swift` /
`RunnerTests+CommandExecution.swift` for the on-device side.

Key design choices vs. the TS source:

- No long-lived daemon. TS spawns one for state sharing; Dart instead
  persists sessions to disk (`~/.agent-device/sessions/`), plus the
  iOS XCUITest runner (`~/.agent-device/ios-runners/<udid>.json`),
  Android screenrecord PID (`~/.agent-device/android-recorders/<serial>.json`),
  and live log streams (`~/.agent-device/log-streams/<deviceId>.json`)
  so CLI invocations and the user's shell both converge on the same
  underlying tooling.
- No dynamic `bindCommands`. `AgentDevice` exposes concrete typed
  methods; each `Backend` subclass overrides what it supports — the
  base class's `unsupported(...)` makes partial coverage honest.
- iOS physical devices route over the CoreDevice IPv6 tunnel
  (`xcrun devicectl device info details → tunnelIPAddress`), not the
  legacy usbmuxd/iproxy path Apple deprecated on iOS 17+.

## Testing

```bash
# Unit tests (fast, no device required):
dart test packages/agent_device/test \
  --exclude-tags='android-live,ios-live,ios-device-live,android-emulator,fixture-live'

# iOS simulator live suite (needs a booted simulator + built runner):
AGENT_DEVICE_IOS_LIVE=1 dart test --tags=ios-live

# iOS physical device suite (also needs AGENT_DEVICE_IOS_DEVICE_UDID=<udid>):
AGENT_DEVICE_IOS_LIVE=1 AGENT_DEVICE_IOS_DEVICE_UDID=<udid> \
  dart test --tags=ios-device-live

# Android live suite (booted emulator or connected device):
AGENT_DEVICE_ANDROID_LIVE=1 dart test --tags=android-live

# All checks (analyze + unit tests):
make check
```

Test tags in use: `android-live`, `android-emulator`, `ios-live`,
`ios-device-live`, `fixture-live`. Tests without a tag never need a
device.

## License

MIT
