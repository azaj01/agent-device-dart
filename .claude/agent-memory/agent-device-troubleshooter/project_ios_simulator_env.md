---
name: project-ios-simulator-env
description: iOS simulator environment details and runner session management for agent-device-dart
metadata:
  type: project
---

Active simulator: iPhone 16e, UDID `9046550C-D9D6-4832-AFB6-8C0D73D90285`, runtime iOS 26.3.

Runner sessions persist at `~/.agent-device/ios-runners/<udid>.json`. A session file does NOT guarantee the runner process is alive — always verify with `ps -p <xcodebuildPid>` before trusting a session. Stale files for non-booted simulators should be removed before running live tests.

The runner session format (as of 2026-05-28):
`{"udid":"...","port":...,"xcodebuildPid":...,"xctestrunPath":"...","logPath":"...","kind":"simulator"}`

Note: the session file does NOT include a `lastSuccessAt` field at the JSON level — that field lives in the in-process `IosRunnerSession` object, not in the persisted file.

**Why:** Stale session files (dead PID, missing temp dir) can cause the runner to fail to cold-start cleanly if the code path trusts the file without checking liveness.

**How to apply:** Before running live tests, always check `~/.agent-device/ios-runners/` and remove session files whose `xcodebuildPid` is no longer running.
