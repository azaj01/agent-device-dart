@TestOn('mac-os || linux')
@Tags(['regression', 'replay-live'])
library;

// ignore_for_file: avoid_print

import 'dart:io';

import 'package:agent_device/agent_device.dart';
import 'package:agent_device/src/replay/replay_runtime.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

/// Regression tests that run upstream agent-device `.ad` replay scripts
/// against real devices. These validate that the Dart port's replay runner
/// produces compatible results with the TypeScript original.
///
/// Gated on:
///   AGENT_DEVICE_REGRESSION_ANDROID=1  (Android emulator)
///   AGENT_DEVICE_REGRESSION_IOS=1      (iOS simulator)
void main() {
  final repoRoot = _findRepoRoot();
  final upstreamReplays = p.join(
    repoRoot,
    'agent-device',
    'test',
    'integration',
    'replays',
  );

  late Directory artifactDir;

  setUpAll(() async {
    artifactDir = await Directory.systemTemp.createTemp('ad-regression-');
    print('[regression] artifacts: ${artifactDir.path}');
  });

  tearDownAll(() async {
    if (await artifactDir.exists()) {
      await artifactDir.delete(recursive: true);
    }
  });

  // ---------------------------------------------------------------------------
  // Android replay regression
  // ---------------------------------------------------------------------------

  final androidGate = Platform.environment['AGENT_DEVICE_REGRESSION_ANDROID'];
  if (androidGate == '1') {
    final androidSerial =
        Platform.environment['AGENT_DEVICE_REGRESSION_ANDROID_SERIAL'] ??
        'emulator-5554';

    group('Android upstream replays', () {
      late AgentDevice device;

      setUpAll(() async {
        device = await AgentDevice.open(
          backend: const AndroidBackend(),
          selector: DeviceSelector(serial: androidSerial),
          sessionName: 'regression-android',
        );
        print('[regression-android] opened on ${device.device.id}');
      });

      tearDownAll(() async {
        await device.close();
      });

      for (final script in [
        '01-settings.ad',
        '03-scroll-discovery.ad',
        '05-app-lifecycle.ad',
        '06-swipe-gestures.ad',
      ]) {
        test('replay $script', () async {
          final scriptPath = p.join(upstreamReplays, 'android', script);
          expect(
            File(scriptPath).existsSync(),
            isTrue,
            reason: 'Upstream script must exist: $scriptPath',
          );
          final result = await runReplayScript(
            scriptPath: scriptPath,
            device: device,
            artifactDir: p.join(artifactDir.path, 'android', script),
          );
          print(
            '[regression-android] $script: '
            '${result.steps.length} steps, '
            '${result.passed} ok, '
            '${result.failed} failed',
          );
          final failures = result.steps
              .where((s) => !s.ok)
              .where((s) => !_isScreenshotPathError(s))
              .map(
                (s) =>
                    'step ${s.index}: ${s.action.command} → ${s.errorCode}: ${s.errorMessage}',
              )
              .toList();
          expect(
            failures,
            isEmpty,
            reason: 'All steps in $script should pass:\n${failures.join('\n')}',
          );
        }, timeout: const Timeout(Duration(seconds: 120)));
      }

      for (final script in [
        '02-deep-navigation.ad',
        '04-text-input-keyboard.ad',
      ]) {
        test('replay $script (best-effort)', () async {
          final scriptPath = p.join(upstreamReplays, 'android', script);
          if (!File(scriptPath).existsSync()) {
            markTestSkipped('Script not found: $scriptPath');
            return;
          }
          final result = await runReplayScript(
            scriptPath: scriptPath,
            device: device,
            artifactDir: p.join(artifactDir.path, 'android', script),
          );
          final okCount = result.passed;
          final total = result.steps.length;
          print(
            '[regression-android] $script (best-effort): '
            '$okCount/$total steps ok',
          );
          expect(
            okCount,
            greaterThanOrEqualTo((total / 2).ceil()),
            reason: '$script: only $okCount/$total steps passed',
          );
          // Also assert at least 1 step ran.
          expect(total, greaterThan(0));
        }, timeout: const Timeout(Duration(seconds: 120)));
      }
    });
  }

  // ---------------------------------------------------------------------------
  // iOS replay regression
  // ---------------------------------------------------------------------------

  final iosGate = Platform.environment['AGENT_DEVICE_REGRESSION_IOS'];
  if (iosGate == '1') {
    final iosSerial =
        Platform.environment['AGENT_DEVICE_REGRESSION_IOS_SERIAL'];

    group('iOS upstream replays', () {
      late AgentDevice device;

      setUpAll(() async {
        final selector = iosSerial != null
            ? DeviceSelector(serial: iosSerial)
            : const DeviceSelector(
                platform: PlatformSelector.ios,
              );
        device = await AgentDevice.open(
          backend: const IosBackend(),
          selector: selector,
          sessionName: 'regression-ios',
        );
        print('[regression-ios] opened on ${device.device.id}');
      });

      tearDownAll(() async {
        await device.close();
      });

      for (final script in [
        '01-settings.ad',
        '03-scroll-discovery.ad',
        '05-app-lifecycle.ad',
        '06-swipe-gestures.ad',
      ]) {
        test('replay $script', () async {
          final scriptPath = p.join(
            upstreamReplays,
            'ios',
            'simulator',
            script,
          );
          expect(
            File(scriptPath).existsSync(),
            isTrue,
            reason: 'Upstream script must exist: $scriptPath',
          );
          final result = await runReplayScript(
            scriptPath: scriptPath,
            device: device,
            artifactDir: p.join(artifactDir.path, 'ios', script),
          );
          print(
            '[regression-ios] $script: '
            '${result.steps.length} steps, '
            '${result.passed} ok, '
            '${result.failed} failed',
          );
          final failures = result.steps
              .where((s) => !s.ok)
              .where((s) => !_isScreenshotPathError(s))
              .map(
                (s) =>
                    'step ${s.index}: ${s.action.command} → ${s.errorCode}: ${s.errorMessage}',
              )
              .toList();
          expect(
            failures,
            isEmpty,
            reason: 'All steps in $script should pass:\n${failures.join('\n')}',
          );
        }, timeout: const Timeout(Duration(seconds: 120)));
      }

      for (final script in [
        '02-deep-navigation.ad',
        '04-text-input-keyboard.ad',
      ]) {
        test('replay $script (best-effort)', () async {
          final scriptPath = p.join(
            upstreamReplays,
            'ios',
            'simulator',
            script,
          );
          if (!File(scriptPath).existsSync()) {
            markTestSkipped('Script not found: $scriptPath');
            return;
          }
          final result = await runReplayScript(
            scriptPath: scriptPath,
            device: device,
            artifactDir: p.join(artifactDir.path, 'ios', script),
          );
          final okCount = result.passed;
          final total = result.steps.length;
          print(
            '[regression-ios] $script (best-effort): '
            '$okCount/$total steps ok',
          );
          expect(
            okCount,
            greaterThanOrEqualTo((total / 2).ceil()),
            reason: '$script: only $okCount/$total steps passed',
          );
          // Also assert at least 1 step ran.
          expect(total, greaterThan(0));
        }, timeout: const Timeout(Duration(seconds: 120)));
      }
    });
  }

  // ---------------------------------------------------------------------------
  // Skip message when no devices are gated
  // ---------------------------------------------------------------------------

  if (androidGate != '1' && iosGate != '1') {
    test(
      'upstream replay regression tests skipped',
      () {},
      skip:
          'Set AGENT_DEVICE_REGRESSION_ANDROID=1 and/or '
          'AGENT_DEVICE_REGRESSION_IOS=1 to run',
    );
  }
}

bool _isScreenshotPathError(ReplayStepResult step) {
  if (step.action.command != 'screenshot') return false;
  final msg = step.errorMessage ?? '';
  return msg.contains('PathNotFoundException') ||
      msg.contains('No such file or directory') ||
      msg.contains('did not produce a file');
}

String _findRepoRoot() {
  var dir = Directory(p.fromUri(Platform.script.resolve('.')));
  for (var i = 0; i < 10; i++) {
    final pubspec = File(p.join(dir.path, 'pubspec.yaml'));
    if (pubspec.existsSync()) {
      final content = pubspec.readAsStringSync();
      if (content.contains('workspace:') ||
          content.contains('agent_device_workspace')) {
        return dir.path;
      }
    }
    final parent = dir.parent;
    if (parent.path == dir.path) break;
    dir = parent;
  }
  return Directory.current.path;
}
