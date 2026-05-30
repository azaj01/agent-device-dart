# agent-device: Dart port vs npm — benchmark

| | |
| --- | --- |
| Target app | `expo-test-app` |
| Platform | `ios` |
| Device | iOS simulator 9046550C-D9D6-4832-AFB6-8C0D73D90285 |
| Generated | 2026-05-30T15:10:47.367052Z |
| Reps (perf) | 5 |
| Dart binary | `0.0.4` |
| npm CLI | `0.16.4` |

Both CLIs drive the **same** Flutter fixture app on the **same** device through OS-level accessibility, so this is a like-for-like comparison.

## ⏱ Performance — steady-state latency

Median of 5 reps on the Home screen, same booted device, run back-to-back. Lower is better; bars scale to the slower CLI per row.

**`snapshot (isolated)`**
- dart `████████████████████` 464 ms · p95 556 ms · σ 50 ms · n=10
- npm  `████████████████░░░░` 364 ms · p95 372 ms · σ 5 ms · n=10
- npm is **1.27× faster**

**`snapshot (mixed)`**
- dart `████████████████████` 474 ms · p95 548 ms · σ 43 ms · n=5
- npm  `████████████████░░░░` 382 ms · p95 397 ms · σ 11 ms · n=5
- npm is **1.24× faster**

**`screenshot`**
- dart `██████████░░░░░░░░░░` 383 ms · p95 473 ms · σ 45 ms · n=5
- npm  `████████████████████` 752 ms · p95 815 ms · σ 27 ms · n=5
- Dart is **1.96× faster**

**`perf`**
- dart `████████████████████` 764 ms · p95 1145 ms · σ 153 ms · n=5
- npm  `████████░░░░░░░░░░░░` 305 ms · p95 351 ms · σ 20 ms · n=5
- npm is **2.50× faster**

**`appstate`**
- dart `████████████████████` 459 ms · p95 707 ms · σ 104 ms · n=5
- npm  `████░░░░░░░░░░░░░░░░` 83 ms · p95 88 ms · σ 2 ms · n=5
- npm is **5.53× faster**

**`press`**
- dart `████████████████████` 1082 ms · p95 1321 ms · σ 110 ms · n=5
- npm  `███████████████░░░░░` 838 ms · p95 1084 ms · σ 129 ms · n=5
- npm is **1.29× faster**


## 🥶 Performance — cold costs (one-off)

| Measurement | Dart | npm |
| --- | --- | --- |
| cold open (fresh state dir) | 592 ms | 4533 ms |

> Note: this measures session bootstrap + runner launch on a fresh state dir. The first-ever native runner *compile* is cached outside the state dir and is not included.


## 🎯 Accuracy — deterministic walkthrough

Identical command stream against the fixture oracle. Both CLIs are expected to reach parity; any miss is a flagged divergence.

- **Dart**: 8/9 `██████████████████░░` 89%
- **npm**: 8/9 `██████████████████░░` 89%

### Divergences

**Dart failures:**
- ❌ form: scroll reveals below-fold submit button — `scroll` should bring the off-screen submit button into view

**npm failures:**
- ❌ form: scroll reveals below-fold submit button — `scroll` should bring the off-screen submit button into view


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


