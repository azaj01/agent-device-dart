// Tests for buildIosSimulatorLaunchArgs flag ordering.
//
// Port of the flag-ordering assertions from the upstream
// buildIosSimulatorLaunchArgs unit coverage introduced in
// agent-device commit 6dc0aa550 ("perf: collapse iOS simulator relaunch into
// one simctl launch call (#1024)").
//
// The test exercises the public @visibleForTesting seam directly — no simctl
// calls are made.
import 'package:agent_device/src/platforms/ios/app_lifecycle.dart';
import 'package:test/test.dart';

void main() {
  const udid = 'BBBBBBBB-BBBB-BBBB-BBBB-BBBBBBBBBBBB';
  const bundleId = 'com.example.MyApp';

  group('buildIosSimulatorLaunchArgs — baseline', () {
    test('plain launch: simctl launch <udid> <bundleId>', () {
      final args = buildIosSimulatorLaunchArgs(udid, bundleId);
      expect(args, equals(['simctl', 'launch', udid, bundleId]));
    });

    test('launchConsole inserts --console-pty before udid', () {
      final args = buildIosSimulatorLaunchArgs(
        udid,
        bundleId,
        launchConsole: '/tmp/console.log',
      );
      expect(
        args,
        equals(['simctl', 'launch', '--console-pty', udid, bundleId]),
      );
    });

    test('launchArgs are appended after bundleId', () {
      final args = buildIosSimulatorLaunchArgs(
        udid,
        bundleId,
        launchArgs: ['--reset-settings', '--foo'],
      );
      expect(
        args,
        equals(
          ['simctl', 'launch', udid, bundleId, '--reset-settings', '--foo'],
        ),
      );
    });
  });

  group('buildIosSimulatorLaunchArgs — terminateRunningApp', () {
    test(
      'terminateRunningApp adds --terminate-running-process before udid',
      () {
        final args = buildIosSimulatorLaunchArgs(
          udid,
          bundleId,
          terminateRunningApp: true,
        );
        expect(
          args,
          equals([
            'simctl',
            'launch',
            '--terminate-running-process',
            udid,
            bundleId,
          ]),
        );
      },
    );

    test(
      'terminateRunningApp=false omits --terminate-running-process',
      () {
        final args = buildIosSimulatorLaunchArgs(
          udid,
          bundleId,
          terminateRunningApp: false,
        );
        expect(args, isNot(contains('--terminate-running-process')));
      },
    );

    test(
      '--console-pty comes before --terminate-running-process when both set',
      () {
        final args = buildIosSimulatorLaunchArgs(
          udid,
          bundleId,
          launchConsole: '/tmp/console.log',
          terminateRunningApp: true,
        );
        expect(
          args,
          equals([
            'simctl',
            'launch',
            '--console-pty',
            '--terminate-running-process',
            udid,
            bundleId,
          ]),
        );
        // Explicit ordering assertions.
        final consoleIdx = args.indexOf('--console-pty');
        final terminateIdx = args.indexOf('--terminate-running-process');
        final udidIdx = args.indexOf(udid);
        expect(consoleIdx, lessThan(terminateIdx),
            reason: '--console-pty must precede --terminate-running-process');
        expect(terminateIdx, lessThan(udidIdx),
            reason: '--terminate-running-process must precede udid');
      },
    );

    test(
      'terminateRunningApp with launchArgs: flag before udid, args after bundleId',
      () {
        final args = buildIosSimulatorLaunchArgs(
          udid,
          bundleId,
          terminateRunningApp: true,
          launchArgs: ['--foo', 'bar'],
        );
        expect(
          args,
          equals([
            'simctl',
            'launch',
            '--terminate-running-process',
            udid,
            bundleId,
            '--foo',
            'bar',
          ]),
        );
      },
    );
  });
}
