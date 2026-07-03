// Port of agent-device/src/platforms/apple/core/__tests__/simulator-booted-memo.test.ts
//
// Tests for the recently-observed-Booted memo in devices.dart.
// Mirrors the upstream TTL, seeding, and invalidation behaviour; the
// simulatorSetPath-scope test is omitted because the Dart MVP targets the
// default simulator set only (no set-path key component).
import 'package:agent_device/src/platforms/ios/devices.dart';
import 'package:test/test.dart';

void main() {
  // Use a virtual clock so tests are deterministic and fast. The clock starts
  // at t=1000ms and can be advanced by the tests.
  int virtualNow = 1000;

  setUp(() {
    virtualNow = 1000;
    resetSimulatorBootedMemoForTests(nowMs: () => virtualNow);
  });

  tearDown(() {
    resetSimulatorBootedMemoForTests();
  });

  test(
    'readSimulatorBootedMemo returns false when the udid has not been marked',
    () {
      expect(readSimulatorBootedMemo('sim-1'), isFalse);
    },
  );

  test('markSimulatorBooted makes readSimulatorBootedMemo return true', () {
    markSimulatorBooted('sim-1');
    expect(readSimulatorBootedMemo('sim-1'), isTrue);
  });

  test(
    'readSimulatorBootedMemo skips the listing within the booted memo TTL',
    () {
      markSimulatorBooted('sim-1');
      expect(readSimulatorBootedMemo('sim-1'), isTrue,
          reason: 'first check: still within TTL');

      // Advance to just inside the TTL.
      virtualNow += simulatorBootedMemoTtlMs - 1;
      expect(readSimulatorBootedMemo('sim-1'), isTrue,
          reason: 'still within TTL window');

      // Advance past the TTL.
      virtualNow += 2;
      expect(readSimulatorBootedMemo('sim-1'), isFalse,
          reason: 'past TTL: listing should not be skipped');
    },
  );

  test('clearSimulatorBootedMemo invalidates the entry', () {
    markSimulatorBooted('sim-1');
    expect(readSimulatorBootedMemo('sim-1'), isTrue);

    clearSimulatorBootedMemo('sim-1');

    expect(readSimulatorBootedMemo('sim-1'), isFalse);
  });

  test(
    'clearSimulatorBootedMemo on shutdown forces next ensureBooted to re-list',
    () {
      // Simulate the pattern: mark booted → shutdown (clear) → check again.
      markSimulatorBooted('sim-1');
      clearSimulatorBootedMemo('sim-1'); // analogous to shutdownSimulator

      expect(readSimulatorBootedMemo('sim-1'), isFalse,
          reason: 'after shutdown, memo must be gone');
    },
  );

  test('memo is scoped per udid — clearing one does not affect another', () {
    markSimulatorBooted('sim-1');
    markSimulatorBooted('sim-2');

    clearSimulatorBootedMemo('sim-1');

    expect(readSimulatorBootedMemo('sim-1'), isFalse);
    expect(readSimulatorBootedMemo('sim-2'), isTrue);
  });

  test('resetSimulatorBootedMemoForTests clears all entries', () {
    markSimulatorBooted('sim-1');
    markSimulatorBooted('sim-2');

    resetSimulatorBootedMemoForTests();

    expect(readSimulatorBootedMemo('sim-1'), isFalse);
    expect(readSimulatorBootedMemo('sim-2'), isFalse);
  });

  test('simulatorBootedMemoTtlMs constant equals 5000', () {
    expect(simulatorBootedMemoTtlMs, equals(5000));
  });
}
