// Port of agent-device/src/utils/snapshot-occlusion.ts
library;

import '../snapshot/presentation_tree.dart' show areRectsApproximatelyEqual;
import '../snapshot/processing.dart' show normalizeType;
import '../snapshot/snapshot.dart';

// ---------------------------------------------------------------------------
// Constants
// ---------------------------------------------------------------------------

const _coveredPresentationHint = 'covered';

/// Node type fragments that represent known floating UI chrome that can
/// visually occlude elements beneath them in presentation order.
const _overlayKindFragments = [
  'tabbar',
  'toolbar',
  'navigationbar',
  'bottomnavigation',
  'bottomnavigationview',
  'sheet',
  'dialog',
  'alert',
  'popover',
  'menu',
];

/// Node type fragments that represent semantic interactive elements — i.e.
/// elements that are candidates to be the actual touch target.
const _semanticTouchKindFragments = [
  'button',
  'link',
  'menuitem',
  'tabitem',
  'textfield',
  'searchfield',
  'edittext',
  'checkbox',
  'radio',
  'switch',
  'cell',
];

// ---------------------------------------------------------------------------
// Public API
// ---------------------------------------------------------------------------

/// Walk [nodes] in presentation order and annotate any node whose center
/// point is covered by a later overlay-like sibling.
///
/// Annotated nodes get:
/// - `hittable = false`
/// - `interactionBlocked = 'covered'`
/// - `'covered'` appended to `presentationHints`
///
/// Returns the same list reference when no nodes were annotated; otherwise
/// returns a new list with the annotated copies substituted in.
List<RawSnapshotNode> annotateCoveredSnapshotNodes(
  List<RawSnapshotNode> nodes,
) {
  if (nodes.length < 2) return nodes;

  final annotated = [...nodes];
  final byIndex = <int, RawSnapshotNode>{
    for (final node in annotated) node.index: node,
  };
  // Memo of "is the node at list position covered by a later overlay?".
  // Annotating a node only flips hittable/interactionBlocked/hints — never the
  // rect/type the covering geometry reads — so coverage is stable across the
  // pass and safe to cache. Collapses the otherwise-O(n^3) nested search
  // (each candidate re-checks whether its cover is itself covered) to ~O(n^2).
  final coveredMemo = <int, bool>{};

  var changed = false;
  for (var position = 0; position < annotated.length; position++) {
    final node = annotated[position];
    if (!_isCandidateTouchNode(node)) continue;
    if (!_isNodeCovered(annotated, byIndex, position, coveredMemo)) continue;

    changed = true;
    final coveredNode = _cloneAsCovered(node);
    annotated[position] = coveredNode;
    byIndex[coveredNode.index] = coveredNode;
  }

  return changed ? annotated : nodes;
}

/// Returns `true` when [node.interactionBlocked] is set (i.e. the node is
/// blocked for any reason — currently only `'covered'` is used).
bool isSnapshotNodeInteractionBlocked(
  RawSnapshotNode node,
) {
  return node.interactionBlocked != null;
}

// ---------------------------------------------------------------------------
// Covering-node search
// ---------------------------------------------------------------------------

/// Whether the node at [targetPosition] has its center covered by a later
/// overlay-like sibling. Memoized in [coveredMemo] (keyed by list position).
bool _isNodeCovered(
  List<RawSnapshotNode> nodes,
  Map<int, RawSnapshotNode> byIndex,
  int targetPosition,
  Map<int, bool> coveredMemo,
) {
  final cached = coveredMemo[targetPosition];
  if (cached != null) return cached;
  final result = _computeNodeCovered(nodes, byIndex, targetPosition, coveredMemo);
  coveredMemo[targetPosition] = result;
  return result;
}

bool _computeNodeCovered(
  List<RawSnapshotNode> nodes,
  Map<int, RawSnapshotNode> byIndex,
  int targetPosition,
  Map<int, bool> coveredMemo,
) {
  final target = nodes[targetPosition];
  final targetRect = _positiveRect(target.rect);
  if (targetRect == null) return false;
  final center = centerOfRect(targetRect);

  for (
    var position = targetPosition + 1;
    position < nodes.length;
    position++
  ) {
    if (_canCoverPoint(
      nodes,
      byIndex,
      position,
      target,
      targetRect,
      center,
      coveredMemo,
    )) {
      return true;
    }
  }
  return false;
}

bool _canCoverPoint(
  List<RawSnapshotNode> nodes,
  Map<int, RawSnapshotNode> byIndex,
  int candidatePosition,
  RawSnapshotNode target,
  Rect targetRect,
  Point center,
  Map<int, bool> coveredMemo,
) {
  final coverRect = _visibleCoverRect(
    nodes,
    byIndex,
    candidatePosition,
    target,
    targetRect,
    coveredMemo,
  );
  return coverRect != null && _containsPoint(coverRect, center.x, center.y);
}

Rect? _visibleCoverRect(
  List<RawSnapshotNode> nodes,
  Map<int, RawSnapshotNode> byIndex,
  int candidatePosition,
  RawSnapshotNode target,
  Rect targetRect,
  Map<int, bool> coveredMemo,
) {
  final candidate = nodes[candidatePosition];
  if (!_isOverlayLikeNode(candidate)) return null;
  if (_areRelatedSnapshotNodes(target, candidate, byIndex)) return null;
  final candidateRect = _positiveRect(candidate.rect);
  if (candidateRect == null) return null;
  if (areRectsApproximatelyEqual(targetRect, candidateRect)) return null;
  // The candidate itself must not be covered by something above it.
  if (_isNodeCovered(nodes, byIndex, candidatePosition, coveredMemo)) {
    return null;
  }
  return candidateRect;
}

// ---------------------------------------------------------------------------
// Node classification
// ---------------------------------------------------------------------------

bool _isCandidateTouchNode(RawSnapshotNode node) {
  if (_positiveRect(node.rect) == null) return false;
  if (node.hittable == true) return true;
  if (_isSemanticTouchNode(node)) return true;
  return (node.label?.trim().isNotEmpty == true) ||
      (node.value?.trim().isNotEmpty == true) ||
      (node.identifier?.trim().isNotEmpty == true);
}

bool _isOverlayLikeNode(RawSnapshotNode node) {
  if (_positiveRect(node.rect) == null) return false;
  if (_isViewportRoot(node)) return false;
  // Only known floating UI chrome should cover later targets.
  return _nodeKindIncludesAny(node, _overlayKindFragments);
}

bool _isSemanticTouchNode(RawSnapshotNode node) {
  return _nodeKindIncludesAny(node, _semanticTouchKindFragments);
}

bool _nodeKindIncludesAny(
  RawSnapshotNode node,
  List<String> fragments,
) {
  final normalized = _normalizeNodeKind(node);
  return fragments.any((fragment) => normalized.contains(fragment));
}

String _normalizeNodeKind(RawSnapshotNode node) {
  return [node.type, node.role, node.subrole]
      .map((v) => normalizeType(v ?? ''))
      .join(' ');
}

bool _isViewportRoot(RawSnapshotNode node) {
  final normalized = _normalizeNodeKind(node);
  return normalized.contains('application') || normalized.contains('window');
}

// ---------------------------------------------------------------------------
// Ancestry checks
// ---------------------------------------------------------------------------

bool _areRelatedSnapshotNodes(
  RawSnapshotNode left,
  RawSnapshotNode right,
  Map<int, RawSnapshotNode> byIndex,
) {
  return _isSnapshotAncestor(left, right, byIndex) ||
      _isSnapshotAncestor(right, left, byIndex);
}

bool _isSnapshotAncestor(
  RawSnapshotNode ancestor,
  RawSnapshotNode node,
  Map<int, RawSnapshotNode> byIndex,
) {
  var parentIndex = node.parentIndex;
  final visited = <int>{};
  while (parentIndex != null) {
    if (visited.contains(parentIndex)) break;
    visited.add(parentIndex);
    final current = byIndex[parentIndex];
    if (current == null) break;
    if (current.index == ancestor.index) return true;
    parentIndex = current.parentIndex;
  }
  return false;
}

// ---------------------------------------------------------------------------
// Rect helpers
// ---------------------------------------------------------------------------

/// Returns the rect only if it has positive width and height after
/// normalization; otherwise null.
Rect? _positiveRect(Rect? rect) {
  if (rect == null) return null;
  if (!rect.x.isFinite ||
      !rect.y.isFinite ||
      !rect.width.isFinite ||
      !rect.height.isFinite) {
    return null;
  }
  if (rect.width <= 0 || rect.height <= 0) return null;
  return rect;
}

bool _containsPoint(Rect rect, double x, double y) {
  return x >= rect.x &&
      x <= rect.x + rect.width &&
      y >= rect.y &&
      y <= rect.y + rect.height;
}

// ---------------------------------------------------------------------------
// Annotation helper
// ---------------------------------------------------------------------------

RawSnapshotNode _cloneAsCovered(RawSnapshotNode node) {
  final hints = <String>{...?node.presentationHints, _coveredPresentationHint};
  return RawSnapshotNode(
    index: node.index,
    type: node.type,
    role: node.role,
    subrole: node.subrole,
    label: node.label,
    value: node.value,
    identifier: node.identifier,
    rect: node.rect,
    enabled: node.enabled,
    selected: node.selected,
    hittable: false,
    depth: node.depth,
    parentIndex: node.parentIndex,
    pid: node.pid,
    bundleId: node.bundleId,
    appName: node.appName,
    windowTitle: node.windowTitle,
    surface: node.surface,
    hiddenContentAbove: node.hiddenContentAbove,
    hiddenContentBelow: node.hiddenContentBelow,
    interactionBlocked: _coveredPresentationHint,
    presentationHints: hints.toList(),
  );
}
