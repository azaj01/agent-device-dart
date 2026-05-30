# agent-device: Dart port vs npm — benchmark

| | |
| --- | --- |
| Target app | `flutter-fixture` |
| Platform | `android` |
| Device | Android emulator emulator-5554 |
| Generated | 2026-05-30T18:54:48.861206Z |
| Reps (perf) | 5 |
| Dart binary | `0.0.4` |
| npm CLI | `0.16.4` |

Both CLIs drive the **same** Flutter fixture app on the **same** device through OS-level accessibility, so this is a like-for-like comparison.

## ⏱ Performance — steady-state latency

Median of 5 reps on the Home screen, same booted device, run back-to-back. Lower is better; bars scale to the slower CLI per row.

**`snapshot (isolated)`**
- dart `████████████████████` 5506 ms · p95 6761 ms · σ 956 ms · n=8 · ⚠️ 2 failed
- npm  `████████░░░░░░░░░░░░` 2320 ms · p95 2630 ms · σ 152 ms · n=10
- npm is **2.37× faster**

**`snapshot (mixed)`**
- dart `████████████████████` 4305 ms · p95 6265 ms · σ 1316 ms · n=5
- npm  `██████████░░░░░░░░░░` 2146 ms · p95 2290 ms · σ 57 ms · n=5
- npm is **2.01× faster**

**`screenshot`**
- dart `████████████████████` 4818 ms · p95 5978 ms · σ 1469 ms · n=5
- npm  `██████░░░░░░░░░░░░░░` 1466 ms · p95 1671 ms · σ 108 ms · n=5
- npm is **3.29× faster**

**`perf`**
- dart `████████████████████` 1420 ms · p95 6650 ms · σ 2120 ms · n=5
- npm  `███░░░░░░░░░░░░░░░░░` 184 ms · p95 438 ms · σ 110 ms · n=5
- npm is **7.72× faster**

**`appstate`**
- dart `████████████████████` 824 ms · p95 2996 ms · σ 1116 ms · n=5
- npm  `███████████░░░░░░░░░` 459 ms · p95 519 ms · σ 39 ms · n=5
- npm is **1.80× faster**

**`press`**
- dart `████████████████████` 1175 ms · p95 1476 ms · σ 384 ms · n=5
- npm  `███░░░░░░░░░░░░░░░░░` 186 ms · p95 232 ms · σ 26 ms · n=5
- npm is **6.32× faster**


## 🥶 Performance — cold costs (one-off)

| Measurement | Dart | npm |
| --- | --- | --- |
| cold open (fresh state dir) | 22272 ms | 945 ms |

> Note: this measures session bootstrap + runner launch on a fresh state dir. The first-ever native runner *compile* is cached outside the state dir and is not included.


## 🎯 Accuracy — deterministic walkthrough

Identical command stream against the fixture oracle. Both CLIs are expected to reach parity; any miss is a flagged divergence.

- **Dart**: 19/20 `███████████████████░` 95%
- **npm**: 20/20 `████████████████████` 100%

### Divergences

**Dart failures:**
- ❌ diff: snapshot diff supported — diff snapshot should report what changed (npm); Dart lacks the command


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


