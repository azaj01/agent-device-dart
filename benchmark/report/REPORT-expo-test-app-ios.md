# agent-device: Dart port vs npm — benchmark

| | |
| --- | --- |
| Target app | `expo-test-app` |
| Platform | `ios` |
| Device | iOS simulator 9046550C-D9D6-4832-AFB6-8C0D73D90285 |
| Generated | 2026-05-30T14:20:32.849798Z |
| Reps (perf) | 5 |
| Dart binary | `0.0.4` |
| npm CLI | `0.16.4` |

Both CLIs drive the **same** Flutter fixture app on the **same** device through OS-level accessibility, so this is a like-for-like comparison.

## ⏱ Performance — steady-state latency

Median of 5 reps on the Home screen, same booted device, run back-to-back. Lower is better; bars scale to the slower CLI per row.

**`snapshot (isolated)`**
- dart `████████████████████` 579 ms · p95 659 ms · σ 63 ms · n=10
- npm  `█████████████░░░░░░░` 367 ms · p95 399 ms · σ 12 ms · n=10
- npm is **1.58× faster**

**`snapshot (mixed)`**
- dart `████████████████████` 483 ms · p95 554 ms · σ 34 ms · n=5
- npm  `████████████████░░░░` 377 ms · p95 383 ms · σ 4 ms · n=5
- npm is **1.28× faster**

**`screenshot`**
- dart `███████████░░░░░░░░░` 431 ms · p95 587 ms · σ 76 ms · n=5
- npm  `████████████████████` 759 ms · p95 770 ms · σ 16 ms · n=5
- Dart is **1.76× faster**

**`perf`**
- dart `████████████████████` 754 ms · p95 2173 ms · σ 567 ms · n=5
- npm  `████████░░░░░░░░░░░░` 304 ms · p95 307 ms · σ 3 ms · n=5
- npm is **2.48× faster**

**`appstate`**
- dart `████████████████████` 450 ms · p95 583 ms · σ 55 ms · n=5
- npm  `████░░░░░░░░░░░░░░░░` 83 ms · p95 88 ms · σ 3 ms · n=5
- npm is **5.42× faster**

**`press`**
- dart `████████████████████` 1036 ms · p95 1599 ms · σ 222 ms · n=5
- npm  `█████████████████░░░` 856 ms · p95 1107 ms · σ 128 ms · n=5
- npm is **1.21× faster**


## 🥶 Performance — cold costs (one-off)

| Measurement | Dart | npm |
| --- | --- | --- |
| cold open (fresh state dir) | 536 ms | 4062 ms |

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


