// Port of agent-device/src/platforms/ios/devices.ts.
//
// Enumerates iOS devices — simulators via `simctl list devices -j` plus
// physical iOS/tvOS devices via `xcrun devicectl list devices`. Physical
// device failures are swallowed so the list still returns simulators
// even when no device is connected.
library;

import 'dart:convert';

import 'package:agent_device/src/backend/device_info.dart';
import 'package:agent_device/src/backend/platform.dart';
import 'package:agent_device/src/utils/errors.dart';
import 'package:agent_device/src/utils/exec.dart';

import 'devicectl.dart';
import 'simctl.dart';

// Recently-observed-Booted memo. `simctl list devices -j` costs ~0.7s per
// spawn; a single open --relaunch can invoke it multiple times across the
// close and launch paths. Mirrors SIMULATOR_BOOTED_MEMO_TTL_MS in the
// upstream simulator.ts: a simulator shut down externally inside the window
// surfaces the raw simctl error instead of an auto-boot. Transitions we
// own (boot) seed the memo; shutdown invalidates it.
// Exported so unit tests can assert TTL behaviour without duplicating the
// value.
const int simulatorBootedMemoTtlMs = 5000;

// Key: udid. Our MVP targets the default simulator set so
// simulatorSetPath is always null; a single udid key is sufficient.
final Map<String, int> _simulatorBootedMemo = {};

// Clock seam so unit tests can inject a deterministic timestamp.
// Production code leaves this null and uses DateTime.now().
int Function()? _nowMsOverride;

int _nowMs() =>
    _nowMsOverride?.call() ?? DateTime.now().millisecondsSinceEpoch;

/// Returns true when [udid] has a recently-observed Booted entry in the
/// in-process memo (within [simulatorBootedMemoTtlMs]).
bool readSimulatorBootedMemo(String udid) {
  final observedAt = _simulatorBootedMemo[udid];
  if (observedAt == null) return false;
  if (_nowMs() - observedAt > simulatorBootedMemoTtlMs) {
    _simulatorBootedMemo.remove(udid);
    return false;
  }
  return true;
}

/// Record that [udid] was observed in Booted state right now.
void markSimulatorBooted(String udid) {
  _simulatorBootedMemo[udid] = _nowMs();
}

/// Invalidate the booted memo for [udid]. Call on simulator shutdown so
/// subsequent callers do not skip the state listing.
void clearSimulatorBootedMemo(String udid) {
  _simulatorBootedMemo.remove(udid);
}

/// Reset all booted-memo entries and (optionally) the clock override.
/// Exposed for use in tests only.
void resetSimulatorBootedMemoForTests({int Function()? nowMs}) {
  _simulatorBootedMemo.clear();
  _nowMsOverride = nowMs;
}

/// Enumerate iOS (/tvOS) simulators via `xcrun simctl list devices -j`.
///
/// Returns one [BackendDeviceInfo] per simulator (available + unavailable).
/// Physical iOS devices are omitted in the MVP.
///
/// Booted state for a given UDID is recorded in the in-process
/// [_simulatorBootedMemo] when [markSimulatorBooted] has been called
/// recently. Callers who know a simulator is booted (e.g. after a launch or
/// open-relaunch) should call [markSimulatorBooted] to avoid repeat listings.
Future<List<BackendDeviceInfo>> listAppleSimulators() async {
  final result = await runCmd(
    'xcrun',
    buildSimctlArgs(['list', 'devices', '-j']),
    const ExecOptions(timeoutMs: 15000),
  );
  final Map<String, Object?> raw;
  try {
    raw = jsonDecode(result.stdout) as Map<String, Object?>;
  } on FormatException catch (e) {
    throw AppError(
      AppErrorCodes.commandFailed,
      'Could not parse `simctl list devices -j` output: ${e.message}',
      details: {'stdout': result.stdout, 'stderr': result.stderr},
    );
  }

  final devicesByRuntime =
      (raw['devices'] as Map?) ?? const <String, Object?>{};
  final out = <BackendDeviceInfo>[];
  devicesByRuntime.forEach((runtimeKey, value) {
    if (value is! List) return;
    final runtime = _runtimeLabel(runtimeKey.toString());
    for (final entry in value) {
      if (entry is! Map) continue;
      final udid = entry['udid']?.toString();
      final name = entry['name']?.toString();
      if (udid == null || name == null) continue;
      final state = entry['state']?.toString() ?? 'Unknown';
      final isAvailable = entry['isAvailable'] == true;
      final typeId = entry['deviceTypeIdentifier']?.toString() ?? '';
      final booted = state == 'Booted';
      // Seed the booted memo for any simulator currently in Booted state so
      // subsequent callers within the TTL window skip the listing entirely.
      if (booted) markSimulatorBooted(udid);
      out.add(
        BackendDeviceInfo(
          id: udid,
          name: name,
          platform: _platformFromRuntime(runtimeKey.toString()),
          target: _targetFromDeviceType(typeId),
          kind: 'simulator',
          booted: booted,
          details: <String, Object?>{
            'runtime': runtime,
            'state': state,
            'isAvailable': isAvailable,
            'deviceTypeIdentifier': typeId,
          },
        ),
      );
    }
  });
  return out;
}

/// Enumerate every iOS-family device visible to Xcode tooling —
/// simulators from `simctl` plus physical devices from `devicectl`.
/// Physical-device lookups fail silently so a missing iOS device doesn't
/// hide simulators.
Future<List<BackendDeviceInfo>> listAppleDevices() async {
  final simulators = await listAppleSimulators();
  final physical = await listApplePhysicalDevicesViaDevicectl();
  // Deduplicate on id (very rare but possible if a physical device shares
  // a UDID with a simulator set entry).
  final seen = <String>{for (final d in simulators) d.id};
  final merged = <BackendDeviceInfo>[...simulators];
  for (final d in physical) {
    if (seen.add(d.id)) merged.add(d);
  }
  return merged;
}

/// Pick the first booted simulator whose `udid` or `name` optionally
/// matches a filter. Returns null when nothing matches.
BackendDeviceInfo? pickBootedSimulator(
  List<BackendDeviceInfo> devices, {
  String? udid,
  String? name,
}) {
  for (final d in devices) {
    if (d.booted != true) continue;
    if (udid != null && d.id != udid) continue;
    if (name != null && d.name != name) continue;
    return d;
  }
  return null;
}

String _runtimeLabel(String key) {
  // com.apple.CoreSimulator.SimRuntime.iOS-26-2 → iOS 26.2
  final parts = key.split('.');
  if (parts.length < 2) return key;
  final tail = parts.last;
  return tail
      .replaceAll('-', ' ')
      .replaceFirstMapped(
        RegExp(r'(\w+) (\d+) (\d+)'),
        (m) => '${m.group(1)} ${m.group(2)}.${m.group(3)}',
      );
}

AgentDeviceBackendPlatform _platformFromRuntime(String key) {
  if (key.contains('tvOS')) return AgentDeviceBackendPlatform.ios;
  if (key.contains('watchOS')) return AgentDeviceBackendPlatform.ios;
  if (key.contains('iOS')) return AgentDeviceBackendPlatform.ios;
  if (key.contains('macOS')) return AgentDeviceBackendPlatform.macos;
  // Unknown — default to ios so the device surfaces to the user who can
  // inspect the details map.
  return AgentDeviceBackendPlatform.ios;
}

String? _targetFromDeviceType(String typeId) {
  if (typeId.contains('Apple-TV')) return 'tv';
  if (typeId.contains('Watch')) return 'watch';
  return 'mobile';
}
