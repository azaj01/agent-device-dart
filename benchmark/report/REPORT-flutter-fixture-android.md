# agent-device: Dart port vs npm — benchmark

| | |
| --- | --- |
| Target app | `flutter-fixture` |
| Platform | `android` |
| Device | Android emulator emulator-5554 |
| Generated | 2026-05-30T15:28:56.250314Z |
| Reps (perf) | 5 |
| Dart binary | `0.0.4` |
| npm CLI | `0.16.4` |

Both CLIs drive the **same** Flutter fixture app on the **same** device through OS-level accessibility, so this is a like-for-like comparison.

## ⏱ Performance — steady-state latency

Median of 5 reps on the Home screen, same booted device, run back-to-back. Lower is better; bars scale to the slower CLI per row.

**`snapshot (isolated)`**
- dart `████████████████████` 2402 ms · p95 2473 ms · σ 32 ms · n=10
- npm  `██████████████████░░` 2131 ms · p95 2159 ms · σ 15 ms · n=10
- npm is **1.13× faster**

**`snapshot (mixed)`**
- dart `████████████████████` 2411 ms · p95 2444 ms · σ 22 ms · n=5
- npm  `██████████████████░░` 2126 ms · p95 2158 ms · σ 19 ms · n=5
- npm is **1.13× faster**

**`screenshot`**
- dart `████████████████████` 1637 ms · p95 1663 ms · σ 31 ms · n=5
- npm  `█████████████████░░░` 1401 ms · p95 1412 ms · σ 13 ms · n=5
- npm is **1.17× faster**

**`perf`**
- dart `████████████████████` 446 ms · p95 534 ms · σ 42 ms · n=5
- npm  `███████░░░░░░░░░░░░░` 157 ms · p95 186 ms · σ 16 ms · n=5
- npm is **2.84× faster**

**`appstate`**
- dart `████████████████░░░░` 353 ms · p95 382 ms · σ 13 ms · n=5
- npm  `████████████████████` 451 ms · p95 478 ms · σ 19 ms · n=5
- Dart is **1.28× faster**

**`press`**
- dart `████████████████████` 457 ms · p95 572 ms · σ 54 ms · n=5
- npm  `████████░░░░░░░░░░░░` 181 ms · p95 201 ms · σ 10 ms · n=5
- npm is **2.52× faster**


## 🥶 Performance — cold costs (one-off)

| Measurement | Dart | npm |
| --- | --- | --- |
| cold open (fresh state dir) | 2631 ms | 780 ms |

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


