// Port of agent-device/src/core/__tests__/dispatch-scroll.test.ts
// (scroll-edge-state coverage only — daemon/CLI dispatch layer not ported)
import 'package:agent_device/src/snapshot/snapshot.dart';
import 'package:agent_device/src/utils/errors.dart';
import 'package:agent_device/src/utils/scroll_edge_state.dart';
import 'package:test/test.dart';

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

/// Build a minimal snapshot with one ScrollView container and one child.
List<SnapshotNode> makeScrollSnapshot({
  required bool hiddenBelow,
  required String message,
}) {
  return [
    SnapshotNode(
      index: 1,
      ref: 'e1',
      type: 'ScrollView',
      label: 'Messages',
      hiddenContentBelow: hiddenBelow ? true : null,
      rect: const Rect(x: 0, y: 100, width: 400, height: 600),
    ),
    SnapshotNode(
      index: 2,
      ref: 'e2',
      parentIndex: 1,
      type: 'Button',
      label: message,
      rect: const Rect(x: 0, y: 640, width: 400, height: 56),
    ),
  ];
}

// ---------------------------------------------------------------------------
// analyzeScrollEdgeState
// ---------------------------------------------------------------------------

void main() {
  group('analyzeScrollEdgeState', () {
    test('returns emptySnapshot=true for empty node list', () {
      final state = analyzeScrollEdgeState([], 'bottom');
      expect(state.emptySnapshot, isTrue);
      expect(state.canScroll, isFalse);
      expect(state.signature, isEmpty);
    });

    test('returns canScroll=false when no scrollable container is found', () {
      final nodes = [
        SnapshotNode(
          index: 1,
          ref: 'e1',
          type: 'Button',
          label: 'OK',
          rect: const Rect(x: 0, y: 0, width: 100, height: 44),
        ),
      ];
      final state = analyzeScrollEdgeState(nodes, 'bottom');
      expect(state.canScroll, isFalse);
      expect(state.emptySnapshot, isFalse);
    });

    test('returns canScroll=false when scrollable has no hidden content below', () {
      final nodes = makeScrollSnapshot(hiddenBelow: false, message: 'Hello');
      final state = analyzeScrollEdgeState(nodes, 'bottom');
      expect(state.canScroll, isFalse);
      expect(state.emptySnapshot, isFalse);
    });

    test('returns canScroll=true when scrollable has hidden content below', () {
      final nodes = makeScrollSnapshot(hiddenBelow: true, message: 'Hello');
      final state = analyzeScrollEdgeState(nodes, 'bottom');
      expect(state.canScroll, isTrue);
      expect(state.emptySnapshot, isFalse);
    });

    test('extracts scope from scrollable container label', () {
      final nodes = makeScrollSnapshot(hiddenBelow: true, message: 'Hello');
      final state = analyzeScrollEdgeState(nodes, 'bottom');
      expect(state.scope, equals('Messages'));
    });

    test('scope is null when scrollable has no useful label/id/value', () {
      final nodes = [
        SnapshotNode(
          index: 1,
          ref: 'e1',
          type: 'ScrollView',
          hiddenContentBelow: true,
          rect: const Rect(x: 0, y: 0, width: 400, height: 800),
        ),
      ];
      final state = analyzeScrollEdgeState(nodes, 'bottom');
      expect(state.scope, isNull);
    });

    test('produces deterministic non-empty signature', () {
      final nodes = makeScrollSnapshot(hiddenBelow: false, message: 'Hello');
      final state1 = analyzeScrollEdgeState(nodes, 'bottom');
      final state2 = analyzeScrollEdgeState(nodes, 'bottom');
      expect(state1.signature, isNotEmpty);
      expect(state1.signature, equals(state2.signature));
    });
  });

  // ---------------------------------------------------------------------------
  // captureScrollEdgeState
  // ---------------------------------------------------------------------------

  group('captureScrollEdgeState', () {
    test('returns state from captureNodes', () async {
      final nodes = makeScrollSnapshot(hiddenBelow: true, message: 'Latest');
      final state = await captureScrollEdgeState(
        edge: 'bottom',
        captureNodes: (_) async => nodes,
      );
      expect(state.canScroll, isTrue);
    });

    test('retries without scope when scoped snapshot is empty', () async {
      var callCount = 0;
      final state = await captureScrollEdgeState(
        edge: 'bottom',
        scope: 'Messages',
        captureNodes: (scope) async {
          callCount++;
          if (scope != null) return []; // scoped call returns empty
          return makeScrollSnapshot(hiddenBelow: false, message: 'Hello');
        },
      );
      expect(callCount, equals(2));
      expect(state.emptySnapshot, isFalse);
    });

    test('wraps errors in COMMAND_FAILED AppError', () async {
      await expectLater(
        () => captureScrollEdgeState(
          edge: 'bottom',
          captureNodes: (_) async => throw Exception('network error'),
        ),
        throwsA(
          isA<AppError>()
              .having((e) => e.code, 'code', AppErrorCodes.commandFailed)
              .having(
                (e) => e.message,
                'message',
                contains('scroll bottom'),
              ),
        ),
      );
    });

    test('scoped error message names the scope', () async {
      await expectLater(
        () => captureScrollEdgeState(
          edge: 'top',
          scope: 'Messages',
          captureNodes: (_) async => throw Exception('boom'),
        ),
        throwsA(
          isA<AppError>()
              .having(
                (e) => e.message,
                'message',
                contains('scoped container'),
              )
              .having(
                (e) => e.details?['scope'],
                'scope',
                equals('Messages'),
              ),
        ),
      );
    });
  });

  // ---------------------------------------------------------------------------
  // runScrollEdgePasses
  // ---------------------------------------------------------------------------

  group('runScrollEdgePasses', () {
    test('does not scroll when no hidden content at edge', () async {
      final scrollCalls = <String>[];
      final result = await runScrollEdgePasses<String>(
        edge: 'bottom',
        captureState: (_) async => analyzeScrollEdgeState(
          makeScrollSnapshot(hiddenBelow: false, message: 'Done'),
          'bottom',
        ),
        scroll: () async {
          scrollCalls.add('scroll');
          return 'ok';
        },
      );
      expect(scrollCalls, isEmpty);
      expect(result.passes, equals(0));
      expect(result.result, isNull);
    });

    test('scrolls while hidden content is reported and stops when done', () async {
      var captureCount = 0;
      final snapshots = [
        makeScrollSnapshot(hiddenBelow: true, message: 'Middle'),
        makeScrollSnapshot(hiddenBelow: true, message: 'Middle'), // scope re-check
        makeScrollSnapshot(hiddenBelow: false, message: 'Bottom'),
      ];
      final scrollCalls = <int>[];
      final result = await runScrollEdgePasses<int>(
        edge: 'bottom',
        captureState: (_) async {
          final idx = captureCount.clamp(0, snapshots.length - 1);
          captureCount++;
          return analyzeScrollEdgeState(snapshots[idx], 'bottom');
        },
        scroll: () async {
          final n = scrollCalls.length + 1;
          scrollCalls.add(n);
          return n;
        },
      );
      expect(scrollCalls.length, equals(1));
      expect(result.passes, equals(1));
      expect(result.result, equals(1));
    });

    test('throws COMMAND_FAILED when safety limit is reached', () async {
      await expectLater(
        () => runScrollEdgePasses<void>(
          edge: 'bottom',
          captureState: (_) async => analyzeScrollEdgeState(
            makeScrollSnapshot(hiddenBelow: true, message: 'Forever'),
            'bottom',
          ),
          scroll: () async {},
        ),
        throwsA(
          isA<AppError>()
              .having((e) => e.code, 'code', AppErrorCodes.commandFailed)
              .having(
                (e) => e.message,
                'message',
                contains('safety limit'),
              ),
        ),
      );
    });
  });

  // ---------------------------------------------------------------------------
  // formatScrollEdgeMessage
  // ---------------------------------------------------------------------------

  group('formatScrollEdgeMessage', () {
    test('already at edge when passes=0', () {
      expect(
        formatScrollEdgeMessage('down', 'bottom', 0, null, null),
        equals('Already at bottom; no hidden content below detected'),
      );
      expect(
        formatScrollEdgeMessage('up', 'top', 0, null, null),
        equals('Already at top; no hidden content above detected'),
      );
    });

    test('scrolled to edge with pass count when edge and passes>0', () {
      expect(
        formatScrollEdgeMessage('down', 'bottom', 3, null, null),
        equals('Scrolled to bottom with 3 down passes'),
      );
    });

    test('scrolled by pixels when no edge', () {
      expect(
        formatScrollEdgeMessage('up', null, 1, null, 200),
        equals('Scrolled up by 200px'),
      );
    });

    test('scrolled by amount when no edge and no pixels', () {
      expect(
        formatScrollEdgeMessage('left', null, 1, 0.5, null),
        equals('Scrolled left by 0.5'),
      );
    });

    test('plain scrolled when no edge, amount, or pixels', () {
      expect(
        formatScrollEdgeMessage('right', null, 1, null, null),
        equals('Scrolled right'),
      );
    });
  });
}

