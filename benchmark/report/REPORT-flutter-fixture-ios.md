# agent-device: Dart port vs npm — benchmark

| | |
| --- | --- |
| Target app | `flutter-fixture` |
| Platform | `ios` |
| Device | iOS simulator 9046550C-D9D6-4832-AFB6-8C0D73D90285 |
| Generated | 2026-05-30T15:06:48.084011Z |
| Reps (perf) | 5 |
| Dart binary | `0.0.4` |
| npm CLI | `0.16.4` |

Both CLIs drive the **same** Flutter fixture app on the **same** device through OS-level accessibility, so this is a like-for-like comparison.

## ⏱ Performance — steady-state latency

Median of 5 reps on the Home screen, same booted device, run back-to-back. Lower is better; bars scale to the slower CLI per row.

**`snapshot (isolated)`**
- dart `████████████████████` 277 ms · p95 350 ms · σ 37 ms · n=10
- npm  `████████████████░░░░` 225 ms · p95 307 ms · σ 36 ms · n=10
- npm is **1.23× faster**

**`snapshot (mixed)`**
- dart `████████████████████` 296 ms · p95 365 ms · σ 35 ms · n=5
- npm  `███████████████░░░░░` 226 ms · p95 343 ms · σ 53 ms · n=5
- npm is **1.31× faster**

**`screenshot`**
- dart `█████████░░░░░░░░░░░` 396 ms · p95 423 ms · σ 16 ms · n=5
- npm  `████████████████████` 906 ms · p95 1475 ms · σ 256 ms · n=5
- Dart is **2.29× faster**

**`perf`**
- dart `████████████████████` 1014 ms · p95 1816 ms · σ 348 ms · n=5
- npm  `██████░░░░░░░░░░░░░░` 326 ms · p95 677 ms · σ 145 ms · n=5
- npm is **3.11× faster**

**`appstate`**
- dart `████████████████████` 477 ms · p95 510 ms · σ 27 ms · n=5
- npm  `████░░░░░░░░░░░░░░░░` 96 ms · p95 165 ms · σ 28 ms · n=5
- npm is **4.97× faster**

**`press`**
- dart `████████████████████` 904 ms · p95 1171 ms · σ 161 ms · n=5
- npm  `████████████████░░░░` 718 ms · p95 1067 ms · σ 183 ms · n=5
- npm is **1.26× faster**


## 🥶 Performance — cold costs (one-off)

| Measurement | Dart | npm |
| --- | --- | --- |
| cold open (fresh state dir) | 930 ms | 4639 ms |

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


