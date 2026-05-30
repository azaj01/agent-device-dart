import 'cli_target.dart';

/// One row of the feature-parity matrix.
class FeatureRow {
  FeatureRow(this.name, this.note);
  final String name;
  final String note;
  bool dartOk = false;
  bool npmOk = false;

  Map<String, dynamic> toJson() => {'name': name, 'dart': dartOk, 'npm': npmOk, 'note': note};
}

/// Union of top-level commands across both CLIs. The `note` flags differences
/// that are documented design choices in the port's README (so a ❌ reads as
/// "intentionally not ported yet" rather than "missing/broken").
final _commands = <FeatureRow>[
  FeatureRow('boot', ''),
  FeatureRow('open', ''),
  FeatureRow('close', ''),
  FeatureRow('install', ''),
  FeatureRow('uninstall', ''),
  FeatureRow('reinstall', ''),
  FeatureRow('install-from-source', 'npm: CI artifact install'),
  FeatureRow('push', 'push notification payloads'),
  FeatureRow('snapshot', 'core accessibility tree'),
  FeatureRow('diff', 'snapshot/screenshot diffing'),
  FeatureRow('devices', ''),
  FeatureRow('apps', ''),
  FeatureRow('appstate', ''),
  FeatureRow('clipboard', ''),
  FeatureRow('keyboard', ''),
  FeatureRow('perf', 'cpu/memory sampling'),
  FeatureRow('back', ''),
  FeatureRow('home', ''),
  FeatureRow('rotate', ''),
  FeatureRow('app-switcher', ''),
  FeatureRow('wait', ''),
  FeatureRow('alert', 'iOS/macOS alert handling'),
  FeatureRow('click', 'alias of press'),
  FeatureRow('press', 'tap by coord/ref/selector'),
  FeatureRow('tap', 'Dart: explicit coord tap'),
  FeatureRow('get', 'read text/attrs'),
  FeatureRow('find', 'present in both; output contract differs (Dart returns matched nodes, npm resolves to a tap coordinate)'),
  FeatureRow('is', 'UI-state assertions'),
  FeatureRow('replay', '.ad replay scripts'),
  FeatureRow('test', '.ad test suites'),
  FeatureRow('batch', 'multi-step batch'),
  FeatureRow('longpress', ''),
  FeatureRow('swipe', ''),
  FeatureRow('focus', ''),
  FeatureRow('type', ''),
  FeatureRow('fill', ''),
  FeatureRow('scroll', ''),
  FeatureRow('pinch', ''),
  FeatureRow('slider', ''),
  FeatureRow('screenshot', ''),
  FeatureRow('trigger-app-event', ''),
  FeatureRow('record', 'video recording'),
  FeatureRow('trace', 'trace capture'),
  FeatureRow('logs', 'app log capture'),
  FeatureRow('network', 'HTTP traffic dump'),
  FeatureRow('settings', 'OS settings/permissions'),
  FeatureRow('session', 'session management'),
  FeatureRow('connect', 'npm: remote daemon'),
  FeatureRow('disconnect', 'npm: remote daemon'),
  FeatureRow('auth', 'npm: cloud auth'),
  FeatureRow('metro', 'npm: React Native Metro'),
  FeatureRow('react-devtools', 'npm: RN DevTools'),
  FeatureRow('ensure-simulator', 'npm: ensure sim exists'),
  FeatureRow('runner', 'Dart: runner lifecycle'),
  FeatureRow('update', 'Dart: self-update'),
  FeatureRow('completion', 'shell completion'),
];

/// A command is present unless invoking `--help` reports it as unknown. Exit
/// codes are unreliable here (some commands validate required args before
/// honouring `--help` and exit non-zero while still existing), so detection is
/// based on the CLIs' "unknown command" diagnostics instead.
bool _present(RunResult r) {
  final out = '${r.stdout}\n${r.stderr}'.toLowerCase();
  if (out.contains('unknown command')) return false; // npm
  if (out.contains('could not find a command')) return false; // Dart (args pkg)
  return true;
}

/// Probe `<cli> <command> --help` on both built binaries. Reflects what
/// actually ships, not just docs.
Future<List<FeatureRow>> probeFeatureMatrix(CliTarget dart, CliTarget npm) async {
  for (final row in _commands) {
    row.dartOk = _present(await dart.run([row.name, '--help'], withSession: false, json: false));
    row.npmOk = _present(await npm.run([row.name, '--help'], withSession: false, json: false));
  }
  return _commands;
}
