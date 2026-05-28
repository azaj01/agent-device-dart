// Tests for the iOS interactive snapshot presentation pipeline.
// Port of agent-device/src/daemon/snapshot-presentation/ios/presentation.test.ts
@TestOn('vm')
library;

import 'package:agent_device/src/snapshot/ios_presentation.dart';
import 'package:agent_device/src/snapshot/snapshot.dart';
import 'package:test/test.dart';

void main() {
  // ---------------------------------------------------------------------------
  // Helpers
  // ---------------------------------------------------------------------------

  const rowRect = Rect(x: 16, y: 293, width: 370, height: 52);

  RawSnapshotNode makeNode({
    required int index,
    required int depth,
    int? parentIndex,
    String? type,
    String? label,
    String? value,
    String? identifier,
    Rect? rect,
    bool? enabled,
    bool? hittable,
  }) =>
      RawSnapshotNode(
        index: index,
        depth: depth,
        parentIndex: parentIndex,
        type: type,
        label: label,
        value: value,
        identifier: identifier,
        rect: rect,
        enabled: enabled,
        hittable: hittable,
      );

  List<(String?, String?, String?)> signatures(List<RawSnapshotNode> nodes) =>
      nodes.map((n) => (n.type, n.label, n.identifier)).toList();

  // ---------------------------------------------------------------------------
  // Row collapsing
  // ---------------------------------------------------------------------------

  test('collapses iOS interactive row backing nodes', () {
    final nodes = [
      makeNode(index: 0, depth: 0, type: 'Application', label: 'Settings'),
      makeNode(index: 1, depth: 1, parentIndex: 0, type: 'CollectionView'),
      makeNode(
        index: 2,
        depth: 2,
        parentIndex: 1,
        type: 'Cell',
        label: 'General',
        rect: rowRect,
      ),
      makeNode(
        index: 3,
        depth: 3,
        parentIndex: 2,
        type: 'Other',
        label: 'General',
        rect: rowRect,
      ),
      makeNode(
        index: 4,
        depth: 4,
        parentIndex: 3,
        type: 'Button',
        label: 'General',
        identifier: 'com.apple.settings.general',
        rect: rowRect,
      ),
      makeNode(
        index: 5,
        depth: 5,
        parentIndex: 4,
        type: 'StaticText',
        label: 'General',
        rect: rowRect,
      ),
      makeNode(
        index: 6,
        depth: 5,
        parentIndex: 4,
        type: 'Image',
        identifier: 'chevron.forward',
        rect: Rect(x: 360, y: 313, width: 7, height: 12),
      ),
    ];

    final result = presentIosInteractiveSnapshot(nodes);

    expect(signatures(result), [
      ('Application', 'Settings', null),
      ('CollectionView', null, null),
      ('Cell', 'General', 'com.apple.settings.general'),
    ]);
  });

  test('promotes iOS switch rows to the switch control', () {
    const switchRect = Rect(x: 320, y: 302, width: 51, height: 31);
    final nodes = [
      makeNode(index: 0, depth: 0, type: 'Application', label: 'Settings'),
      makeNode(index: 1, depth: 1, parentIndex: 0, type: 'CollectionView'),
      makeNode(
        index: 2,
        depth: 2,
        parentIndex: 1,
        type: 'Cell',
        label: 'Airplane Mode',
        rect: rowRect,
      ),
      makeNode(
        index: 3,
        depth: 3,
        parentIndex: 2,
        type: 'Button',
        label: 'Airplane Mode',
        identifier: 'com.apple.settings.airplane-mode',
        rect: rowRect,
      ),
      makeNode(
        index: 4,
        depth: 4,
        parentIndex: 3,
        type: 'Switch',
        label: 'Airplane Mode',
        value: '0',
        rect: switchRect,
      ),
      makeNode(
        index: 5,
        depth: 5,
        parentIndex: 4,
        type: 'Switch',
        label: '0',
        value: '0',
        rect: switchRect,
      ),
    ];

    final result = presentIosInteractiveSnapshot(nodes);

    expect(signatures(result), [
      ('Application', 'Settings', null),
      ('CollectionView', null, null),
      ('Switch', 'Airplane Mode', 'com.apple.settings.airplane-mode'),
    ]);
    expect(result[2].parentIndex, equals(1));
  });

  test('ignores unlabeled accessory buttons when collapsing iOS rows', () {
    final nodes = [
      makeNode(index: 0, depth: 0, type: 'Application', label: 'Settings'),
      makeNode(index: 1, depth: 1, parentIndex: 0, type: 'CollectionView'),
      makeNode(
        index: 2,
        depth: 2,
        parentIndex: 1,
        type: 'Cell',
        label: 'General',
        rect: rowRect,
      ),
      makeNode(
        index: 3,
        depth: 3,
        parentIndex: 2,
        type: 'Button',
        identifier: 'accessory-button',
        rect: rowRect,
      ),
      makeNode(
        index: 4,
        depth: 3,
        parentIndex: 2,
        type: 'Button',
        label: 'General',
        identifier: 'com.apple.settings.general',
        rect: rowRect,
      ),
      makeNode(
        index: 5,
        depth: 4,
        parentIndex: 4,
        type: 'StaticText',
        label: 'General',
        rect: rowRect,
      ),
    ];

    final result = presentIosInteractiveSnapshot(nodes);

    expect(signatures(result), [
      ('Application', 'Settings', null),
      ('CollectionView', null, null),
      ('Cell', 'General', 'com.apple.settings.general'),
    ]);
  });

  test('collapses rows with text-area buttons and disabled chevrons', () {
    const rowRect2 = Rect(x: 20, y: 391, width: 362, height: 53);
    final nodes = [
      makeNode(index: 0, depth: 0, type: 'Application', label: 'Settings'),
      makeNode(index: 1, depth: 1, parentIndex: 0, type: 'Table', label: 'General'),
      makeNode(
        index: 2,
        depth: 2,
        parentIndex: 1,
        type: 'Cell',
        label: 'About',
        identifier: 'About',
        rect: rowRect2,
      ),
      makeNode(
        index: 3,
        depth: 3,
        parentIndex: 2,
        type: 'Other',
        label: 'About',
        rect: Rect(x: 20, y: 391, width: 331, height: 53),
      ),
      makeNode(
        index: 4,
        depth: 4,
        parentIndex: 3,
        type: 'Button',
        label: 'About',
        identifier: 'About',
        rect: Rect(x: 34, y: 404, width: 88, height: 28),
      ),
      makeNode(
        index: 5,
        depth: 3,
        parentIndex: 2,
        type: 'Button',
        label: 'chevron',
        enabled: false,
        rect: Rect(x: 351, y: 410, width: 10, height: 14),
      ),
    ];

    final result = presentIosInteractiveSnapshot(nodes);

    expect(signatures(result), [
      ('Application', 'Settings', null),
      ('Table', 'General', null),
      ('Cell', 'About', 'About'),
    ]);
  });

  // ---------------------------------------------------------------------------
  // Noise suppression
  // ---------------------------------------------------------------------------

  test('suppresses structural identifier-only nodes', () {
    final nodes = [
      makeNode(index: 0, depth: 0, type: 'Application', label: 'MyApp'),
      makeNode(
        index: 1,
        depth: 1,
        parentIndex: 0,
        type: 'Other',
        identifier: 'SomeInternalId',
        // no label, no value, not hittable
      ),
      makeNode(
        index: 2,
        depth: 2,
        parentIndex: 1,
        type: 'Button',
        label: 'OK',
        rect: rowRect,
      ),
    ];

    final result = presentIosInteractiveSnapshot(nodes);
    final types = result.map((n) => n.type).toList();

    expect(types, isNot(contains('Other')));
    expect(result.any((n) => n.label == 'OK'), isTrue);
  });

  test('does not suppress hittable other nodes', () {
    final nodes = [
      makeNode(index: 0, depth: 0, type: 'Application', label: 'MyApp'),
      makeNode(
        index: 1,
        depth: 1,
        parentIndex: 0,
        type: 'Other',
        identifier: 'SomeInternalId',
        hittable: true,
      ),
    ];

    final result = presentIosInteractiveSnapshot(nodes);
    expect(result.any((n) => n.type == 'Other'), isTrue);
  });

  // ---------------------------------------------------------------------------
  // Empty / identity cases
  // ---------------------------------------------------------------------------

  test('returns empty list unchanged', () {
    final result = presentIosInteractiveSnapshot([]);
    expect(result, isEmpty);
  });

  test('returns original list when no rules fire', () {
    final nodes = [makeNode(index: 0, depth: 0, type: 'Application', label: 'Root')];
    final result = presentIosInteractiveSnapshot(nodes);
    expect(result, same(nodes));
  });

  // ---------------------------------------------------------------------------
  // Implicit scrollable action annotation
  // ---------------------------------------------------------------------------

  test('annotates implicit scrollable actions as Cell', () {
    final nodes = [
      makeNode(
        index: 0,
        depth: 0,
        type: 'Application',
        label: 'App',
        rect: Rect(x: 0, y: 0, width: 390, height: 844),
      ),
      makeNode(
        index: 1,
        depth: 1,
        parentIndex: 0,
        type: 'ScrollView',
        rect: Rect(x: 0, y: 0, width: 390, height: 600),
      ),
      makeNode(
        index: 2,
        depth: 2,
        parentIndex: 1,
        type: 'Other',
        label: 'Product details',
        rect: Rect(x: 0, y: 100, width: 390, height: 60),
      ),
    ];

    final result = presentIosInteractiveSnapshot(nodes);
    final actionNode = result.firstWhere(
      (n) => n.label == 'Product details',
      orElse: () => throw StateError('node not found'),
    );
    expect(actionNode.type, equals('Cell'));
  });
}
