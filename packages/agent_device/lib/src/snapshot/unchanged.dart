// Port of agent-device/src/commands/snapshot-unchanged.ts
library;

import 'snapshot.dart';

/// Ensure [snapshot] has a [SnapshotState.presentationKey]. If it already
/// has one it is returned unchanged; otherwise a new [SnapshotState] with
/// the computed key is returned.
SnapshotState ensureSnapshotPresentationKey(
  SnapshotState snapshot,
  SnapshotOptions options,
) {
  if (snapshot.presentationKey != null) return snapshot;
  return SnapshotState(
    nodes: snapshot.nodes,
    createdAt: snapshot.createdAt,
    truncated: snapshot.truncated,
    backend: snapshot.backend,
    comparisonSafe: snapshot.comparisonSafe,
    presentationKey: buildSnapshotPresentationKey(options),
  );
}

/// Build [SnapshotUnchanged] metadata when consecutive snapshots are
/// content-identical, or return `null` when a full re-emit is required.
///
/// Returns null when:
/// - [options.forceFull] or [options.raw] is true
/// - there is no [previous] snapshot
/// - either snapshot has `comparisonSafe == false`
/// - the app identity changed between captures
/// - the presentation keys differ (different scope/depth/flags)
/// - the node presentations are not equivalent
SnapshotUnchanged? buildUnchangedSnapshotMetadata({
  required SnapshotState? previous,
  required SnapshotState current,
  required SnapshotOptions options,
  SnapshotIdentity? identity,
}) {
  if (options.forceFull == true || options.raw == true) return null;
  if (previous == null) return null;
  if (previous.comparisonSafe == false || current.comparisonSafe == false) {
    return null;
  }
  if (!_hasSameSnapshotIdentity(previous, current, identity)) return null;
  if (previous.presentationKey == null ||
      previous.presentationKey != current.presentationKey) {
    return null;
  }
  if (!_areSnapshotPresentationsEquivalent(previous, current)) return null;

  final scope = options.scope?.trim();
  return SnapshotUnchanged(
    ageMs: (current.createdAt - previous.createdAt).clamp(0, double.maxFinite.toInt()),
    nodeCount: current.nodes.length,
    interactiveOnly: options.interactiveOnly == true ? true : null,
    scope: (scope != null && scope.isNotEmpty) ? scope : null,
  );
}

/// Optional identity parameters that can detect an app switch between
/// the previous and current snapshot.
class SnapshotIdentity {
  final String? previousAppBundleId;
  final String? currentAppBundleId;

  const SnapshotIdentity({
    this.previousAppBundleId,
    this.currentAppBundleId,
  });
}

bool _hasSameSnapshotIdentity(
  SnapshotState previous,
  SnapshotState current,
  SnapshotIdentity? identity,
) {
  if (previous.backend != null &&
      current.backend != null &&
      previous.backend != current.backend) {
    return false;
  }
  if (identity?.previousAppBundleId != null &&
      identity?.currentAppBundleId != null &&
      identity!.previousAppBundleId != identity.currentAppBundleId) {
    return false;
  }
  return true;
}

bool _areSnapshotPresentationsEquivalent(
  SnapshotState previous,
  SnapshotState current,
) {
  if (previous.truncated != current.truncated) return false;
  // TODO: replace stringify with a field-by-field comparison or stable hash.
  final prevKey = _buildComparableKey(previous.nodes);
  final currKey = _buildComparableKey(current.nodes);
  return prevKey == currKey;
}

/// Build a comparable string key from the presentation-relevant fields of
/// each node (excludes volatile fields `ref` and `pid`).
String _buildComparableKey(List<SnapshotNode> nodes) {
  final buf = StringBuffer('[');
  for (var i = 0; i < nodes.length; i++) {
    if (i > 0) buf.write(',');
    final n = nodes[i];
    buf.write('{');
    buf.write('"index":${n.index}');
    buf.write(',"depth":${n.depth}');
    buf.write(',"parentIndex":${n.parentIndex}');
    buf.write(',"type":${_str(n.type)}');
    buf.write(',"role":${_str(n.role)}');
    buf.write(',"subrole":${_str(n.subrole)}');
    buf.write(',"label":${_str(n.label)}');
    buf.write(',"value":${_str(n.value)}');
    buf.write(',"identifier":${_str(n.identifier)}');
    buf.write(',"enabled":${n.enabled}');
    buf.write(',"selected":${n.selected}');
    // Note: upstream includes `focused` here but the Dart port's SnapshotNode
    // does not yet carry that field — omitted to stay within this commit's scope.
    buf.write(',"hittable":${n.hittable}');
    buf.write(',"rect":${_rect(n.rect)}');
    buf.write(',"bundleId":${_str(n.bundleId)}');
    buf.write(',"appName":${_str(n.appName)}');
    buf.write(',"windowTitle":${_str(n.windowTitle)}');
    buf.write(',"surface":${_str(n.surface)}');
    buf.write(',"hiddenContentAbove":${n.hiddenContentAbove}');
    buf.write(',"hiddenContentBelow":${n.hiddenContentBelow}');
    buf.write('}');
  }
  buf.write(']');
  return buf.toString();
}

String _str(String? v) => v == null ? 'null' : '"${v.replaceAll('"', '\\"')}"';

String _rect(Rect? r) {
  if (r == null) return 'null';
  return '{"x":${r.x},"y":${r.y},"width":${r.width},"height":${r.height}}';
}
