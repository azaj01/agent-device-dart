// Port of agent-device/src/utils/android-helper-snapshot-presentation.ts
library;

import '../snapshot/snapshot.dart';
import '../snapshot/tree.dart';

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
/// (zero-area nodes, duplicate emails, adjacent structural duplicates, etc.)
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

/// Detect whether the snapshot likely contains repeated navigation subtrees.
///
/// Returns true if the nodes contain ≥8 duplicates by type+label signature,
/// which often indicates a bottom navigation or tab bar that was captured
/// multiple times.
bool detectPossibleRepeatedNavSubtree(List<SnapshotNode> nodes) {
  if (nodes.length < 20) {
    return false;
  }
  final counts = <String, int>{};
  for (final node in nodes) {
    final type = (node.type ?? '').toLowerCase();
    final label = _normalizeRepeatedNodeLabel(displayNodeLabel(node));
    if (label == null) continue;
    final signature = '$type|$label';
    counts[signature] = (counts[signature] ?? 0) + 1;
  }
  var duplicateCount = 0;
  for (final count in counts.values) {
    if (count > 1) {
      duplicateCount += count;
    }
  }
  return duplicateCount >= 8;
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
  _markZeroAreaNodesForRemoval(nodes, removed);
  _markBottomNavNodesNearComposerForRemoval(nodes, removed, replacements);
  _markDuplicateEmailButtonsForRemoval(nodes, removed);
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

void _markBottomNavNodesNearComposerForRemoval(
  List<SnapshotNode> nodes,
  Set<int> removed,
  Map<int, SnapshotNode> replacements,
) {
  final composer = _findBottomEditableNode(nodes);
  final composerRect = composer?.rect;
  if (composerRect == null) return;

  final navNodes = _findBottomNavigationLikeNodes(nodes, composerRect);
  for (final node in navNodes) {
    _addPresentationHints(replacements, node, ['likely navigation']);
    _markDescendantsForRemoval(nodes, node.index, removed);
  }
}

void _markDuplicateEmailButtonsForRemoval(
  List<SnapshotNode> nodes,
  Set<int> removed,
) {
  final seenByParent = <String, SnapshotNode>{};
  for (final node in nodes) {
    if (removed.contains(node.index) ||
        !_isEmailLikeLabel(displayNodeLabel(node))) {
      continue;
    }
    final parentKey = node.parentIndex != null
        ? node.parentIndex.toString()
        : 'root';
    final signature =
        '$parentKey|${displayNodeLabel(node).trim().toLowerCase()}';
    final previous = seenByParent[signature];
    if (previous == null) {
      seenByParent[signature] = node;
      continue;
    }
    if (_areSameVisualRow(previous.rect, node.rect)) {
      _markNodeAndDescendantsForRemoval(nodes, node.index, removed);
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
    final label = _normalizeStructuralNodeLabel(displayNodeLabel(node));
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
      _areStructurallyAdjacentForCollapse(previous, node);
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
  final collapsedHint = _imagePresentationHint(collapsed);
  final collapsedNode = replacements[collapsed.index] ?? collapsed;
  final hints = [
    ..._readPresentationHints(collapsedNode),
    if (collapsedHint != null) ...[collapsedHint],
  ];
  _addPresentationHints(replacements, survivor, hints);
  _markNodeAndDescendantsForRemoval(nodes, collapsed.index, removed);
  return replacements[survivor.index] ?? survivor;
}

void _markNodeAndDescendantsForRemoval(
  List<SnapshotNode> nodes,
  int rootIndex,
  Set<int> removed,
) {
  removed.add(rootIndex);
  _markDescendantsForRemoval(nodes, rootIndex, removed);
}

void _markDescendantsForRemoval(
  List<SnapshotNode> nodes,
  int rootIndex,
  Set<int> removed,
) {
  final pending = [rootIndex];
  while (pending.isNotEmpty) {
    final current = pending.removeLast();
    for (final node in nodes) {
      if (node.parentIndex != current || removed.contains(node.index)) continue;
      removed.add(node.index);
      pending.add(node.index);
    }
  }
}

void _addPresentationHints(
  Map<int, SnapshotNode> replacements,
  SnapshotNode node,
  List<String> hints,
) {
  final existing = replacements[node.index] ?? node;
  final existingHints = _readPresentationHints(existing);
  final merged = {
    ...existingHints,
    ...hints.where((h) => h.isNotEmpty),
  }.toList();
  replacements[node.index] = SnapshotNode(
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
  )..presentationHints = merged;
}

List<String> _readPresentationHints(SnapshotNode node) {
  return node.presentationHints ?? [];
}

bool _hasRenderableArea(Rect rect) {
  return rect.width > 0 && rect.height > 0;
}

bool _isRootNode(SnapshotNode node) {
  return node.parentIndex == null;
}

Rect? _resolveLikelyViewport(List<SnapshotNode> nodes) {
  Rect? best;
  var bestArea = 0.0;
  for (final node in nodes) {
    if (node.rect == null || !_hasRenderableArea(node.rect!)) continue;
    final area = node.rect!.width * node.rect!.height;
    if (area > bestArea) {
      best = node.rect;
      bestArea = area;
    }
  }
  return best;
}

SnapshotNode? _findBottomEditableNode(List<SnapshotNode> nodes) {
  final viewport = _resolveLikelyViewport(nodes);
  final lowerBound = viewport != null
      ? viewport.y + viewport.height * 0.65
      : double.negativeInfinity;
  return nodes.firstWhereOrNull((node) {
    if (node.rect == null || node.rect!.y < lowerBound) return false;
    return _isEditableNode(node);
  });
}

List<SnapshotNode> _findBottomNavigationLikeNodes(
  List<SnapshotNode> nodes,
  Rect composerRect,
) {
  final rows = <String, List<SnapshotNode>>{};
  for (final node in nodes) {
    if (!_isBottomNavigationCandidate(node, nodes, composerRect)) continue;
    final rect = node.rect!;
    final parentKey = node.parentIndex != null
        ? node.parentIndex.toString()
        : 'root';
    final rowKey = [
      parentKey,
      _bucket(rect.y + rect.height / 2, 24),
      _bucket(rect.width, 24),
      _bucket(rect.height, 24),
    ].join('|');
    rows.putIfAbsent(rowKey, () => []).add(node);
  }

  final navigationNodes = <SnapshotNode>[];
  for (final row in rows.values) {
    if (!_isBottomNavigationRow(row, nodes, composerRect)) continue;
    navigationNodes.addAll(row);
  }
  return navigationNodes;
}

bool _isNearComposerVerticalBand(Rect rect, Rect composerRect) {
  final tolerance = (composerRect.height * 2).clamp(96, double.infinity);
  return rect.y <= composerRect.y + composerRect.height + tolerance &&
      rect.y + rect.height >= composerRect.y - tolerance;
}

bool _isBottomNavigationCandidate(
  SnapshotNode node,
  List<SnapshotNode> nodes,
  Rect composerRect,
) {
  if (node.rect == null ||
      !_hasRenderableArea(node.rect!) ||
      _isRootNode(node) ||
      _isEditableNode(node) ||
      _isTextOnlyNode(node) ||
      !_isNearComposerVerticalBand(node.rect!, composerRect)) {
    return false;
  }
  return _normalizeRepeatedNodeLabel(_getNodeOrDescendantLabel(node, nodes)) !=
      null;
}

bool _isBottomNavigationRow(
  List<SnapshotNode> row,
  List<SnapshotNode> nodes,
  Rect composerRect,
) {
  if (row.length < 3) return false;
  final labels = <String>{};
  for (final node in row) {
    final label = _normalizeRepeatedNodeLabel(
      _getNodeOrDescendantLabel(node, nodes),
    );
    if (label != null) labels.add(label);
  }
  if (labels.length < 3) return false;

  final sorted = [...row]
    ..sort((left, right) => (left.rect?.x ?? 0).compareTo(right.rect?.x ?? 0));
  final first = sorted.first.rect!;
  final last = sorted.last.rect!;
  final horizontalSpan = last.x + last.width - first.x;
  return horizontalSpan >= composerRect.width;
}

bool _isEditableNode(SnapshotNode node) {
  final type = (node.type ?? '').toLowerCase();
  final identifier = (node.identifier ?? '').trim().toLowerCase();
  return type.contains('edittext') ||
      type.contains('textfield') ||
      identifier == 'composer';
}

bool _isTextOnlyNode(SnapshotNode node) {
  final type = (node.type ?? '').toLowerCase();
  return type.contains('textview') || type == 'text';
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

String? _imagePresentationHint(SnapshotNode node) {
  return (node.type ?? '').toLowerCase().contains('image') ? 'has image' : null;
}

bool _areStructurallyAdjacentForCollapse(
  SnapshotNode left,
  SnapshotNode right,
) {
  if (_areStructurallyAdjacent(left, right)) {
    return true;
  }
  return _isPassiveChildOfActionableDuplicate(left, right);
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

String? _normalizeStructuralNodeLabel(String label) {
  final normalized = label.trim().replaceAll(RegExp(r'\s+'), ' ').toLowerCase();
  if (normalized.isEmpty) return null;
  if (RegExp(r'^(true|false|\d+)$').hasMatch(normalized)) return null;
  return normalized;
}

String _getNodeOrDescendantLabel(SnapshotNode node, List<SnapshotNode> nodes) {
  final label = displayNodeLabel(node);
  if (label.trim().isNotEmpty) return label;
  final pending = [node.index];
  while (pending.isNotEmpty) {
    final current = pending.removeLast();
    for (final child in nodes) {
      if (child.parentIndex != current) continue;
      final childLabel = displayNodeLabel(child);
      if (childLabel.trim().isNotEmpty) return childLabel;
      pending.add(child.index);
    }
  }
  return '';
}

String? _normalizeRepeatedNodeLabel(String label) {
  final normalized = label.trim().replaceAll(RegExp(r'\s+'), ' ').toLowerCase();
  if (normalized.isEmpty || _isEmailLikeLabel(normalized)) return null;
  return normalized;
}

int _bucket(double value, int size) {
  return (value / size).round();
}

bool _isEmailLikeLabel(String label) {
  return RegExp(r'\S+@\S+\.\S+').hasMatch(label);
}

bool _areSameVisualRow(Rect? left, Rect? right) {
  if (left == null || right == null) return true;
  final leftCenterY = left.y + left.height / 2;
  final rightCenterY = right.y + right.height / 2;
  return (leftCenterY - rightCenterY).abs() <=
      [left.height, right.height, 1].reduce((a, b) => a > b ? a : b);
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

extension on List<SnapshotNode> {
  SnapshotNode? firstWhereOrNull(bool Function(SnapshotNode) test) {
    for (final item in this) {
      if (test(item)) return item;
    }
    return null;
  }
}
