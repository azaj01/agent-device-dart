# agent-device: Dart port vs npm — benchmark

| | |
| --- | --- |
| Target app | `flutter-fixture` |
| Platform | `android` |
| Device | Android emulator emulator-5554 |
| Generated | 2026-05-30T12:49:47.798305Z |
| Reps (perf) | 5 |
| Dart binary | `0.0.4` |
| npm CLI | `0.16.4` |

Both CLIs drive the **same** Flutter fixture app on the **same** device through OS-level accessibility, so this is a like-for-like comparison.

## ⏱ Performance — steady-state latency

Median of 5 reps on the Home screen, same booted device, run back-to-back. Lower is better; bars scale to the slower CLI per row.

**`startup (--version)`**
- dart `████████░░░░░░░░░░░░` 32 ms · p95 32 ms
- npm  `████████████████████` 82 ms · p95 90 ms
- Dart is **2.56× faster**

**`snapshot`**
- dart `████████████████████` 2426 ms · p95 2760 ms
- npm  `██████████████████░░` 2145 ms · p95 2292 ms
- npm is **1.13× faster**

**`screenshot`**
- dart `████████████████████` 1778 ms · p95 1947 ms
- npm  `████████████████░░░░` 1427 ms · p95 1453 ms
- npm is **1.25× faster**

**`perf`**
- dart `████████████████████` 478 ms · p95 882 ms
- npm  `█████████░░░░░░░░░░░` 206 ms · p95 221 ms
- npm is **2.32× faster**

**`appstate`**
- dart `██████████████████░░` 396 ms · p95 597 ms
- npm  `████████████████████` 446 ms · p95 482 ms
- Dart is **1.13× faster**

**`press`**
- dart `████████████████████` 520 ms · p95 632 ms
- npm  `█████████░░░░░░░░░░░` 238 ms · p95 260 ms
- npm is **2.18× faster**


## 🥶 Performance — cold costs (one-off)

| Measurement | Dart | npm |
| --- | --- | --- |
| cold open (fresh state dir) | 3934 ms | 850 ms |

> Note: this measures session bootstrap + runner launch on a fresh state dir. The first-ever native runner *compile* is cached outside the state dir and is not included.


## 🎯 Accuracy — deterministic walkthrough

Identical command stream against the fixture oracle. Both CLIs are expected to reach parity; any miss is a flagged divergence.

- **Dart**: 15/15 `████████████████████` 100%
- **npm**: 15/15 `████████████████████` 100%

✅ No divergences — both CLIs passed every check.


## 🧩 Feature set — command parity

Probed by invoking `<cli> <command> --help` on each built binary (✅ = command present). Notes mark documented port design choices.

- **Dart**: 45/56 `████████████████░░░░`
- **npm**:  50/56 `██████████████████░░`

| Command | Dart | npm | Notes |
| --- | :---: | :---: | --- |
| `boot` | ✅ | ✅ |  |
| `open` | ✅ | ✅ |  |
| `close` | ✅ | ✅ |  |
| `install` | ✅ | ✅ |  |
| `uninstall` | ✅ | ❌ |  |
| `reinstall` | ✅ | ✅ |  |
| `install-from-source` | ❌ | ✅ | npm: CI artifact install |
| `push` | ❌ | ✅ | push notification payloads |
| `snapshot` | ✅ | ✅ | core accessibility tree |
| `diff` | ❌ | ✅ | snapshot/screenshot diffing |
| `devices` | ✅ | ✅ |  |
| `apps` | ✅ | ✅ |  |
| `appstate` | ✅ | ✅ |  |
| `clipboard` | ✅ | ✅ |  |
| `keyboard` | ✅ | ✅ |  |
| `perf` | ✅ | ✅ | cpu/memory sampling |
| `back` | ✅ | ✅ |  |
| `home` | ✅ | ✅ |  |
| `rotate` | ✅ | ✅ |  |
| `app-switcher` | ✅ | ✅ |  |
| `wait` | ✅ | ✅ |  |
| `alert` | ❌ | ✅ | iOS/macOS alert handling |
| `click` | ✅ | ✅ | alias of press |
| `press` | ✅ | ✅ | tap by coord/ref/selector |
| `tap` | ✅ | ❌ | Dart: explicit coord tap |
| `get` | ✅ | ✅ | read text/attrs |
| `find` | ✅ | ✅ | present in both; output contract differs (Dart returns matched nodes, npm resolves to a tap coordinate) |
| `is` | ✅ | ✅ | UI-state assertions |
| `replay` | ✅ | ✅ | .ad replay scripts |
| `test` | ✅ | ✅ | .ad test suites |
| `batch` | ✅ | ✅ | multi-step batch |
| `longpress` | ✅ | ✅ |  |
| `swipe` | ✅ | ✅ |  |
| `focus` | ✅ | ✅ |  |
| `type` | ✅ | ✅ |  |
| `fill` | ✅ | ✅ |  |
| `scroll` | ✅ | ✅ |  |
| `pinch` | ✅ | ✅ |  |
| `slider` | ✅ | ❌ |  |
| `screenshot` | ✅ | ✅ |  |
| `trigger-app-event` | ✅ | ✅ |  |
| `record` | ✅ | ✅ | video recording |
| `trace` | ❌ | ✅ | trace capture |
| `logs` | ✅ | ✅ | app log capture |
| `network` | ✅ | ✅ | HTTP traffic dump |
| `settings` | ✅ | ✅ | OS settings/permissions |
| `session` | ✅ | ✅ | session management |
| `connect` | ❌ | ✅ | npm: remote daemon |
| `disconnect` | ❌ | ✅ | npm: remote daemon |
| `auth` | ❌ | ✅ | npm: cloud auth |
| `metro` | ❌ | ✅ | npm: React Native Metro |
| `react-devtools` | ❌ | ✅ | npm: RN DevTools |
| `ensure-simulator` | ❌ | ✅ | npm: ensure sim exists |
| `runner` | ✅ | ❌ | Dart: runner lifecycle |
| `update` | ✅ | ❌ | Dart: self-update |
| `completion` | ✅ | ❌ | shell completion |


