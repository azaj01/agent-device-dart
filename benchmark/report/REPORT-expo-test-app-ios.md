# agent-device: Dart port vs npm — benchmark

| | |
| --- | --- |
| Target app | `expo-test-app` |
| Platform | `ios` |
| Device | iOS simulator 9046550C-D9D6-4832-AFB6-8C0D73D90285 |
| Generated | 2026-05-30T18:43:32.033574Z |
| Reps (perf) | 5 |
| Dart binary | `0.0.4` |
| npm CLI | `0.16.4` |

Both CLIs drive the **same** Flutter fixture app on the **same** device through OS-level accessibility, so this is a like-for-like comparison.

## ⏱ Performance — steady-state latency

Median of 5 reps on the Home screen, same booted device, run back-to-back. Lower is better; bars scale to the slower CLI per row.

**`snapshot (isolated)`**
- dart `███████████████░░░░░` 301 ms · p95 454 ms · σ 52 ms · n=10
- npm  `████████████████████` 405 ms · p95 458 ms · σ 29 ms · n=10
- Dart is **1.35× faster**

**`snapshot (mixed)`**
- dart `██████████████░░░░░░` 294 ms · p95 366 ms · σ 32 ms · n=5
- npm  `████████████████████` 411 ms · p95 499 ms · σ 45 ms · n=5
- Dart is **1.40× faster**

**`screenshot`**
- dart `██████░░░░░░░░░░░░░░` 261 ms · p95 393 ms · σ 59 ms · n=5
- npm  `████████████████████` 919 ms · p95 1048 ms · σ 99 ms · n=5
- Dart is **3.52× faster**

**`perf`**
- dart `████████████████████` 708 ms · p95 1093 ms · σ 189 ms · n=5
- npm  `██████████░░░░░░░░░░` 361 ms · p95 455 ms · σ 48 ms · n=5
- npm is **1.96× faster**

**`appstate`**
- dart `████████████████████` 294 ms · p95 548 ms · σ 102 ms · n=5
- npm  `██████░░░░░░░░░░░░░░` 89 ms · p95 100 ms · σ 6 ms · n=5
- npm is **3.30× faster**

**`press`**
- dart `████████████████████` 867 ms · p95 1194 ms · σ 130 ms · n=5
- npm  `███████████████████░` 824 ms · p95 50945 ms · σ 20047 ms · n=5
- npm is **1.05× faster**


## 🥶 Performance — cold costs (one-off)

| Measurement | Dart | npm |
| --- | --- | --- |
| cold open (fresh state dir) | 304 ms | 6262 ms |

> Note: this measures session bootstrap + runner launch on a fresh state dir. The first-ever native runner *compile* is cached outside the state dir and is not included.


## 🎯 Accuracy — deterministic walkthrough

Identical command stream against the fixture oracle. Both CLIs are expected to reach parity; any miss is a flagged divergence.

- **Dart**: 20/21 `███████████████████░` 95%
- **npm**: 16/21 `███████████████░░░░░` 76%

### Divergences

**Dart failures:**
- ❌ wait: text-wait command (npm grammar) — wait <text> <timeout> blocks until the async result (npm); Dart uses a different wait grammar

**npm failures:**
- ❌ form: scroll reveals below-fold submit button — `scroll` should bring the off-screen submit button into view
- ❌ gesture: pan moves target — Pan should change the x offset (got "x 0, y 0, scale 1.00, rotate 0")
- ❌ gesture: rotate registers — Rotate should set rotate-changed (got "pan changed no, pinch changed no, rotate changed no")
- ❌ gesture: fling registers — Fling should increment the fling counter (before=0, after=0)
- ❌ longlist: scroll moves the long list — Scrolling should move the long catalog (footer y 4262.33349609375 → 4262.33349609375)


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


