// Port of upstream tests from:
//   src/__tests__/runtime-interactions.test.ts (covered/duplicate-covered cases)
//   src/daemon/handlers/__tests__/snapshot-capture.test.ts (buildSnapshotState occlusion cases)
@TestOn('vm')
library;

import 'package:agent_device/src/commands/interaction_targeting.dart';
import 'package:agent_device/src/snapshot/snapshot.dart';
import 'package:agent_device/src/snapshot/snapshot_occlusion.dart';
import 'package:test/test.dart';

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

/// Build a minimal flat list of [RawSnapshotNode]s from JSON-like maps.
List<RawSnapshotNode> _makeNodes(List<Map<String, Object?>> data) {
  return data.map((d) {
    final rectData = d['rect'] as Map<String, Object?>?;
    Rect? rect;
    if (rectData != null) {
      rect = Rect(
        x: (rectData['x'] as num).toDouble(),
        y: (rectData['y'] as num).toDouble(),
        width: (rectData['width'] as num).toDouble(),
        height: (rectData['height'] as num).toDouble(),
      );
    }
    return RawSnapshotNode(
      index: d['index'] as int,
      depth: d['depth'] as int?,
      parentIndex: d['parentIndex'] as int?,
      type: d['type'] as String?,
      label: d['label'] as String?,
      rect: rect,
      hittable: d['hittable'] as bool?,
    );
  }).toList();
}

// ---------------------------------------------------------------------------
// annotateCoveredSnapshotNodes
// ---------------------------------------------------------------------------

void main() {
  group('annotateCoveredSnapshotNodes', () {
    test('returns the same list reference when nothing is covered', () {
      final nodes = _makeNodes([
        {
          'index': 0,
          'depth': 0,
          'type': 'Application',
          'rect': {'x': 0, 'y': 0, 'width': 390, 'height': 844},
        },
        {
          'index': 1,
          'depth': 1,
          'parentIndex': 0,
          'type': 'Button',
          'label': 'Visible action',
          'rect': {'x': 40, 'y': 100, 'width': 160, 'height': 44},
          'hittable': true,
        },
      ]);
      final result = annotateCoveredSnapshotNodes(nodes);
      expect(identical(result, nodes), isTrue);
    });

    test('marks a button covered by a TabBar overlay', () {
      // Button center (86, 812) is inside TabBar rect (0, 760, 390, 84).
      final nodes = _makeNodes([
        {
          'index': 0,
          'depth': 0,
          'type': 'Application',
          'label': 'Example',
          'rect': {'x': 0, 'y': 0, 'width': 390, 'height': 844},
        },
        {
          'index': 1,
          'depth': 1,
          'parentIndex': 0,
          'type': 'Button',
          'label': 'Save draft',
          'rect': {'x': 16, 'y': 790, 'width': 140, 'height': 44},
          'hittable': true,
        },
        {
          'index': 2,
          'depth': 1,
          'parentIndex': 0,
          'type': 'TabBar',
          'rect': {'x': 0, 'y': 760, 'width': 390, 'height': 84},
          'hittable': true,
        },
      ]);

      final result = annotateCoveredSnapshotNodes(nodes);

      final covered = result.firstWhere((n) => n.label == 'Save draft');
      expect(covered.hittable, isFalse);
      expect(covered.interactionBlocked, equals('covered'));
      expect(covered.presentationHints, contains('covered'));

      // TabBar itself should not be annotated.
      final tabBar = result.firstWhere((n) => n.type == 'TabBar');
      expect(tabBar.interactionBlocked, isNull);
    });

    test('does not treat later generic hittable containers as covers', () {
      // A CollectionView appearing after a Button is not overlay-like.
      final nodes = _makeNodes([
        {
          'index': 0,
          'depth': 0,
          'type': 'Application',
          'rect': {'x': 0, 'y': 0, 'width': 390, 'height': 844},
        },
        {
          'index': 1,
          'depth': 1,
          'parentIndex': 0,
          'type': 'Button',
          'label': 'Visible action',
          'rect': {'x': 40, 'y': 100, 'width': 160, 'height': 44},
          'hittable': true,
        },
        {
          'index': 2,
          'depth': 1,
          'parentIndex': 0,
          'type': 'CollectionView',
          'label': 'Content list',
          'rect': {'x': 0, 'y': 80, 'width': 390, 'height': 600},
          'hittable': true,
        },
      ]);

      final result = annotateCoveredSnapshotNodes(nodes);

      final button = result.firstWhere((n) => n.label == 'Visible action');
      expect(button.hittable, isTrue);
      expect(button.interactionBlocked, isNull);
    });

    test('does not annotate an ancestor-covered node when the overlay is its parent', () {
      // A button that is a direct descendant of a TabBar should not be
      // annotated as covered because they are related nodes.
      final nodes = _makeNodes([
        {
          'index': 0,
          'depth': 0,
          'type': 'Application',
          'rect': {'x': 0, 'y': 0, 'width': 390, 'height': 844},
        },
        {
          'index': 1,
          'depth': 1,
          'parentIndex': 0,
          'type': 'TabBar',
          'rect': {'x': 0, 'y': 760, 'width': 390, 'height': 84},
          'hittable': true,
        },
        {
          'index': 2,
          'depth': 2,
          'parentIndex': 1,
          'type': 'Button',
          'label': 'Home tab',
          'rect': {'x': 16, 'y': 772, 'width': 80, 'height': 60},
          'hittable': true,
        },
      ]);

      final result = annotateCoveredSnapshotNodes(nodes);

      // The tab button inside the TabBar must NOT be annotated as covered.
      final tabButton = result.firstWhere((n) => n.label == 'Home tab');
      expect(tabButton.interactionBlocked, isNull);
    });

    test('preserves existing presentationHints when annotating covered', () {
      final nodes = [
        RawSnapshotNode(
          index: 0,
          depth: 0,
          type: 'Application',
          rect: const Rect(x: 0, y: 0, width: 390, height: 844),
        ),
        RawSnapshotNode(
          index: 1,
          depth: 1,
          parentIndex: 0,
          type: 'Button',
          label: 'Save draft',
          rect: const Rect(x: 16, y: 790, width: 140, height: 44),
          hittable: true,
          presentationHints: ['someHint'],
        ),
        RawSnapshotNode(
          index: 2,
          depth: 1,
          parentIndex: 0,
          type: 'TabBar',
          rect: const Rect(x: 0, y: 760, width: 390, height: 84),
          hittable: true,
        ),
      ];

      final result = annotateCoveredSnapshotNodes(nodes);

      final covered = result.firstWhere((n) => n.label == 'Save draft');
      expect(covered.presentationHints, containsAll(['someHint', 'covered']));
    });

    test('returns the original list when fewer than 2 nodes', () {
      final nodes = _makeNodes([
        {
          'index': 0,
          'depth': 0,
          'type': 'Button',
          'rect': {'x': 0, 'y': 0, 'width': 100, 'height': 40},
          'hittable': true,
        },
      ]);
      final result = annotateCoveredSnapshotNodes(nodes);
      expect(identical(result, nodes), isTrue);
    });
  });

  // -------------------------------------------------------------------------
  // isSnapshotNodeInteractionBlocked
  // -------------------------------------------------------------------------

  group('isSnapshotNodeInteractionBlocked', () {
    test('returns false when interactionBlocked is null', () {
      final node = RawSnapshotNode(index: 0, type: 'Button');
      expect(isSnapshotNodeInteractionBlocked(node), isFalse);
    });

    test('returns true when interactionBlocked is "covered"', () {
      final node = RawSnapshotNode(
        index: 0,
        type: 'Button',
        interactionBlocked: 'covered',
      );
      expect(isSnapshotNodeInteractionBlocked(node), isTrue);
    });
  });

  // -------------------------------------------------------------------------
  // Interaction-targeting integration: covered reason
  // -------------------------------------------------------------------------

  group('resolveActionableTouchResolution with covered nodes', () {
    test('reports covered reason when the target node is interaction-blocked', () {
      // Simulate a pre-annotated node (interactionBlocked = 'covered').
      final coveredButton = SnapshotNode(
        index: 1,
        ref: 'e2',
        type: 'Button',
        label: 'Save draft',
        rect: const Rect(x: 16, y: 790, width: 140, height: 44),
        hittable: false,
        interactionBlocked: 'covered',
        presentationHints: ['covered'],
      );
      final app = SnapshotNode(
        index: 0,
        ref: 'e1',
        type: 'Application',
        rect: const Rect(x: 0, y: 0, width: 390, height: 844),
        hittable: true,
      );
      final tabBar = SnapshotNode(
        index: 2,
        ref: 'e3',
        type: 'TabBar',
        rect: const Rect(x: 0, y: 760, width: 390, height: 84),
        hittable: true,
      );
      final nodes = [app, coveredButton, tabBar];

      final resolution = resolveActionableTouchResolution(nodes, coveredButton);

      expect(resolution.reason, ActionableTouchResolutionReason.covered);
      expect(resolution.node.ref, equals('e2'));
    });

    test('does not climb to a covered hittable ancestor', () {
      // Target node is not covered, but its hittable ancestor is.
      final text = SnapshotNode(
        index: 0,
        ref: 'e1',
        type: 'text',
        label: 'Click me',
        rect: const Rect(x: 16, y: 790, width: 80, height: 20),
        hittable: false,
        parentIndex: 1,
      );
      final coveredButton = SnapshotNode(
        index: 1,
        ref: 'e2',
        type: 'Button',
        rect: const Rect(x: 16, y: 790, width: 140, height: 44),
        hittable: false,
        interactionBlocked: 'covered',
        parentIndex: 2,
      );
      final app = SnapshotNode(
        index: 2,
        ref: 'e3',
        type: 'Application',
        rect: const Rect(x: 0, y: 0, width: 390, height: 844),
        hittable: true,
      );
      final nodes = [text, coveredButton, app];

      final resolution = resolveActionableTouchResolution(nodes, text);

      // Should NOT return the covered button as the hittable ancestor.
      expect(resolution.node.ref, isNot(equals('e2')));
    });
  });

  // Guards the full pipeline contract the backends rely on: annotation must
  // survive attachRefs, and interaction targeting must then report 'covered'.
  // (Regression guard for the annotateCoveredSnapshotNodes wiring in the iOS
  // and Android snapshot backends.)
  group('annotate → attachRefs → interaction targeting', () {
    test('a covered node resolves with the covered reason end-to-end', () {
      final nodes = _makeNodes([
        {
          'index': 0,
          'depth': 0,
          'type': 'Application',
          'label': 'Example',
          'rect': {'x': 0, 'y': 0, 'width': 390, 'height': 844},
        },
        {
          'index': 1,
          'depth': 1,
          'parentIndex': 0,
          'type': 'Button',
          'label': 'Save draft',
          'rect': {'x': 16, 'y': 790, 'width': 140, 'height': 44},
          'hittable': true,
        },
        {
          'index': 2,
          'depth': 1,
          'parentIndex': 0,
          'type': 'TabBar',
          'rect': {'x': 0, 'y': 760, 'width': 390, 'height': 84},
          'hittable': true,
        },
      ]);

      final snapshotNodes = attachRefs(annotateCoveredSnapshotNodes(nodes));
      final button = snapshotNodes.firstWhere((n) => n.label == 'Save draft');

      // attachRefs must carry interactionBlocked through to the SnapshotNode.
      expect(button.interactionBlocked, equals('covered'));

      final resolution = resolveActionableTouchResolution(snapshotNodes, button);
      expect(
        resolution.reason,
        ActionableTouchResolutionReason.covered,
      );
    });
  });
}
