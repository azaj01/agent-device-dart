// Unit tests for Android helper snapshot filtering.
@TestOn('vm')
library;

import 'package:agent_device/src/snapshot/snapshot.dart';
import 'package:agent_device/src/utils/android_helper_snapshot_presentation.dart';
import 'package:test/test.dart';

void main() {
  group('buildAndroidHelperPresentationInput', () {
    test('returns unfiltered nodes when raw=true', () {
      final nodes = [
        SnapshotNode(
          index: 0,
          ref: '@0',
          rect: Rect(x: 0, y: 0, width: 100, height: 100),
        ),
        SnapshotNode(
          index: 1,
          ref: '@1',
          rect: Rect(x: 10, y: 10, width: 0, height: 0), // zero area
        ),
      ];
      final data = {
        'androidSnapshot': {'backend': 'android-helper'},
      };

      final result = buildAndroidHelperPresentationInput(
        data,
        nodes,
        raw: true,
      );

      expect(result.nodes, equals(nodes));
      expect(result.filteredCount, equals(0));
    });

    test('returns unfiltered nodes when not from android-helper', () {
      final nodes = [
        SnapshotNode(
          index: 0,
          ref: '@0',
          rect: Rect(x: 0, y: 0, width: 100, height: 100),
        ),
        SnapshotNode(
          index: 1,
          ref: '@1',
          rect: Rect(x: 10, y: 10, width: 0, height: 0), // zero area
        ),
      ];
      final data = {
        'androidSnapshot': {'backend': 'uiautomator'},
      };

      final result = buildAndroidHelperPresentationInput(data, nodes);

      expect(result.nodes, equals(nodes));
      expect(result.filteredCount, equals(0));
    });

    test('filters zero-area nodes when from android-helper', () {
      final nodes = [
        SnapshotNode(
          index: 0,
          ref: '@0',
          rect: Rect(x: 0, y: 0, width: 100, height: 100),
          parentIndex: null, // root node
        ),
        SnapshotNode(
          index: 1,
          ref: '@1',
          rect: Rect(x: 10, y: 10, width: 0, height: 0), // zero area, non-root
          parentIndex: 0,
        ),
        SnapshotNode(
          index: 2,
          ref: '@2',
          rect: Rect(
            x: 20,
            y: 20,
            width: 50,
            height: 0,
          ), // zero height, non-root
          parentIndex: 0,
        ),
      ];
      final data = {
        'androidSnapshot': {'backend': 'android-helper'},
      };

      final result = buildAndroidHelperPresentationInput(data, nodes);

      expect(result.nodes.length, equals(1));
      expect(result.nodes.first.index, equals(0));
      expect(result.filteredCount, equals(2));
    });

    test('preserves root nodes even with zero area', () {
      final nodes = [
        SnapshotNode(
          index: 0,
          ref: '@0',
          rect: Rect(x: 0, y: 0, width: 0, height: 0), // zero area but root
          parentIndex: null,
        ),
        SnapshotNode(
          index: 1,
          ref: '@1',
          rect: Rect(x: 10, y: 10, width: 0, height: 0), // zero area, non-root
          parentIndex: 0,
        ),
      ];
      final data = {
        'androidSnapshot': {'backend': 'android-helper'},
      };

      final result = buildAndroidHelperPresentationInput(data, nodes);

      // Root node is preserved, non-root zero-area child is removed
      expect(result.nodes.length, equals(1));
      expect(result.nodes.first.index, equals(0));
      expect(result.filteredCount, equals(1));
    });
  });

  group('detectPossibleRepeatedNavSubtree', () {
    test('returns false for small snapshots', () {
      final nodes = List.generate(
        10,
        (i) => SnapshotNode(index: i, ref: '@$i', label: 'Button'),
      );

      expect(detectPossibleRepeatedNavSubtree(nodes), isFalse);
    });

    test('returns false when duplicate count is below threshold', () {
      // Create a 20-node snapshot with mostly unique labels
      final nodes = List.generate(
        20,
        (i) => SnapshotNode(
          index: i,
          ref: '@$i',
          type: 'button',
          label: 'Button$i', // All unique
        ),
      );

      expect(detectPossibleRepeatedNavSubtree(nodes), isFalse);
    });

    test('returns true when duplicate count reaches threshold', () {
      // Create a 20-node snapshot with 10 identical buttons
      final nodes = <SnapshotNode>[
        ...List<SnapshotNode>.generate(
          10,
          (i) => SnapshotNode(
            index: i,
            ref: '@$i',
            type: 'button',
            label: 'Home', // Same label repeated
          ),
        ),
        ...List.generate(
          10,
          (i) => SnapshotNode(
            index: i + 10,
            ref: '@${i + 10}',
            type: 'button',
            label: 'Item$i',
          ),
        ),
      ];

      // 10 "Home" buttons = duplicateCount >= 8, so should return true
      expect(detectPossibleRepeatedNavSubtree(nodes), isTrue);
    });

    test('ignores email-like labels in repeated node detection', () {
      final nodes = List.generate(
        20,
        (i) => SnapshotNode(
          index: i,
          ref: '@$i',
          label: i < 10 ? 'user@example.com' : 'Button$i',
        ),
      );

      // Email labels are normalized to null and not counted
      expect(detectPossibleRepeatedNavSubtree(nodes), isFalse);
    });
  });
}
