// Port of agent-device/src/commands/__tests__/snapshot-unchanged.test.ts
import 'package:agent_device/src/snapshot/snapshot.dart';
import 'package:agent_device/src/snapshot/unchanged.dart';
import 'package:test/test.dart';

SnapshotState makeSnapshot(
  String label, {
  Map<String, Object?> overrides = const {},
  SnapshotOptions options = const SnapshotOptions(),
}) {
  final baseNode = SnapshotNode(
    index: 0,
    ref: 'e1',
    depth: 0,
    type: 'Button',
    label: label,
    pid: 1234,
    hittable: true,
  );

  final nodesOverride = overrides['nodes'];
  final List<SnapshotNode> nodes;
  if (nodesOverride is List<SnapshotNode>) {
    nodes = nodesOverride;
  } else {
    nodes = [baseNode];
  }

  return ensureSnapshotPresentationKey(
    SnapshotState(
      nodes: nodes,
      createdAt: (overrides['createdAt'] as int?) ?? 1000,
      backend: overrides.containsKey('backend')
          ? (overrides['backend'] != null
              ? SnapshotBackend.fromString(overrides['backend'] as String)
              : null)
          : SnapshotBackend.xctest,
      comparisonSafe: overrides['comparisonSafe'] as bool?,
      truncated: overrides['truncated'] as bool?,
    ),
    options,
  );
}

void main() {
  group('snapshot-unchanged', () {
    test('unchanged metadata ignores refs and volatile process ids', () {
      final previous = makeSnapshot('Create');
      final current = makeSnapshot(
        'Create',
        overrides: {
          'nodes': [
            SnapshotNode(
              index: previous.nodes[0].index,
              ref: 'e99',
              depth: previous.nodes[0].depth,
              type: previous.nodes[0].type,
              label: previous.nodes[0].label,
              pid: 5678,
              hittable: previous.nodes[0].hittable,
            ),
          ],
        },
      );

      final result = buildUnchangedSnapshotMetadata(
        previous: previous,
        current: current,
        options: const SnapshotOptions(),
      );
      expect(result, isNotNull);
      expect(result!.nodeCount, equals(1));
    });

    test('unchanged metadata detects visible label changes', () {
      final result = buildUnchangedSnapshotMetadata(
        previous: makeSnapshot('Create'),
        current: makeSnapshot('Send'),
        options: const SnapshotOptions(),
      );
      expect(result, isNull);
    });

    test('unchanged metadata requires comparison-safe snapshots', () {
      expect(
        buildUnchangedSnapshotMetadata(
          previous: makeSnapshot(
            'Create',
            overrides: {'comparisonSafe': false},
          ),
          current: makeSnapshot('Create'),
          options: const SnapshotOptions(),
        ),
        isNull,
      );

      expect(
        buildUnchangedSnapshotMetadata(
          previous: makeSnapshot('Create'),
          current: makeSnapshot(
            'Create',
            overrides: {'comparisonSafe': false},
          ),
          options: const SnapshotOptions(),
        ),
        isNull,
      );
    });

    test(
      'unchanged metadata requires matching presentation key and identity',
      () {
        final previous = makeSnapshot(
          'Create',
          overrides: {'createdAt': 1000},
        );
        final current = makeSnapshot(
          'Create',
          overrides: {'createdAt': 3500},
        );

        // Different scope on current vs previous.
        expect(
          buildUnchangedSnapshotMetadata(
            previous: previous,
            current: makeSnapshot(
              'Create',
              overrides: {'createdAt': 3500},
              options: const SnapshotOptions(scope: 'Composer'),
            ),
            options: const SnapshotOptions(scope: 'Composer'),
          ),
          isNull,
        );

        // Different bundle id.
        expect(
          buildUnchangedSnapshotMetadata(
            previous: previous,
            current: current,
            options: const SnapshotOptions(),
            identity: const SnapshotIdentity(
              previousAppBundleId: 'com.example.before',
              currentAppBundleId: 'com.example.after',
            ),
          ),
          isNull,
        );

        // Same scope + same bundle id → should match.
        final result = buildUnchangedSnapshotMetadata(
          previous: makeSnapshot(
            'Create',
            overrides: {'createdAt': 1000},
            options: const SnapshotOptions(
              interactiveOnly: true,
              scope: 'Composer',
            ),
          ),
          current: makeSnapshot(
            'Create',
            overrides: {'createdAt': 3500},
            options: const SnapshotOptions(
              interactiveOnly: true,
              scope: 'Composer',
            ),
          ),
          options: const SnapshotOptions(
            interactiveOnly: true,
            scope: 'Composer',
          ),
          identity: const SnapshotIdentity(
            previousAppBundleId: 'com.example.app',
            currentAppBundleId: 'com.example.app',
          ),
        );
        expect(result, isNotNull);
        expect(result!.ageMs, equals(2500));
        expect(result.nodeCount, equals(1));
        expect(result.interactiveOnly, isTrue);
        expect(result.scope, equals('Composer'));
      },
    );

    test('unchanged metadata trims scope in compact output metadata', () {
      final result = buildUnchangedSnapshotMetadata(
        previous: makeSnapshot(
          'Create',
          overrides: {'createdAt': 1000},
          options: const SnapshotOptions(scope: ' Composer '),
        ),
        current: makeSnapshot(
          'Create',
          overrides: {'createdAt': 3500},
          options: const SnapshotOptions(scope: ' Composer '),
        ),
        options: const SnapshotOptions(scope: ' Composer '),
      );
      expect(result, isNotNull);
      expect(result!.scope, equals('Composer'));
    });

    test('force-full and raw snapshots do not emit unchanged metadata', () {
      final previous = makeSnapshot('Create');
      final current = makeSnapshot('Create');

      expect(
        buildUnchangedSnapshotMetadata(
          previous: previous,
          current: current,
          options: const SnapshotOptions(forceFull: true),
        ),
        isNull,
      );
      expect(
        buildUnchangedSnapshotMetadata(
          previous: previous,
          current: current,
          options: const SnapshotOptions(raw: true),
        ),
        isNull,
      );
    });
  });
}
