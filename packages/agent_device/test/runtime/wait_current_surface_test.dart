// Tests for wait() timeout surface diagnostics.
// Port of agent-device/src/daemon/handlers/__tests__/snapshot-handler.test.ts
// (the wait-timeout-surface test cases added in commit d268b79a).
import 'package:agent_device/agent_device.dart';
import 'package:agent_device/src/runtime/interaction_target.dart';
import 'package:test/test.dart';

// ---------------------------------------------------------------------------
// Fake backend
//
// Normal polling calls (from isPredicate → snapshot) return empty nodes so
// the predicate never passes. The surface-inspection call — identified by
// interactiveOnly:true + compact:true — returns [surfaceNodes] (or throws
// when [surfaceThrows] is set).
// ---------------------------------------------------------------------------

class _FakeBackend extends Backend {
  final List<SnapshotNode> surfaceNodes;
  final bool surfaceThrows;

  _FakeBackend({this.surfaceNodes = const [], this.surfaceThrows = false});

  @override
  AgentDeviceBackendPlatform get platform => AgentDeviceBackendPlatform.android;

  @override
  Future<List<BackendDeviceInfo>> listDevices(
    BackendCommandContext ctx, [
    BackendDeviceFilter? filter,
  ]) async => [
    const BackendDeviceInfo(
      id: 'emulator-5554',
      name: 'Pixel',
      platform: AgentDeviceBackendPlatform.android,
    ),
  ];

  @override
  Future<BackendSnapshotResult> captureSnapshot(
    BackendCommandContext ctx,
    BackendSnapshotOptions? options,
  ) async {
    // Surface-inspection call is identified by interactiveOnly+compact both set.
    final isSurfaceInspection =
        options?.interactiveOnly == true && options?.compact == true;
    if (isSurfaceInspection) {
      if (surfaceThrows) throw Exception('snapshot unavailable');
      return BackendSnapshotResult(nodes: surfaceNodes);
    }
    // Normal polling: return empty so the predicate never passes.
    return const BackendSnapshotResult(nodes: []);
  }
}

// ---------------------------------------------------------------------------
// Clock that advances by [step] ms on each call so timeout fires immediately.
// ---------------------------------------------------------------------------

class _StepClock implements CommandClock {
  int _t = 0;
  final int step;
  _StepClock({required this.step});

  @override
  int now() {
    final t = _t;
    _t += step;
    return t;
  }

  @override
  Future<void> sleep(Duration d) async {}
}

// ---------------------------------------------------------------------------
// Node fixtures (mirrors the TS test fixtures)
// ---------------------------------------------------------------------------

SnapshotNode _node({
  required int index,
  required String type,
  String? label,
  String? identifier,
  Rect? rect,
  bool hittable = false,
  int depth = 0,
}) => SnapshotNode(
  index: index,
  ref: 'r$index',
  type: type,
  label: label,
  identifier: identifier,
  rect: rect,
  hittable: hittable,
  depth: depth,
);

final _locationPermissionNodes = [
  _node(
    index: 0,
    type: 'android.widget.FrameLayout',
    label: 'Location permission',
    rect: Rect(x: 0, y: 0, width: 390, height: 844),
  ),
  _node(
    index: 1,
    type: 'android.widget.TextView',
    label: 'Allow location access?',
    rect: Rect(x: 24, y: 210, width: 342, height: 40),
    depth: 1,
  ),
  _node(
    index: 2,
    type: 'android.widget.Button',
    label: 'Not now',
    rect: Rect(x: 24, y: 320, width: 140, height: 48),
    hittable: true,
    depth: 1,
  ),
  _node(
    index: 3,
    type: 'android.widget.Button',
    label: 'Continue',
    rect: Rect(x: 180, y: 320, width: 160, height: 48),
    hittable: true,
    depth: 1,
  ),
];

final _locationRequiredNodes = [
  _node(
    index: 0,
    type: 'android.widget.TextView',
    label: 'Location required',
    rect: Rect(x: 24, y: 180, width: 342, height: 40),
  ),
  _node(
    index: 1,
    type: 'android.widget.Button',
    label: 'Dismiss',
    rect: Rect(x: 24, y: 260, width: 342, height: 48),
  ),
];

final _iosSurfaceSummaryNodes = [
  _node(
    index: 0,
    type: 'XCUIElementTypeApplication',
    label: 'Expo Go',
    rect: Rect(x: 0, y: 0, width: 393, height: 852),
  ),
  _node(
    index: 1,
    type: 'XCUIElementTypeImage',
    label: 'gearshape.fill',
    rect: Rect(x: 12, y: 54, width: 24, height: 24),
    depth: 1,
  ),
  SnapshotNode(
    index: 2,
    ref: 'r2',
    type: 'XCUIElementTypeOther',
    label: 'Tab Bar',
    rect: Rect(x: 0, y: 760, width: 393, height: 92),
    depth: 1,
  ),
  _node(
    index: 3,
    type: 'XCUIElementTypeStaticText',
    label: 'Confirm catalog refresh',
    rect: Rect(x: 48, y: 280, width: 297, height: 36),
    depth: 1,
  ),
  _node(
    index: 4,
    type: 'XCUIElementTypeButton',
    label: 'Keep browsing',
    rect: Rect(x: 48, y: 360, width: 297, height: 48),
    depth: 1,
  ),
  _node(
    index: 5,
    type: 'XCUIElementTypeButton',
    identifier: 'host.exp.exponent:id/reload_button',
    rect: Rect(x: 260, y: 54, width: 48, height: 48),
    depth: 1,
  ),
];

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

Future<AgentDevice> _openDevice(_FakeBackend backend) =>
    AgentDevice.open(backend: backend, clock: _StepClock(step: 1000));

Future<AppError> _waitUntilTimeout(
  AgentDevice device,
  String selectorSource,
) async {
  try {
    await device.wait(
      'exists',
      InteractionTarget.selector(selectorSource),
      timeout: Duration.zero,
    );
    fail('expected wait to throw');
  } on AppError catch (e) {
    return e;
  }
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  group('wait() timeout surface diagnostics', () {
    test(
      'timeout message includes compact current-surface labels and buttons',
      () async {
        final backend = _FakeBackend(surfaceNodes: _locationPermissionNodes);
        final device = await _openDevice(backend);
        final error = await _waitUntilTimeout(device, 'text="Receipt uploaded"');

        expect(error.message, contains('timed out'));
        expect(error.message, contains('Current surface:'));
        expect(error.message, contains('Allow location access?'));
        expect(error.message, contains('Not now'));
        expect(error.message, contains('Continue'));

        final surface =
            error.details?['currentSurface'] as Map<String, Object?>?;
        expect(surface, isNotNull);
        expect(
          (surface!['labels'] as List).cast<String>(),
          containsAll(['Allow location access?', 'Not now', 'Continue']),
        );
        expect(
          (surface['buttons'] as List).cast<String>(),
          containsAll(['Not now', 'Continue']),
        );
      },
    );

    test(
      'timeout message includes compact current-surface details (selector)',
      () async {
        final backend = _FakeBackend(surfaceNodes: _locationRequiredNodes);
        final device = await _openDevice(backend);
        final error = await _waitUntilTimeout(device, 'id=receipt-uploaded');

        expect(error.message, contains('timed out'));
        expect(error.message, contains('Current surface:'));
        expect(error.message, contains('Location required'));

        final surface =
            error.details?['currentSurface'] as Map<String, Object?>?;
        expect(surface, isNotNull);
        expect(
          (surface!['labels'] as List).cast<String>(),
          containsAll(['Location required', 'Dismiss']),
        );
        expect(
          (surface['buttons'] as List).cast<String>(),
          contains('Dismiss'),
        );
      },
    );

    test(
      'timeout summary prefers content labels over chrome and identifier noise',
      () async {
        final backend = _FakeBackend(surfaceNodes: _iosSurfaceSummaryNodes);
        final device = await _openDevice(backend);
        final error = await _waitUntilTimeout(
          device,
          'text="Impossible success text"',
        );

        expect(error.message, contains('timed out'));
        expect(error.message, contains('Current surface:'));
        // Non-chrome content nodes appear in the summary.
        expect(error.message, contains('Confirm catalog refresh'));
        expect(error.message, contains('Keep browsing'));

        final surface =
            error.details?['currentSurface'] as Map<String, Object?>?;
        expect(surface, isNotNull);
        final labels = (surface!['labels'] as List).cast<String>();
        expect(labels, contains('Confirm catalog refresh'));
        expect(labels, contains('Keep browsing'));
        // Chrome/identifier noise appears in full labels list but not summary.
        expect(labels, contains('Expo Go'));

        final buttons = (surface['buttons'] as List).cast<String>();
        expect(buttons, contains('Keep browsing'));
      },
    );

    test(
      'timeout preserves current behavior when surface inspection fails',
      () async {
        final backend = _FakeBackend(surfaceThrows: true);
        final device = await _openDevice(backend);
        final error = await _waitUntilTimeout(device, 'text="Receipt uploaded"');

        expect(error.message, contains('timed out'));
        // No current surface info when snapshot fails.
        expect(error.message, isNot(contains('Current surface')));
        expect(error.details?['currentSurface'], isNull);
        // Base details are still present.
        expect(error.details?['predicate'], 'exists');
        expect(error.details?['timeoutMs'], isNotNull);
      },
    );
  });
}
