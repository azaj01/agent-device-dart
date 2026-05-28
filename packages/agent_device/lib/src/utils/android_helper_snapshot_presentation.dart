// Port of agent-device/src/utils/android-helper-snapshot-presentation.ts
// and agent-device/src/utils/android-helper-presentation/* submodules
library;

import '../snapshot/snapshot.dart';
import '../snapshot/tree.dart';

// Re-export detectPossibleRepeatedNavSubtree from its new home so callers
// that imported it from this file (including existing tests) continue to work.
export 'repeated_nav_subtree.dart' show detectPossibleRepeatedNavSubtree;

// ---------------------------------------------------------------------------
// Public types
// ---------------------------------------------------------------------------

/// Input for Android helper presentation — the filtered nodes and count of nodes
/// that were removed.
class AndroidHelperPresentationInput {
  final List<SnapshotNode> nodes;
  final int filteredCount;

  const AndroidHelperPresentationInput({
    required this.nodes,
    required this.filteredCount,
  });
}

// ---------------------------------------------------------------------------
// Public functions
// ---------------------------------------------------------------------------

/// Build the presentation input for Android helper snapshots.
///
/// If the snapshot was captured via the Android helper, filters noise
/// (zero-area nodes, rectless scrollable descendants, unlabeled action rows,
/// repeated action row descendants, adjacent structural duplicates, etc.)
/// and returns the filtered node list plus a count of removed nodes.
/// If raw mode is requested or the snapshot was not from the helper,
/// returns the input nodes unchanged with filteredCount = 0.
AndroidHelperPresentationInput buildAndroidHelperPresentationInput(
  Map<String, Object?> data,
  List<SnapshotNode> nodes, {
  bool? raw,
}) {
  if (raw == true || !_isAndroidHelperSnapshot(data)) {
    return AndroidHelperPresentationInput(nodes: nodes, filteredCount: 0);
  }
  final filtered = _filterAndroidHelperTextOutputNodes(nodes);
  return AndroidHelperPresentationInput(
    nodes: filtered,
    filteredCount: nodes.length - filtered.length,
  );
}

// ---------------------------------------------------------------------------
// Private helpers
// ---------------------------------------------------------------------------

const _actionableStructuralTypeTokens = [
  'button',
  'switch',
  'checkbox',
  'radio',
];
const _structuralNoiseTypeTokens = ['button', 'image', 'textview', 'view'];

bool _isAndroidHelperSnapshot(Map<String, Object?> data) {
  final metadata = data['androidSnapshot'];
  if (metadata is! Map) return false;
  return metadata['backend'] == 'android-helper';
}

List<SnapshotNode> _filterAndroidHelperTextOutputNodes(
  List<SnapshotNode> nodes,
) {
  if (nodes.isEmpty) return nodes;

  final removed = <int>{};
  final replacements = <int, SnapshotNode>{};
  final nodeIndex = Map.fromEntries(nodes.map((node) => MapEntry(node.index, node)));
  _markZeroAreaNodesForRemoval(nodes, removed);
  _markRectlessScrollableDescendantsForRemoval(nodes, nodeIndex, removed, replacements);
  _markUnlabeledActionRowsForPromotion(nodes, removed, replacements);
  _markRepeatedActionRowDescendantsForRemoval(nodes, removed);
  _markAdjacentDuplicateStructuralNodesForRemoval(nodes, removed, replacements);

  return nodes
      .where((node) => !removed.contains(node.index))
      .map((node) => replacements[node.index] ?? node)
      .toList();
}

void _markZeroAreaNodesForRemoval(List<SnapshotNode> nodes, Set<int> removed) {
  for (final node in nodes) {
    if (node.rect == null ||
        _hasRenderableArea(node.rect!) ||
        _isRootNode(node)) {
      continue;
    }
    _markNodeAndDescendantsForRemoval(nodes, node.index, removed);
  }
}

void _markRectlessScrollableDescendantsForRemoval(
  List<SnapshotNode> nodes,
  Map<int, SnapshotNode> nodeIndex,
  Set<int> removed,
  Map<int, SnapshotNode> replacements,
) {
  for (final node in nodes) {
    if (removed.contains(node.index) || node.rect != null || _isRootNode(node)) {
      continue;
    }

    final scrollAncestor = _findAncestor(node, nodeIndex, _isScrollableNode);
    if (scrollAncestor != null) {
      _addHiddenContentHint(
        replacements,
        scrollAncestor,
        _inferRectlessNodeDirection(node, nodes),
      );
    }
    _markNodeAndDescendantsForRemoval(nodes, node.index, removed);
  }
}

String? _inferRectlessNodeDirection(
  SnapshotNode node,
  List<SnapshotNode> nodes,
) {
  final renderedSiblingIndexes = nodes
      .where(
        (candidate) =>
            candidate.parentIndex == node.parentIndex &&
            candidate.rect != null &&
            _hasRenderableArea(candidate.rect!),
      )
      .map((candidate) => candidate.index)
      .toList();
  if (renderedSiblingIndexes.isEmpty) return null;

  // Android helper rectless children are offscreen list content. UIAutomator
  // traversal order is the only signal left once bounds disappear, so this is
  // intentionally a conservative above/below hint rather than exact geometry.
  if (node.index < renderedSiblingIndexes.reduce((a, b) => a < b ? a : b)) {
    return 'above';
  }
  if (node.index > renderedSiblingIndexes.reduce((a, b) => a > b ? a : b)) {
    return 'below';
  }
  return null;
}

void _addHiddenContentHint(
  Map<int, SnapshotNode> replacements,
  SnapshotNode node,
  String? direction,
) {
  if (direction == null) return;
  final existing = replacements[node.index] ?? node;
  final newNode = SnapshotNode(
    index: existing.index,
    ref: existing.ref,
    type: existing.type,
    role: existing.role,
    subrole: existing.subrole,
    label: existing.label,
    value: existing.value,
    identifier: existing.identifier,
    rect: existing.rect,
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
    hiddenContentAbove: (existing.hiddenContentAbove == true || direction == 'above') ? true : null,
    hiddenContentBelow: (existing.hiddenContentBelow == true || direction == 'below') ? true : null,
    presentationHints: existing.presentationHints,
  );
  replacements[node.index] = newNode;
}

void _markUnlabeledActionRowsForPromotion(
  List<SnapshotNode> nodes,
  Set<int> removed,
  Map<int, SnapshotNode> replacements,
) {
  for (final node in nodes) {
    if (removed.contains(node.index) || !_isUnlabeledActionRow(node)) continue;

    final descendants = _collectDescendants(nodes, node.index);
    final promotedContent = _collectPromotableRowContent(descendants, node, removed);
    if (promotedContent.label.isEmpty) continue;

    final existing = replacements[node.index] ?? node;
    replacements[node.index] = SnapshotNode(
      index: existing.index,
      ref: existing.ref,
      type: existing.type,
      role: existing.role,
      subrole: existing.subrole,
      label: promotedContent.label,
      value: existing.value,
      identifier: existing.identifier,
      rect: existing.rect,
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
      hiddenContentAbove: existing.hiddenContentAbove,
      hiddenContentBelow: existing.hiddenContentBelow,
      presentationHints: existing.presentationHints,
    );
    for (final descendantIndex in promotedContent.removableIndexes) {
      _markNodeAndDescendantsForRemoval(nodes, descendantIndex, removed);
    }
  }
}

({String label, List<int> removableIndexes}) _collectPromotableRowContent(
  List<SnapshotNode> descendants,
  SnapshotNode parent,
  Set<int> removed,
) {
  final labels = <String>[];
  final removableIndexes = <int>[];
  final seen = <String>{};
  for (final descendant in descendants) {
    if (removed.contains(descendant.index) ||
        !_isPassiveRowContent(descendant) ||
        !_isRectContainedBy(descendant.rect, parent.rect)) {
      continue;
    }
    final label = _visibleNodeLabel(descendant).trim().replaceAll(RegExp(r'\s+'), ' ');
    final normalized = _normalizeStructuralNodeLabel(label);
    removableIndexes.add(descendant.index);
    if (label.isEmpty || normalized == null || seen.contains(normalized)) continue;
    seen.add(normalized);
    labels.add(label);
  }
  return (label: labels.join(', '), removableIndexes: removableIndexes);
}

void _markRepeatedActionRowDescendantsForRemoval(
  List<SnapshotNode> nodes,
  Set<int> removed,
) {
  for (final node in nodes) {
    if (removed.contains(node.index) || !_isActionRowParent(node)) continue;

    final parentLabel = _normalizeStructuralNodeLabel(_visibleNodeLabel(node));
    if (parentLabel == null) continue;

    final repeatedDescendants = _collectDescendants(nodes, node.index)
        .where(
          (descendant) =>
              !removed.contains(descendant.index) &&
              _isRepeatedActionRowDescendant(node, descendant, parentLabel),
        )
        .toList();

    for (final descendant in repeatedDescendants.where(_isPassiveRowContent)) {
      _markNodeAndDescendantsForRemoval(nodes, descendant.index, removed);
    }

    final repeatedControls = repeatedDescendants
        .where((descendant) => !_isPassiveRowContent(descendant))
        .toList();
    final repeatedControlLabels = repeatedControls
        .map((descendant) => _normalizeStructuralNodeLabel(_visibleNodeLabel(descendant)))
        .where((label) => label != null)
        .toSet();
    if (repeatedControls.length < 2 || repeatedControlLabels.length < 2) continue;

    for (final descendant in repeatedControls) {
      _markNodeAndDescendantsForRemoval(nodes, descendant.index, removed);
    }
  }
}

void _markAdjacentDuplicateStructuralNodesForRemoval(
  List<SnapshotNode> nodes,
  Set<int> removed,
  Map<int, SnapshotNode> replacements,
) {
  final lastByLabel = <String, SnapshotNode>{};
  for (final node in nodes) {
    if (removed.contains(node.index) || !_isStructuralNoiseCandidate(node)) {
      continue;
    }
    final label = _normalizeStructuralNodeLabel(_visibleNodeLabel(node));
    if (label == null) continue;

    // RN can expose the same visible row content through parallel typed siblings
    // such as ImageView + Button or TextView + Button, so label is the signature.
    final previous = lastByLabel[label];
    if (previous != null &&
        _shouldCollapseAdjacentStructuralDuplicate(previous, node, removed)) {
      final survivor = _collapseAdjacentStructuralDuplicate(
        nodes,
        previous,
        node,
        removed,
        replacements,
      );
      lastByLabel[label] = survivor;
      continue;
    }
    lastByLabel[label] = node;
  }
}

bool _shouldCollapseAdjacentStructuralDuplicate(
  SnapshotNode previous,
  SnapshotNode node,
  Set<int> removed,
) {
  return !removed.contains(previous.index) &&
      _areSameVisualRow(previous.rect, node.rect) &&
      (_areStructurallyAdjacent(previous, node) ||
          _isPassiveChildOfActionableDuplicate(previous, node));
}

SnapshotNode _collapseAdjacentStructuralDuplicate(
  List<SnapshotNode> nodes,
  SnapshotNode previous,
  SnapshotNode node,
  Set<int> removed,
  Map<int, SnapshotNode> replacements,
) {
  final survivor = _chooseStructuralRepresentative(previous, node);
  final collapsed = survivor.index == previous.index ? node : previous;
  final collapsedHint = (collapsed.type ?? '').toLowerCase().contains('image') ? 'has image' : null;
  final existing = replacements[survivor.index] ?? survivor;
  final collapsedHints =
      (replacements[collapsed.index] ?? collapsed).presentationHints;
  final mergedHints = _mergePresentationHints(
    existing.presentationHints,
    collapsedHints,
    collapsedHint,
  );
  replacements[survivor.index] = SnapshotNode(
    index: existing.index,
    ref: existing.ref,
    type: existing.type,
    role: existing.role,
    subrole: existing.subrole,
    label: existing.label,
    value: existing.value,
    identifier: existing.identifier,
    rect: existing.rect,
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
    hiddenContentAbove: existing.hiddenContentAbove,
    hiddenContentBelow: existing.hiddenContentBelow,
  )..presentationHints = mergedHints.isEmpty ? null : mergedHints;
  _markNodeAndDescendantsForRemoval(nodes, collapsed.index, removed);
  return replacements[survivor.index] ?? survivor;
}

List<String> _mergePresentationHints(
  List<String>? current,
  List<String>? collapsed,
  String? extra,
) {
  final result = <String>{
    ...?current,
    ...?collapsed,
    ?extra,
  };
  return result.toList();
}

void _markNodeAndDescendantsForRemoval(
  List<SnapshotNode> nodes,
  int rootIndex,
  Set<int> removed,
) {
  final pending = [rootIndex];
  while (pending.isNotEmpty) {
    final current = pending.removeLast();
    if (removed.contains(current)) continue;
    removed.add(current);
    for (final node in nodes) {
      if (node.parentIndex != current || removed.contains(node.index)) continue;
      pending.add(node.index);
    }
  }
}

// ---------------------------------------------------------------------------
// Geometry utilities
// ---------------------------------------------------------------------------

bool _hasRenderableArea(Rect rect) {
  return rect.width > 0 && rect.height > 0;
}

bool _isRectContainedBy(Rect? rect, Rect? container) {
  if (rect == null || container == null) return false;
  const tolerance = 2.0;
  return rect.x >= container.x - tolerance &&
      rect.y >= container.y - tolerance &&
      rect.x + rect.width <= container.x + container.width + tolerance &&
      rect.y + rect.height <= container.y + container.height + tolerance;
}

bool _areSameVisualRow(Rect? left, Rect? right) {
  if (left == null || right == null) return true;
  final leftCenterY = left.y + left.height / 2;
  final rightCenterY = right.y + right.height / 2;
  return (leftCenterY - rightCenterY).abs() <=
      [left.height, right.height, 1.0].reduce((a, b) => a > b ? a : b);
}

// ---------------------------------------------------------------------------
// Label utilities
// ---------------------------------------------------------------------------

/// Returns the visible label for a node, suppressing generic resource IDs
/// for layout-like types.
String _visibleNodeLabel(SnapshotNode node) {
  final label = displayNodeLabel(node);
  if (label.isEmpty || label != (node.identifier?.trim() ?? '')) {
    return label;
  }
  if (!_isGenericResourceId(label)) {
    return label;
  }
  final type = (node.type ?? '').toLowerCase();
  if (type.contains('view') ||
      type.contains('layout') ||
      type.contains('image') ||
      type.contains('list') ||
      type.contains('recyclerview') ||
      type.contains('collection')) {
    return '';
  }
  return label;
}

String? _normalizeStructuralNodeLabel(String label) {
  final normalized = label.trim().replaceAll(RegExp(r'\s+'), ' ').toLowerCase();
  if (normalized.isEmpty) return null;
  if (RegExp(r'^(true|false|\d+)$').hasMatch(normalized)) return null;
  return normalized;
}

bool _isGenericResourceId(String value) {
  return RegExp(r'^[\w.]+:id\/[\w.-]+$', caseSensitive: false).hasMatch(value);
}

// ---------------------------------------------------------------------------
// Predicates
// ---------------------------------------------------------------------------

bool _isRootNode(SnapshotNode node) {
  return node.parentIndex == null;
}

bool _isEditableNode(SnapshotNode node) {
  final type = (node.type ?? '').toLowerCase();
  final identifier = (node.identifier ?? '').trim().toLowerCase();
  return type.contains('edittext') ||
      type.contains('textfield') ||
      identifier == 'composer';
}

bool _isScrollableNode(SnapshotNode node) {
  final type = (node.type ?? '').toLowerCase();
  return type.contains('scroll') ||
      type.contains('list') ||
      type.contains('recyclerview');
}

bool _isStructuralNoiseCandidate(SnapshotNode node) {
  if (node.rect == null ||
      !_hasRenderableArea(node.rect!) ||
      _isRootNode(node) ||
      _isEditableNode(node)) {
    return false;
  }
  final type = (node.type ?? '').toLowerCase();
  return type == 'text' || _hasAnyTypeToken(type, _structuralNoiseTypeTokens);
}

bool _isUnlabeledActionRow(SnapshotNode node) {
  return node.hittable == true &&
      !_isEditableNode(node) &&
      node.rect != null &&
      _hasRenderableArea(node.rect!) &&
      _visibleNodeLabel(node).trim().isEmpty;
}

bool _isActionRowParent(SnapshotNode node) {
  return node.hittable == true &&
      !_isEditableNode(node) &&
      node.rect != null &&
      _hasRenderableArea(node.rect!) &&
      _normalizeStructuralNodeLabel(_visibleNodeLabel(node)) != null;
}

bool _isPassiveRowContent(SnapshotNode node) {
  if (node.hittable == true || _isEditableNode(node)) return false;
  final type = (node.type ?? '').toLowerCase();
  return type.contains('text') || type.contains('image') || type.contains('icon');
}

bool _isRepeatedActionRowDescendant(
  SnapshotNode parent,
  SnapshotNode node,
  String parentLabel,
) {
  if (!_isStructuralNoiseCandidate(node) ||
      !_isRectContainedBy(node.rect, parent.rect)) {
    return false;
  }
  final label = _normalizeStructuralNodeLabel(_visibleNodeLabel(node));
  return label != null && label != parentLabel && parentLabel.contains(label);
}

// ---------------------------------------------------------------------------
// Tree utilities
// ---------------------------------------------------------------------------

SnapshotNode? _findAncestor(
  SnapshotNode node,
  Map<int, SnapshotNode> nodeIndex,
  bool Function(SnapshotNode) predicate,
) {
  var current = node;
  while (current.parentIndex != null) {
    final parent = nodeIndex[current.parentIndex];
    if (parent == null) return null;
    if (predicate(parent)) return parent;
    current = parent;
  }
  return null;
}

List<SnapshotNode> _collectDescendants(List<SnapshotNode> nodes, int rootIndex) {
  final descendants = <SnapshotNode>[];
  final pending = [rootIndex];
  while (pending.isNotEmpty) {
    final current = pending.removeLast();
    for (final node in nodes) {
      if (node.parentIndex != current) continue;
      descendants.add(node);
      pending.add(node.index);
    }
  }
  return descendants;
}

// ---------------------------------------------------------------------------
// Structural representative selection
// ---------------------------------------------------------------------------

SnapshotNode _chooseStructuralRepresentative(
  SnapshotNode left,
  SnapshotNode right,
) {
  final leftScore = _structuralRepresentativeScore(left);
  final rightScore = _structuralRepresentativeScore(right);
  return rightScore > leftScore ? right : left;
}

int _structuralRepresentativeScore(SnapshotNode node) {
  final type = (node.type ?? '').toLowerCase();
  var score = 0;
  if (_hasAnyTypeToken(type, _actionableStructuralTypeTokens)) {
    score += 100;
  } else if (type.contains('image')) {
    score += 30;
  } else if (type.contains('textview') || type == 'text') {
    score += 20;
  } else if (type.contains('view')) {
    score += 10;
  }
  if (node.hittable == true) score += 20;
  if (node.enabled != false) score += 5;
  return score;
}

bool _hasAnyTypeToken(String type, List<String> tokens) {
  return tokens.any((token) => type.contains(token));
}

bool _isPassiveChildOfActionableDuplicate(
  SnapshotNode left,
  SnapshotNode right,
) {
  final parent = left.parentIndex == right.index
      ? right
      : right.parentIndex == left.index
      ? left
      : null;
  final child = parent?.index == left.index
      ? right
      : parent?.index == right.index
      ? left
      : null;
  if (parent == null || child == null) return false;
  return _chooseStructuralRepresentative(parent, child).index == parent.index;
}

bool _areStructurallyAdjacent(SnapshotNode left, SnapshotNode right) {
  if (left.parentIndex == right.parentIndex) {
    return (left.index - right.index).abs() <= 3;
  }
  if (left.parentIndex == right.index || right.parentIndex == left.index) {
    return false;
  }
  return ((left.depth ?? 0) - (right.depth ?? 0)).abs() <= 1 &&
      (left.index - right.index).abs() <= 2;
}

