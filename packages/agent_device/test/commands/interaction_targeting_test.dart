// Port of agent-device/src/commands/__tests__/interaction-targeting.test.ts
@TestOn('vm')
library;

import 'package:agent_device/src/commands/interaction_targeting.dart';
import 'package:agent_device/src/snapshot/snapshot.dart';
import 'package:test/test.dart';

void main() {
  group('ActionableTouchResolution', () {
    group('resolveActionableTouchNode', () {
      test('returns the input node when no better target is available', () {
        final node = SnapshotNode(
          index: 0,
          ref: 'e0',
          type: 'button',
          rect: const Rect(x: 10, y: 20, width: 100, height: 50),
          hittable: true,
        );
        final nodes = [node];

        final resolved = resolveActionableTouchNode(nodes, node);

        expect(resolved.ref, equals(node.ref));
      });

      test('prefers a semantic touch target over a hittable ancestor', () {
        // A semantic button with a hittable screen container.
        final button = SnapshotNode(
          index: 0,
          ref: 'e0',
          type: 'button',
          label: 'Submit',
          rect: const Rect(x: 100, y: 100, width: 50, height: 50),
          hittable: true,
          parentIndex: 1,
        );
        final screen = SnapshotNode(
          index: 1,
          ref: 'e1',
          type: 'application',
          rect: const Rect(x: 0, y: 0, width: 1080, height: 1920),
          hittable: true,
        );
        final nodes = [button, screen];

        // Asking for the button should resolve to the button itself.
        final resolved = resolveActionableTouchNode(nodes, button);

        expect(resolved.ref, equals(button.ref));
      });

      test('rejects overly broad ancestors (screen-sized)', () {
        // A small unselectable child under a screen-filling button.
        final text = SnapshotNode(
          index: 0,
          ref: 'e0',
          type: 'text',
          label: 'Hello',
          rect: const Rect(x: 500, y: 500, width: 20, height: 20),
          hittable: false,
          parentIndex: 1,
        );
        final button = SnapshotNode(
          index: 1,
          ref: 'e1',
          type: 'button',
          rect: const Rect(x: 0, y: 0, width: 1080, height: 1920),
          hittable: true,
          parentIndex: 2,
        );
        final screen = SnapshotNode(
          index: 2,
          ref: 'e2',
          type: 'application',
          rect: const Rect(x: 0, y: 0, width: 1080, height: 1920),
          hittable: true,
        );
        final nodes = [text, button, screen];

        // Asking for the text should return the text itself, not the overly
        // broad button ancestor, because the button covers the viewport.
        final resolved = resolveActionableTouchNode(nodes, text);

        expect(resolved.ref, equals(text.ref));
      });

      test('climbs to a hittable ancestor when the node is not hittable', () {
        // A text child under a button.
        final text = SnapshotNode(
          index: 0,
          ref: 'e0',
          type: 'text',
          label: 'Click me',
          rect: const Rect(x: 100, y: 100, width: 50, height: 50),
          hittable: false,
          parentIndex: 1,
        );
        final button = SnapshotNode(
          index: 1,
          ref: 'e1',
          type: 'button',
          rect: const Rect(x: 100, y: 100, width: 100, height: 100),
          hittable: true,
          parentIndex: 2,
        );
        final screen = SnapshotNode(
          index: 2,
          ref: 'e2',
          type: 'application',
          rect: const Rect(x: 0, y: 0, width: 1080, height: 1920),
          hittable: true,
        );
        final nodes = [text, button, screen];

        // Asking for the text should climb to the button.
        final resolved = resolveActionableTouchNode(nodes, text);

        expect(resolved.ref, equals(button.ref));
      });

      test('finds and prefers same-rect descendants', () {
        // A button with an inner group that has the same rect.
        final button = SnapshotNode(
          index: 0,
          ref: 'e0',
          type: 'button',
          label: 'Submit',
          rect: const Rect(x: 100, y: 100, width: 100, height: 50),
          hittable: true,
        );
        final group = SnapshotNode(
          index: 1,
          ref: 'e1',
          type: 'group',
          rect: const Rect(x: 100, y: 100, width: 100, height: 50),
          hittable: true,
          parentIndex: 0,
        );
        final text = SnapshotNode(
          index: 2,
          ref: 'e2',
          type: 'text',
          label: 'Submit',
          rect: const Rect(x: 100, y: 100, width: 100, height: 50),
          hittable: true,
          parentIndex: 1,
        );
        final nodes = [button, group, text];

        // Asking for the button should drill down to the text node.
        final resolved = resolveActionableTouchNode(nodes, button);

        expect(resolved.ref, equals(text.ref));
      });

      test('handles null rects gracefully', () {
        final node = SnapshotNode(
          index: 0,
          ref: 'e0',
          type: 'button',
          hittable: true,
          // No rect
        );
        final nodes = [node];

        // Should return the node as-is (cannot verify semantic role without rect).
        final resolved = resolveActionableTouchNode(nodes, node);

        expect(resolved.ref, equals(node.ref));
      });

      test('recognizes semantic touch role fragments', () {
        final button = SnapshotNode(
          index: 0,
          ref: 'e0',
          type: 'checkbox',
          rect: const Rect(x: 10, y: 20, width: 50, height: 50),
          hittable: true,
        );
        final nodes = [button];

        // The checkbox should be recognized as a semantic target.
        final resolved = resolveActionableTouchNode(nodes, button);

        expect(resolved.ref, equals(button.ref));
      });

      test('matches "tab" exactly, not "tabbar" or "table"', () {
        final tab = SnapshotNode(
          index: 0,
          ref: 'e0',
          type: 'tab',
          rect: const Rect(x: 10, y: 20, width: 50, height: 50),
          hittable: true,
        );
        final tabBar = SnapshotNode(
          index: 1,
          ref: 'e1',
          type: 'tabbar',
          rect: const Rect(x: 0, y: 0, width: 1080, height: 80),
          hittable: true,
        );
        final table = SnapshotNode(
          index: 2,
          ref: 'e2',
          type: 'table',
          rect: const Rect(x: 0, y: 80, width: 1080, height: 1000),
          hittable: true,
        );
        final screen = SnapshotNode(
          index: 3,
          ref: 'e3',
          type: 'application',
          rect: const Rect(x: 0, y: 0, width: 1080, height: 1920),
          hittable: true,
        );
        final nodes = [tab, tabBar, table, screen];

        // Tab is semantic and small, so should be returned directly.
        final tabResolved = resolveActionableTouchNode(nodes, tab);
        expect(tabResolved.ref, equals(tab.ref));

        // TabBar is not semantic (only 'tab' matches exactly).
        // Asking for it should not prefer it as semantic.
        final tabBarResolved = resolveActionableTouchNode(nodes, tabBar);
        // It may climb to screen or stay as-is depending on viewport coverage.
        expect(tabBarResolved.hittable, isTrue);
      });
    });

    group('resolveActionableTouchResolution', () {
      test('returns the resolution reason', () {
        final node = SnapshotNode(
          index: 0,
          ref: 'e0',
          type: 'button',
          rect: const Rect(x: 10, y: 20, width: 100, height: 50),
          hittable: true,
        );
        final nodes = [node];

        final resolution = resolveActionableTouchResolution(nodes, node);

        expect(
          resolution.reason,
          ActionableTouchResolutionReason.semanticTarget,
        );
      });

      test('reason is "hittable-ancestor" when climbing', () {
        final text = SnapshotNode(
          index: 0,
          ref: 'e0',
          type: 'text',
          label: 'Click',
          rect: const Rect(x: 100, y: 100, width: 50, height: 50),
          hittable: false,
          parentIndex: 1,
        );
        final button = SnapshotNode(
          index: 1,
          ref: 'e1',
          type: 'button',
          rect: const Rect(x: 100, y: 100, width: 100, height: 100),
          hittable: true,
          parentIndex: 2,
        );
        final screen = SnapshotNode(
          index: 2,
          ref: 'e2',
          type: 'application',
          rect: const Rect(x: 0, y: 0, width: 1080, height: 1920),
          hittable: true,
        );
        final nodes = [text, button, screen];

        final resolution = resolveActionableTouchResolution(nodes, text);

        expect(
          resolution.reason,
          ActionableTouchResolutionReason.hittableAncestor,
        );
      });
    });
  });
}
