// Port of agent-device/src/daemon/snapshot-presentation/tree.ts
library;

import '../snapshot/processing.dart' show normalizeType;
import '../snapshot/snapshot.dart';

// ---------------------------------------------------------------------------
// Rule context
// ---------------------------------------------------------------------------

/// Mutable context passed to each presentation rule.
class SnapshotTreeRuleContext {
  final Map<int, RawSnapshotNode> replacements;
  final Set<int> suppressedIndexes;

  SnapshotTreeRuleContext({
    required this.replacements,
    required this.suppressedIndexes,
  });
}

// ---------------------------------------------------------------------------
// Descendant / ancestor traversal
// ---------------------------------------------------------------------------

/// Collect all descendants of the node at [startPosition] by iterating
/// forward until depth decreases back to or below the start node's depth.
List<RawSnapshotNode> collectDescendants(
  List<RawSnapshotNode> nodes,
  int startPosition,
) {
  final startDepth = nodes[startPosition].depth ?? 0;
  final descendants = <RawSnapshotNode>[];
  for (var i = startPosition + 1; i < nodes.length; i++) {
    final node = nodes[i];
    if ((node.depth ?? 0) <= startDepth) break;
    descendants.add(node);
  }
  return descendants;
}

List<RawSnapshotNode> _collectAncestors(
  RawSnapshotNode node,
  Map<int, RawSnapshotNode> byIndex,
) {
  final ancestors = <RawSnapshotNode>[];
  final visited = <int>{};
  var parentIndex = node.parentIndex;
  while (parentIndex != null) {
    if (visited.contains(parentIndex)) break;
    visited.add(parentIndex);
    final parent = byIndex[parentIndex];
    if (parent == null) break;
    ancestors.add(parent);
    parentIndex = parent.parentIndex;
  }
  return ancestors;
}

/// Find the nearest ancestor satisfying [predicate], or null.
RawSnapshotNode? findNearestAncestor(
  RawSnapshotNode node,
  Map<int, RawSnapshotNode> byIndex,
  bool Function(RawSnapshotNode) predicate,
) {
  for (final ancestor in _collectAncestors(node, byIndex)) {
    if (predicate(ancestor)) return ancestor;
  }
  return null;
}

/// Find the nearest ancestor (or self when [includeSelf] is true) that is a
/// scrollable container type.
RawSnapshotNode? findNearestScrollableContainer(
  RawSnapshotNode node,
  Map<int, RawSnapshotNode> byIndex, {
  bool includeSelf = false,
}) {
  if (includeSelf && isScrollableSnapshotType(node.type)) return node;
  return findNearestAncestor(
    node,
    byIndex,
    (ancestor) => isScrollableSnapshotType(ancestor.type),
  );
}

// ---------------------------------------------------------------------------
// Replacement helpers
// ---------------------------------------------------------------------------

/// Merge a partial patch into the replacement map for [node.index].
///
/// Later calls win on a per-field basis: patch wins over any existing
/// replacement entry, which itself wins over the original node fields.
void mergeReplacement(
  Map<int, RawSnapshotNode> replacements,
  RawSnapshotNode node, {
  String? type,
  String? identifier,
  Rect? rect,
  bool? hiddenContentAbove,
  bool? hiddenContentBelow,
}) {
  final existing = replacements[node.index] ?? node;
  replacements[node.index] = RawSnapshotNode(
    index: existing.index,
    type: type ?? existing.type,
    role: existing.role,
    subrole: existing.subrole,
    label: existing.label,
    value: existing.value,
    identifier: identifier ?? existing.identifier,
    rect: rect ?? existing.rect,
    enabled: existing.enabled,
    selected: existing.selected,
    hittable: existing.hittable,
    depth: existing.depth,
    parentIndex: existing.parentIndex,
    pid: existing.pid,
    bundleId: existing.bundleId,
    appName: existing.appName,
    windowTitle: existing.windowTitle,
    surface: existing.surface,
    hiddenContentAbove: hiddenContentAbove ?? existing.hiddenContentAbove,
    hiddenContentBelow: hiddenContentBelow ?? existing.hiddenContentBelow,
    presentationHints: existing.presentationHints,
  );
}

// ---------------------------------------------------------------------------
// Node classification helpers
// ---------------------------------------------------------------------------

/// Returns true when [type] represents an iOS/macOS scrollable container.
bool isScrollableSnapshotType(String? type) {
  final normalized = normalizeType(type ?? '');
  return normalized == 'collectionview' ||
      normalized == 'table' ||
      normalized == 'scrollview' ||
      normalized == 'scrollarea';
}

/// Returns true when the node is a semantic action element (button, link,
/// switch, searchfield, or textfield).
bool isSemanticActionNode(RawSnapshotNode node) {
  final type = normalizeType(node.type ?? '');
  return type == 'button' ||
      type == 'link' ||
      type == 'switch' ||
      type == 'searchfield' ||
      type == 'textfield';
}

/// Returns true when the node is a disabled chevron-style navigation button
/// (e.g., a back-button indicator with no semantic meaning of its own).
bool isDisabledChevronButton(RawSnapshotNode node) {
  return normalizeType(node.type ?? '') == 'button' &&
      node.label?.trim() == 'chevron' &&
      node.enabled == false;
}

/// Returns true when [node] is a repeated static text/link descendant whose
/// label merely echoes [parentLabel].
bool isRepeatedStaticNode(RawSnapshotNode node, String parentLabel) {
  final label = node.label?.trim();
  if (label == null || label.isEmpty || label != parentLabel) return false;
  final type = normalizeType(node.type ?? '');
  return type == 'other' || type == 'statictext' || type == 'link';
}

/// Returns true if [node] should be suppressed because it is a repeated
/// text descendant that is semantically redundant.
bool shouldSuppressRepeatedTextDescendant(
  RawSnapshotNode node,
  String parentLabel,
) {
  final type = normalizeType(node.type ?? '');
  final label = node.label?.trim();
  if (isDisabledChevronButton(node)) return true;
  if (type == 'other' && (label == null || label.isEmpty) && node.value == null) {
    return true;
  }
  if ((type == 'other' || type == 'statictext') &&
      label != null &&
      label.isNotEmpty &&
      parentLabel.contains(label)) {
    return true;
  }
  if (type == 'image') return true;
  return false;
}

// ---------------------------------------------------------------------------
// Viewport helpers
// ---------------------------------------------------------------------------

/// Find the largest `application` or `window` rect in [nodes].
Rect? findLargestViewportRect(Iterable<RawSnapshotNode> nodes) {
  Rect? viewport;
  for (final node in nodes) {
    final type = normalizeType(node.type ?? '');
    if ((type == 'application' || type == 'window') &&
        _isLargerRect(node.rect, viewport)) {
      viewport = node.rect;
    }
  }
  return viewport;
}

/// Returns true when [rect]'s area is ≥ [minRatio] (default 0.8) of
/// [viewport]'s area.
bool isMostlyViewportSizedRect(
  Rect? rect,
  Rect? viewport, {
  double minRatio = 0.8,
}) {
  final rectArea = _rectArea(rect);
  final viewportArea = _rectArea(viewport);
  return rectArea > 0 && viewportArea > 0 && rectArea / viewportArea >= minRatio;
}

bool _isLargerRect(Rect? candidate, Rect? current) {
  if (candidate == null) return false;
  if (current == null) return true;
  return _rectArea(candidate) > _rectArea(current);
}

double _rectArea(Rect? rect) =>
    rect != null ? rect.width * rect.height : 0.0;

/// Returns true when the two rects are approximately equal (within 0.5 units).
bool areRectsApproximatelyEqual(Rect? left, Rect? right) {
  if (left == null || right == null) return false;
  const tolerance = 0.5;
  return (left.x - right.x).abs() <= tolerance &&
      (left.y - right.y).abs() <= tolerance &&
      (left.width - right.width).abs() <= tolerance &&
      (left.height - right.height).abs() <= tolerance;
}

// ---------------------------------------------------------------------------
// Re-indexing after suppression
// ---------------------------------------------------------------------------

/// Rebuild [nodes]' `index` and `parentIndex` fields after some nodes have
/// been removed from [originalNodes] (those listed in [suppressedIndexes]).
///
/// For any node whose original parent was suppressed, walks up the original
/// tree to find the nearest kept ancestor.
List<RawSnapshotNode> reindexSnapshotNodesWithSuppressedParents(
  List<RawSnapshotNode> nodes,
  Set<int> suppressedIndexes,
  List<RawSnapshotNode> originalNodes,
) {
  final originalByIndex = <int, RawSnapshotNode>{
    for (final n in originalNodes) n.index: n,
  };

  // New sequential index for each kept node.
  final indexMap = <int, int>{
    for (var i = 0; i < nodes.length; i++) nodes[i].index: i,
  };

  return [
    for (var i = 0; i < nodes.length; i++)
      _reindexNode(nodes[i], i, indexMap, suppressedIndexes, originalByIndex),
  ];
}

RawSnapshotNode _reindexNode(
  RawSnapshotNode node,
  int newIndex,
  Map<int, int> indexMap,
  Set<int> suppressedIndexes,
  Map<int, RawSnapshotNode> originalByIndex,
) {
  final oldParent = node.parentIndex;
  int? newParentIndex;
  if (oldParent != null) {
    newParentIndex = indexMap[oldParent] ??
        // Original parent was suppressed — walk up to find nearest kept ancestor.
        _findNearestKeptAncestorIndex(
          oldParent,
          suppressedIndexes,
          originalByIndex,
          indexMap,
        );
  }

  return RawSnapshotNode(
    index: newIndex,
    type: node.type,
    role: node.role,
    subrole: node.subrole,
    label: node.label,
    value: node.value,
    identifier: node.identifier,
    rect: node.rect,
    enabled: node.enabled,
    selected: node.selected,
    hittable: node.hittable,
    depth: node.depth,
    parentIndex: newParentIndex,
    pid: node.pid,
    bundleId: node.bundleId,
    appName: node.appName,
    windowTitle: node.windowTitle,
    surface: node.surface,
    hiddenContentAbove: node.hiddenContentAbove,
    hiddenContentBelow: node.hiddenContentBelow,
    presentationHints: node.presentationHints,
  );
}

int? _findNearestKeptAncestorIndex(
  int parentIndex,
  Set<int> suppressedIndexes,
  Map<int, RawSnapshotNode> originalByIndex,
  Map<int, int> indexMap,
) {
  var currentIndex = parentIndex;
  final visited = <int>{};
  while (!visited.contains(currentIndex)) {
    visited.add(currentIndex);
    if (!suppressedIndexes.contains(currentIndex)) {
      return indexMap[currentIndex];
    }
    final current = originalByIndex[currentIndex];
    if (current?.parentIndex == null) break;
    currentIndex = current!.parentIndex!;
  }
  return null;
}
