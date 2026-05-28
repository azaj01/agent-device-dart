// Tests for detectPossibleRepeatedNavSubtree.
// Port of agent-device/src/utils/__tests__/repeated-nav-subtree.test.ts
@TestOn('vm')
library;

import 'package:agent_device/src/snapshot/snapshot.dart';
import 'package:agent_device/src/utils/repeated_nav_subtree.dart';
import 'package:test/test.dart';

void main() {
  // ---------------------------------------------------------------------------
  // Helper
  // ---------------------------------------------------------------------------

  List<SnapshotNode> makeNodes(
    int count,
    Map<String, Object?> Function(int index) build,
  ) {
    return List.generate(count, (index) {
      final data = build(index);
      final rectData = data['rect'] as Map<String, Object?>?;
      final rect = rectData != null
          ? Rect(
              x: (rectData['x'] as num).toDouble(),
              y: (rectData['y'] as num).toDouble(),
              width: (rectData['width'] as num).toDouble(),
              height: (rectData['height'] as num).toDouble(),
            )
          : null;
      return SnapshotNode(
        index: index,
        ref: 'e${index + 1}',
        depth: index == 0 ? 0 : 1,
        type: data['type'] as String?,
        label: data['label'] as String?,
        rect: rect,
        hittable: index != 0,
        enabled: true,
      );
    });
  }

  // ---------------------------------------------------------------------------
  // Tests
  // ---------------------------------------------------------------------------

  test('warns for overlapping duplicate rows', () {
    final nodes = makeNodes(24, (index) {
      if (index == 0) {
        return {
          'type': 'android.widget.FrameLayout',
          'label': 'Root',
          'rect': {'x': 0, 'y': 0, 'width': 1080, 'height': 2400},
        };
      }
      return {
        'type': 'android.widget.Button',
        'label': 'Inbox',
        'rect': {'x': 20, 'y': 40, 'width': 300, 'height': 48},
      };
    });

    expect(detectPossibleRepeatedNavSubtree(nodes), isTrue);
  });

  test('does not warn for repeated list rows', () {
    final nodes = makeNodes(24, (index) {
      if (index == 0) {
        return {
          'type': 'android.widget.FrameLayout',
          'label': 'Root',
          'rect': {'x': 0, 'y': 0, 'width': 1080, 'height': 2400},
        };
      }
      return {
        'type': 'android.widget.Button',
        'label': 'Receipt missing details',
        'rect': {'x': 20, 'y': 40 + index * 80, 'width': 300, 'height': 48},
      };
    });

    expect(detectPossibleRepeatedNavSubtree(nodes), isFalse);
  });

  test('tolerates subpixel adjacent list rows', () {
    final nodes = makeNodes(24, (index) {
      if (index == 0) {
        return {
          'type': 'android.widget.FrameLayout',
          'label': 'Root',
          'rect': {'x': 0, 'y': 0, 'width': 1080, 'height': 2400},
        };
      }
      return {
        'type': 'android.widget.Button',
        'label': 'Receipt missing details',
        'rect': {'x': 20, 'y': 40 + index * 63.99998, 'width': 300, 'height': 64},
      };
    });

    expect(detectPossibleRepeatedNavSubtree(nodes), isFalse);
  });

  test('does not warn for small trees', () {
    final nodes = makeNodes(19, (index) {
      return {
        'type': 'android.widget.Button',
        'label': 'Inbox',
        'rect': {'x': 20, 'y': 40 + index * 80, 'width': 300, 'height': 48},
      };
    });

    expect(detectPossibleRepeatedNavSubtree(nodes), isFalse);
  });

  test('does not warn when duplicates are below threshold', () {
    final nodes = makeNodes(20, (index) {
      final String label;
      if (index < 7) {
        label = 'Unique$index';
      } else if (index < 10) {
        label = 'Shared';
      } else {
        label = 'Other$index';
      }
      return {
        'type': 'android.widget.Button',
        'label': label,
        'rect': {'x': 20, 'y': 40 + index * 80, 'width': 300, 'height': 48},
      };
    });

    expect(detectPossibleRepeatedNavSubtree(nodes), isFalse);
  });
}
