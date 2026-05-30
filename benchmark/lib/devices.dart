import 'dart:io';

import 'apps.dart';
import 'cli_target.dart';

/// Run a shell command, streaming output, and throw on non-zero exit.
Future<void> _run(String exe, List<String> args, {String? cwd}) async {
  stderr.writeln('  \$ $exe ${args.join(' ')}');
  final proc = await Process.start(exe, args, workingDirectory: cwd, mode: ProcessStartMode.inheritStdio);
  final code = await proc.exitCode;
  if (code != 0) {
    throw StateError('command failed ($code): $exe ${args.join(' ')}');
  }
}

/// Ensure [app] is installed on [serial].
///
/// The Flutter fixture is built and installed automatically. The Expo test-app
/// requires a heavyweight native RN build, so it is built out-of-band (see the
/// benchmark README); here we only verify it is present and instruct otherwise.
Future<void> ensureAppInstalled({
  required BenchApp app,
  required String platform,
  required String serial,
  required String repoRoot,
}) async {
  final bundleId = app.bundleId(platform);
  if (app is FlutterFixtureApp) {
    await _ensureFlutterFixtureInstalled(platform: platform, serial: serial, repoRoot: repoRoot);
    // Android stylus workaround (applies to any app driven via fill/type).
    if (platform == 'android') {
      await Process.run(
          'adb', ['-s', serial, 'shell', 'settings', 'put', 'secure', 'stylus_handwriting_enabled', '0']);
    }
    return;
  }
  // Expo test-app: verify installed.
  final installed = await _isInstalled(platform, serial, bundleId);
  if (!installed) {
    throw StateError(
      'App "$bundleId" is not installed on $serial.\n'
      'Build it first (from agent-device/examples/test-app):\n'
      '  pnpm install --ignore-workspace\n'
      "  pnpm exec expo run:${platform == 'ios' ? 'ios' : 'android'} --configuration Release\n"
      'then re-run the benchmark.',
    );
  }
  if (platform == 'android') {
    await Process.run(
        'adb', ['-s', serial, 'shell', 'settings', 'put', 'secure', 'stylus_handwriting_enabled', '0']);
  }
}

Future<bool> _isInstalled(String platform, String serial, String bundleId) async {
  if (platform == 'ios') {
    final r = await Process.run('xcrun', ['simctl', 'listapps', serial]);
    return (r.stdout as String).contains(bundleId);
  }
  final r = await Process.run('adb', ['-s', serial, 'shell', 'pm', 'list', 'packages', bundleId]);
  return (r.stdout as String).contains(bundleId);
}

Future<void> _ensureFlutterFixtureInstalled({
  required String platform,
  required String serial,
  required String repoRoot,
}) async {
  final appDir = '$repoRoot/test_apps/agent_device_fixture_app';

  if (platform == 'android') {
    final apk = '$appDir/build/app/outputs/flutter-apk/app-debug.apk';
    if (!File(apk).existsSync()) {
      stderr.writeln('Building Android fixture APK…');
      await _run('flutter', ['build', 'apk', '--debug'], cwd: appDir);
    }
    await _run('adb', ['-s', serial, 'install', '-r', apk]);
    // Best-effort: disable stylus handwriting (ignore failure on older images).
    await Process.run('adb', ['-s', serial, 'shell', 'settings', 'put', 'secure', 'stylus_handwriting_enabled', '0']);
  } else {
    final bundle = '$appDir/build/ios/iphonesimulator/Runner.app';
    if (!Directory(bundle).existsSync()) {
      stderr.writeln('Building iOS fixture app…');
      await _run('flutter', ['build', 'ios', '--debug', '--simulator'], cwd: appDir);
    }
    await _run('xcrun', ['simctl', 'install', serial, bundle]);
  }
}

/// Measure a cold `open` on a fresh state directory (session bootstrap + runner
/// launch). Note: this does NOT force a first-ever native runner *compile* —
/// that is cached outside the state dir — so it is reported as a separate,
/// best-effort cold-cost line.
Future<int> measureColdOpen(CliTarget t, String bundleId) async {
  final dir = Directory(t.stateDir);
  if (dir.existsSync()) dir.deleteSync(recursive: true);
  final r = await t.run(['open', bundleId]);
  return r.durationMs;
}

/// Kill any lingering npm agent-device daemon and clear its lock files.
///
/// The npm CLI keeps a long-lived daemon; a stale one from a previous run holds
/// Android's single global UiAutomation connection and would starve the Dart
/// phase (which captures snapshots via `uiautomator`), so the benchmark starts
/// from a clean slate. npm transparently respawns its daemon when its phase
/// begins.
Future<void> killNpmDaemon() async {
  await Process.run('pkill', ['-f', 'internal/daemon.js']);
  final home = Platform.environment['HOME'];
  if (home != null) {
    for (final f in ['daemon.json', 'daemon.lock']) {
      final file = File('$home/.agent-device/$f');
      if (file.existsSync()) file.deleteSync();
    }
  }
  await Future<void>.delayed(const Duration(milliseconds: 500));
}

/// Verify the target device is reachable, returning a human label.
Future<String> verifyDevice(String platform, String serial) async {
  if (platform == 'android') {
    final r = await Process.run('adb', ['-s', serial, 'get-state']);
    if ((r.stdout as String).trim() != 'device') {
      throw StateError('Android device $serial is not in "device" state.');
    }
    return 'Android emulator $serial';
  } else {
    final r = await Process.run('xcrun', ['simctl', 'list', 'devices', 'booted']);
    if (!(r.stdout as String).contains(serial)) {
      throw StateError('iOS simulator $serial is not booted.');
    }
    return 'iOS simulator $serial';
  }
}
