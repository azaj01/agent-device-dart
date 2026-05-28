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

    test('promotes unlabeled hittable action rows with passive text content', () {
      // Mirrors "formatSnapshotText promotes Android helper unlabeled action rows"
      final nodes = [
        SnapshotNode(
          index: 0,
          ref: 'e1',
          depth: 0,
          type: 'android.widget.FrameLayout',
          rect: Rect(x: 0, y: 0, width: 390, height: 844),
        ),
        SnapshotNode(
          index: 1,
          ref: 'e2',
          depth: 1,
          parentIndex: 0,
          type: 'android.widget.LinearLayout',
          rect: Rect(x: 0, y: 160, width: 390, height: 72),
          hittable: true,
          // no label — should be promoted from descendants
        ),
        SnapshotNode(
          index: 2,
          ref: 'e3',
          depth: 2,
          parentIndex: 1,
          type: 'android.widget.ImageView',
          rect: Rect(x: 24, y: 176, width: 32, height: 32),
        ),
        SnapshotNode(
          index: 3,
          ref: 'e4',
          depth: 2,
          parentIndex: 1,
          type: 'android.widget.TextView',
          label: 'Network & internet',
          rect: Rect(x: 72, y: 168, width: 260, height: 28),
        ),
        SnapshotNode(
          index: 4,
          ref: 'e5',
          depth: 2,
          parentIndex: 1,
          type: 'android.widget.TextView',
          label: 'Mobile, Wi-Fi, hotspot',
          rect: Rect(x: 72, y: 198, width: 260, height: 24),
        ),
      ];
      final data = {'androidSnapshot': {'backend': 'android-helper'}};

      final result = buildAndroidHelperPresentationInput(data, nodes);

      // 3 nodes collapsed (ImageView + 2x TextView), 2 visible remain
      expect(result.filteredCount, equals(3));
      expect(result.nodes.length, equals(2));
      // The LinearLayout (index 1) gets promoted label from its TextViews
      final row = result.nodes.firstWhere((n) => n.index == 1);
      expect(row.label, equals('Network & internet, Mobile, Wi-Fi, hotspot'));
      // Neither text child appears in output
      expect(result.nodes.any((n) => n.index == 3), isFalse);
      expect(result.nodes.any((n) => n.index == 4), isFalse);
    });

    test('keeps passive descendants outside parent bounds when promoting row label', () {
      // Mirrors "formatSnapshotText keeps passive row descendants that were not promoted"
      final nodes = [
        SnapshotNode(
          index: 0,
          ref: 'e1',
          depth: 0,
          type: 'android.widget.FrameLayout',
          rect: Rect(x: 0, y: 0, width: 390, height: 844),
        ),
        SnapshotNode(
          index: 1,
          ref: 'e2',
          depth: 1,
          parentIndex: 0,
          type: 'android.widget.LinearLayout',
          rect: Rect(x: 0, y: 160, width: 390, height: 72),
          hittable: true,
        ),
        SnapshotNode(
          index: 2,
          ref: 'e3',
          depth: 2,
          parentIndex: 1,
          type: 'android.widget.TextView',
          label: 'Inside row',
          rect: Rect(x: 72, y: 176, width: 260, height: 28),
        ),
        SnapshotNode(
          index: 3,
          ref: 'e4',
          depth: 2,
          parentIndex: 1,
          type: 'android.widget.TextView',
          label: 'Outside parent bounds',
          rect: Rect(x: 72, y: 260, width: 260, height: 28), // y=260, outside parent y+h=232
        ),
      ];
      final data = {'androidSnapshot': {'backend': 'android-helper'}};

      final result = buildAndroidHelperPresentationInput(data, nodes);

      // Only the inside TextView (index 2) is promoted and removed
      expect(result.filteredCount, equals(1));
      expect(result.nodes.length, equals(3));
      // Row gets label from inside descendant
      final row = result.nodes.firstWhere((n) => n.index == 1);
      expect(row.label, equals('Inside row'));
      // Inside child removed
      expect(result.nodes.any((n) => n.index == 2), isFalse);
      // Outside child kept
      expect(result.nodes.any((n) => n.index == 3), isTrue);
    });

    test('keeps single repeated child control in action row', () {
      // Mirrors "formatSnapshotText keeps single repeated child control in Android helper output"
      final nodes = [
        SnapshotNode(
          index: 0,
          ref: 'e1',
          depth: 0,
          type: 'android.widget.FrameLayout',
          rect: Rect(x: 0, y: 0, width: 390, height: 844),
        ),
        SnapshotNode(
          index: 1,
          ref: 'e2',
          depth: 1,
          parentIndex: 0,
          type: 'android.widget.Button',
          label: 'Send message',
          rect: Rect(x: 16, y: 700, width: 358, height: 56),
          hittable: true,
        ),
        SnapshotNode(
          index: 2,
          ref: 'e3',
          depth: 2,
          parentIndex: 1,
          type: 'android.widget.Button',
          label: 'Send',
          rect: Rect(x: 290, y: 708, width: 64, height: 40),
          hittable: true,
        ),
      ];
      final data = {'androidSnapshot': {'backend': 'android-helper'}};

      final result = buildAndroidHelperPresentationInput(data, nodes);

      // Only one repeated control → not enough to collapse (need ≥2 distinct controls)
      expect(result.filteredCount, equals(0));
      expect(result.nodes.length, equals(3));
      expect(result.nodes.any((n) => n.index == 1), isTrue);
      expect(result.nodes.any((n) => n.index == 2), isTrue);
    });

    test('promotes unlabeled action rows but keeps hittable trailing controls', () {
      // Mirrors "formatSnapshotText labels Android helper action rows with trailing child controls"
      final nodes = [
        SnapshotNode(
          index: 0,
          ref: 'e1',
          depth: 0,
          type: 'android.widget.FrameLayout',
          rect: Rect(x: 0, y: 0, width: 390, height: 844),
        ),
        SnapshotNode(
          index: 1,
          ref: 'e2',
          depth: 1,
          parentIndex: 0,
          type: 'android.view.ViewGroup',
          identifier: 'com.google.android.youtube:id/linearLayout',
          rect: Rect(x: 0, y: 120, width: 390, height: 48),
          hittable: true,
          // no label — should be promoted from text descendant
        ),
        SnapshotNode(
          index: 2,
          ref: 'e3',
          depth: 2,
          parentIndex: 1,
          type: 'android.widget.ImageView',
          rect: Rect(x: 4, y: 132, width: 40, height: 24),
        ),
        SnapshotNode(
          index: 3,
          ref: 'e4',
          depth: 2,
          parentIndex: 1,
          type: 'android.widget.TextView',
          label: 'lofi hip hop',
          rect: Rect(x: 52, y: 132, width: 260, height: 24),
        ),
        SnapshotNode(
          index: 4,
          ref: 'e5',
          depth: 2,
          parentIndex: 1,
          type: 'android.widget.ImageView',
          label: 'Edit suggestion lofi hip hop',
          rect: Rect(x: 330, y: 120, width: 48, height: 48),
          hittable: true, // hittable — not passive, should not be promoted/removed
        ),
      ];
      final data = {'androidSnapshot': {'backend': 'android-helper'}};

      final result = buildAndroidHelperPresentationInput(data, nodes);

      // 2 passive descendants (ImageView + TextView) removed; 3 nodes remain
      expect(result.filteredCount, equals(2));
      expect(result.nodes.length, equals(3));
      // ViewGroup gets label from passive TextView
      final row = result.nodes.firstWhere((n) => n.index == 1);
      expect(row.label, equals('lofi hip hop'));
      // Passive text child removed
      expect(result.nodes.any((n) => n.index == 3), isFalse);
      // Hittable image child kept
      expect(result.nodes.any((n) => n.index == 4), isTrue);
    });

    test('hides rectless scrollable descendants and derives direction hints', () {
      // Mirrors "formatSnapshotText hides Android helper rectless offscreen rows
      //          and derives above hints"
      final nodes = [
        SnapshotNode(
          index: 0,
          ref: 'e1',
          depth: 0,
          type: 'android.widget.FrameLayout',
          rect: Rect(x: 0, y: 0, width: 390, height: 844),
        ),
        SnapshotNode(
          index: 1,
          ref: 'e2',
          depth: 1,
          parentIndex: 0,
          type: 'android.widget.ScrollView',
          rect: Rect(x: 0, y: 120, width: 390, height: 640),
          hiddenContentBelow: true,
        ),
        // No rect → offscreen, index 2 < rendered sibling index 3 → 'above'
        SnapshotNode(
          index: 2,
          ref: 'e3',
          depth: 2,
          parentIndex: 1,
          type: 'android.widget.Button',
          label: 'Save Citrus Starter Kit',
          hittable: true,
          // no rect
        ),
        SnapshotNode(
          index: 3,
          ref: 'e4',
          depth: 2,
          parentIndex: 1,
          type: 'android.widget.Button',
          label: 'View details',
          identifier: 'details-pretzel-bites',
          rect: Rect(x: 24, y: 180, width: 342, height: 48),
          hittable: true,
        ),
        SnapshotNode(
          index: 4,
          ref: 'e5',
          depth: 3,
          parentIndex: 3,
          type: 'android.widget.TextView',
          label: 'View details',
          rect: Rect(x: 140, y: 192, width: 110, height: 24),
        ),
      ];
      final data = {'androidSnapshot': {'backend': 'android-helper'}};

      final result = buildAndroidHelperPresentationInput(data, nodes);

      // Rectless button (index 2) + its "View details" text child (index 4, collapsed
      // by adjacent duplicate logic) → 2 filtered
      expect(result.filteredCount, equals(2));
      expect(result.nodes.length, equals(3));
      // Rectless button removed
      expect(result.nodes.any((n) => n.index == 2), isFalse);
      // Visible button kept
      expect(result.nodes.any((n) => n.index == 3), isTrue);
      // ScrollView gets hiddenContentAbove hint (rectless button was above rendered sibling)
      final scrollView = result.nodes.firstWhere((n) => n.index == 1);
      expect(scrollView.hiddenContentAbove, isTrue);
      // Pre-existing hiddenContentBelow preserved
      expect(scrollView.hiddenContentBelow, isTrue);
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
