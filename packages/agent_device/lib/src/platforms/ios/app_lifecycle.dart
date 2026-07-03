// Port of agent-device/src/platforms/ios/apps.ts (MVP subset — install
// paths, bundled runner integration, and backend-session tracking land in
// Phase 8B alongside the XCUITest runner).
library;

import 'dart:convert';
import 'dart:io';

import 'package:agent_device/src/utils/errors.dart';
import 'package:agent_device/src/utils/exec.dart';
import 'package:meta/meta.dart' show visibleForTesting;

import '../app_resolution_cache.dart';
import 'simctl.dart';

const Map<String, String> _aliases = {
  'settings': 'com.apple.Preferences',
};

final _iosAppResolutionCache = AppResolutionCache<String>();

AppResolutionCacheScope _iosAppResolutionScope(String udid) {
  return AppResolutionCacheScope(platform: 'ios', deviceId: udid);
}

/// Resolve an iOS app display name or bundle-id alias to a bundle id.
///
/// Exact bundle ids (containing a dot) pass through immediately without
/// hitting the cache or querying the device.  Display-name matches are
/// cached for [AppResolutionCache] TTL to avoid repeated `simctl listapps`
/// calls within a session.
///
/// NOTE: This implementation covers simulator/physical-iOS only.  macOS
/// resolution (`resolveMacOsApp`) is a separate module not yet ported.
Future<String> resolveIosApp(String udid, String app) async {
  final trimmed = app.trim();
  if (trimmed.contains('.')) return trimmed;

  final alias = _aliases[trimmed.toLowerCase()];
  if (alias != null) return alias;

  final cacheScope = _iosAppResolutionScope(udid);
  final cached = _iosAppResolutionCache.get(cacheScope, trimmed);
  if (cached != null) return cached;

  final apps = await listIosApps(udid, userOnly: false);
  final matches = apps
      .where((a) => (a.name ?? '').toLowerCase() == trimmed.toLowerCase())
      .toList();

  if (matches.length == 1) {
    return _iosAppResolutionCache.set(cacheScope, trimmed, matches[0].bundleId);
  }
  if (matches.length > 1) {
    throw AppError(
      AppErrorCodes.invalidArgs,
      'Multiple apps matched "$app"',
      details: {'matches': matches.map((a) => a.bundleId).toList()},
    );
  }
  throw AppError(
    AppErrorCodes.appNotInstalled,
    'No app found matching "$app"',
  );
}

/// Invalidates the iOS app-resolution cache for [udid] around [operation].
///
/// Use this to wrap install/uninstall operations so that subsequent
/// display-name lookups reflect the new device state.
Future<R> invalidateIosAppResolutionWhile<R>(
  String udid,
  Future<R> Function() operation,
) {
  return _iosAppResolutionCache.invalidateWhile(
    _iosAppResolutionScope(udid),
    operation,
  );
}

/// A brief view of an installed iOS app, extracted from `simctl listapps`.
class IosAppInfo {
  final String bundleId;
  final String? name;
  final String? bundleName;
  final String? applicationType; // "User" | "System"

  const IosAppInfo({
    required this.bundleId,
    this.name,
    this.bundleName,
    this.applicationType,
  });
}

/// `xcrun simctl listapps <udid>` outputs an old-style NeXTSTEP plist
/// (not JSON and not `-j`-capable). Pipe through `plutil -convert json`
/// for a clean structured parse.
Future<List<IosAppInfo>> listIosApps(
  String udid, {
  bool userOnly = true,
}) async {
  final result = await runCmd('sh', [
    '-c',
    'xcrun simctl listapps ${_sh(udid)} | plutil -convert json -r -o - -',
  ], const ExecOptions(timeoutMs: 30000));
  final Map<String, Object?> raw;
  try {
    raw = jsonDecode(result.stdout) as Map<String, Object?>;
  } on FormatException catch (e) {
    throw AppError(
      AppErrorCodes.commandFailed,
      'Could not parse `simctl listapps` output: ${e.message}',
      details: {'udid': udid, 'stderr': result.stderr},
    );
  }
  final apps = <IosAppInfo>[];
  raw.forEach((bundleId, value) {
    if (value is! Map) return;
    final appType = value['ApplicationType']?.toString();
    if (userOnly && appType != 'User') return;
    apps.add(
      IosAppInfo(
        bundleId: bundleId,
        name:
            value['CFBundleDisplayName']?.toString() ??
            value['CFBundleName']?.toString(),
        bundleName: value['CFBundleName']?.toString(),
        applicationType: appType,
      ),
    );
  });
  apps.sort((a, b) => a.bundleId.compareTo(b.bundleId));
  return apps;
}

/// How long `simctl launch --console-pty` is allowed to run before the
/// console capture is considered complete and the process output is flushed.
const _iosSimulatorConsoleCaptureDuration = Duration(milliseconds: 25000);

/// Launch an app by bundle id on [udid]. Returns the PID reported by
/// `simctl launch`.
///
/// When [launchConsole] is set, `simctl launch --console-pty` is used to
/// capture the launch-time stdout/stderr to the given file path.
/// Only valid for iOS simulator targets.
///
/// When [terminateRunningApp] is true, `--terminate-running-process` is added
/// so that `simctl launch` terminates any existing instance before relaunching,
/// collapsing a separate terminate + launch into a single call.
Future<int?> openIosApp(
  String udid,
  String bundleId, {
  String? launchConsole,
  List<String>? launchArgs,
  bool terminateRunningApp = false,
}) async {
  final simctlArgs = _buildIosSimulatorLaunchArgs(
    udid,
    bundleId,
    launchConsole: launchConsole,
    launchArgs: launchArgs,
    terminateRunningApp: terminateRunningApp,
  );
  if (launchConsole != null && launchConsole.isNotEmpty) {
    await _runIosSimulatorConsoleLaunch(simctlArgs, launchConsole);
    return null;
  }
  final result = await runCmd(
    'xcrun',
    simctlArgs,
    const ExecOptions(timeoutMs: 30000),
  );
  // Output format: "<bundleId>: <pid>"
  final match = RegExp(r':\s*(\d+)').firstMatch(result.stdout);
  if (match != null) {
    return int.tryParse(match.group(1)!);
  }
  return null;
}

/// Build the `xcrun simctl launch` argument list for [udid] and [bundleId].
///
/// Exposed for testing so callers can verify flag ordering without running
/// simctl. Production code goes through [openIosApp].
@visibleForTesting
List<String> buildIosSimulatorLaunchArgs(
  String udid,
  String bundleId, {
  String? launchConsole,
  List<String>? launchArgs,
  bool terminateRunningApp = false,
}) {
  final args = ['launch'];
  if (launchConsole != null && launchConsole.isNotEmpty) args.add('--console-pty');
  if (terminateRunningApp) args.add('--terminate-running-process');
  args.add(udid);
  args.add(bundleId);
  // App launch arguments are forwarded verbatim after the bundle id. An empty
  // list adds nothing (a clean launch).
  if (launchArgs != null) args.addAll(launchArgs);
  return buildSimctlArgs(args);
}

List<String> _buildIosSimulatorLaunchArgs(
  String udid,
  String bundleId, {
  String? launchConsole,
  List<String>? launchArgs,
  bool terminateRunningApp = false,
}) => buildIosSimulatorLaunchArgs(
  udid,
  bundleId,
  launchConsole: launchConsole,
  launchArgs: launchArgs,
  terminateRunningApp: terminateRunningApp,
);

/// Run `simctl launch --console-pty` and write the combined stdout/stderr
/// to [logPath]. Treats a timeout as a graceful completion — the app
/// launched and the console window was captured up to the timeout.
Future<void> _runIosSimulatorConsoleLaunch(
  List<String> launchArgs,
  String logPath,
) async {
  await File(logPath).parent.create(recursive: true);
  final timeoutMs = _iosSimulatorConsoleCaptureDuration.inMilliseconds;
  String stdout = '';
  String stderr = '';
  try {
    final result = await runCmd(
      'xcrun',
      launchArgs,
      ExecOptions(allowFailure: true, timeoutMs: timeoutMs),
    );
    stdout = result.stdout;
    stderr = result.stderr;
  } on AppError catch (e) {
    // A timeout is expected — the console capture window closed when the app
    // finished its startup output. Use whatever was captured.
    final details = e.details;
    if (details != null && details['timeoutMs'] == timeoutMs) {
      stdout = details['stdout'] as String? ?? '';
      stderr = details['stderr'] as String? ?? '';
    } else {
      rethrow;
    }
  }
  await File(logPath).writeAsString(_joinProcessOutput(stdout, stderr));
}

String _joinProcessOutput(String stdout, String stderr) {
  if (stdout.isEmpty || stderr.isEmpty) return '$stdout$stderr';
  if (stdout.endsWith('\n') || stdout.endsWith('\r')) return '$stdout$stderr';
  return '$stdout\n$stderr';
}

/// Terminate an app by bundle id on [udid]. Succeeds even if the app
/// isn't running.
Future<void> closeIosApp(String udid, String bundleId) async {
  await runCmd(
    'xcrun',
    buildSimctlArgs(['terminate', udid, bundleId]),
    const ExecOptions(allowFailure: true, timeoutMs: 15000),
  );
}

/// Foreground process state. `simctl` doesn't expose the foreground app
/// directly; we approximate by listing running processes and returning
/// whatever is most recently launched. Real-device foreground tracking
/// lands with `devicectl` in Phase 8B.
Future<({String? bundleId, String? pid})> getIosForeground(String udid) async {
  final result = await runCmd(
    'xcrun',
    buildSimctlArgs(['spawn', udid, 'launchctl', 'list']),
    const ExecOptions(allowFailure: true, timeoutMs: 15000),
  );
  if (result.exitCode != 0) return (bundleId: null, pid: null);
  // Rows: "<pid>\t<status>\t<label>"
  String? best;
  String? bestPid;
  for (final line in result.stdout.split('\n')) {
    final parts = line.trim().split(RegExp(r'\s+'));
    if (parts.length < 3) continue;
    final pid = parts[0];
    final label = parts[2];
    if (pid == '-') continue;
    if (!label.startsWith('UIKitApplication:')) continue;
    // UIKitApplication:com.example.MyApp[…]
    final m = RegExp(r'UIKitApplication:([^\[]+)').firstMatch(label);
    if (m != null) {
      best = m.group(1);
      bestPid = pid;
    }
  }
  return (bundleId: best, pid: bestPid);
}

/// Minimal shell-quote for a UDID (alphanum + dashes).
String _sh(String s) => "'${s.replaceAll("'", r"'\''")}'";
