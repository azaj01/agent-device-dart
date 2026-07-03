// Tests for the idle-stop decision logic added in the port of upstream commit
// b67053e97 ("fix: bound retained iOS runner lifetime with an idle stop").
//
// The daemon-less adaptation enforces the idle bound at reconnect time
// (inside _liveRunner) rather than via an in-process timer. The pure-function
// seam `isRunnerSessionIdleExpired` and `resolveRunnerIdleStopDuration` are
// tested here without launching any live simulator processes.

import 'package:agent_device/src/platforms/ios/runner_client.dart';
import 'package:test/test.dart';

IosRunnerSession _session({DateTime? lastSuccessAt}) => IosRunnerSession(
  udid: 'test-udid',
  port: 1234,
  xcodebuildPid: 99,
  xctestrunPath: '/tmp/runner.xctestrun',
  logPath: '/tmp/runner.log',
  lastSuccessAt: lastSuccessAt,
);

void main() {
  group('isRunnerSessionIdleExpired', () {
    test('returns false when idle stop is zero (disabled)', () {
      // AGENT_DEVICE_IOS_RUNNER_IDLE_STOP_MS=0 disables idle stops.
      final session = _session(lastSuccessAt: DateTime(2000));
      expect(isRunnerSessionIdleExpired(session, Duration.zero), isFalse);
    });

    test('returns false when lastSuccessAt is null (runner never used)', () {
      // A runner that was retained but never successfully used should not be
      // idle-stopped — give it a chance to connect first.
      final session = _session();
      expect(
        isRunnerSessionIdleExpired(session, const Duration(minutes: 5)),
        isFalse,
      );
    });

    test('returns false when last success is within the idle window', () {
      final session = _session(lastSuccessAt: DateTime.now().subtract(
        const Duration(minutes: 4),
      ));
      expect(
        isRunnerSessionIdleExpired(session, const Duration(minutes: 5)),
        isFalse,
      );
    });

    test('returns true when last success is at exactly the idle window', () {
      // Edge: exactly at the boundary counts as expired (>=).
      final session = _session(lastSuccessAt: DateTime.now().subtract(
        const Duration(minutes: 5),
      ));
      expect(
        isRunnerSessionIdleExpired(session, const Duration(minutes: 5)),
        isTrue,
      );
    });

    test('returns true when last success is older than the idle window', () {
      final session = _session(lastSuccessAt: DateTime.now().subtract(
        const Duration(minutes: 10),
      ));
      expect(
        isRunnerSessionIdleExpired(session, const Duration(minutes: 5)),
        isTrue,
      );
    });

    test('works with a very short window (40 ms)', () {
      // Mirrors upstream test: "idle stop tears down a retained runner after
      // the idle window" — verifiable in unit tests without real timers.
      final session = _session(
        lastSuccessAt: DateTime.now().subtract(const Duration(milliseconds: 50)),
      );
      expect(
        isRunnerSessionIdleExpired(session, const Duration(milliseconds: 40)),
        isTrue,
      );
    });
  });

  group('resolveRunnerIdleStopDuration', () {
    test('returns the 5-minute default when no env var is set', () {
      expect(
        resolveRunnerIdleStopDuration({}),
        equals(runnerRetainedIdleStopDefault),
      );
    });

    test('returns Duration.zero when env var is 0 (disables idle stop)', () {
      expect(
        resolveRunnerIdleStopDuration({'AGENT_DEVICE_IOS_RUNNER_IDLE_STOP_MS': '0'}),
        equals(Duration.zero),
      );
    });

    test('returns the parsed duration when env var is a positive integer', () {
      expect(
        resolveRunnerIdleStopDuration({
          'AGENT_DEVICE_IOS_RUNNER_IDLE_STOP_MS': '30000',
        }),
        equals(const Duration(milliseconds: 30000)),
      );
    });

    test('ignores leading/trailing whitespace in the env var', () {
      expect(
        resolveRunnerIdleStopDuration({
          'AGENT_DEVICE_IOS_RUNNER_IDLE_STOP_MS': '  60000  ',
        }),
        equals(const Duration(milliseconds: 60000)),
      );
    });

    test('falls back to default when env var is non-numeric', () {
      expect(
        resolveRunnerIdleStopDuration({
          'AGENT_DEVICE_IOS_RUNNER_IDLE_STOP_MS': 'off',
        }),
        equals(runnerRetainedIdleStopDefault),
      );
    });

    test('falls back to default when env var is negative', () {
      // Upstream: `if (Number.isFinite(parsed) && parsed >= 0)` —
      // negative values fall back to default.
      expect(
        resolveRunnerIdleStopDuration({
          'AGENT_DEVICE_IOS_RUNNER_IDLE_STOP_MS': '-1',
        }),
        equals(runnerRetainedIdleStopDefault),
      );
    });
  });
}
