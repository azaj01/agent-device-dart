// Port of agent-device/src/utils/repeated-nav-subtree.ts
library;

import '../snapshot/snapshot.dart';
import '../snapshot/tree.dart' show displayNodeLabel;

// ---------------------------------------------------------------------------
// Public API
// ---------------------------------------------------------------------------

/// Detect whether [nodes] likely contain a repeated navigation subtree
/// (e.g. a tab bar or nav bar captured multiple times).
///
/// Returns true when ≥ 8 nodes share the same type+label signature AND at
/// least two of them have overlapping rects — which indicates the same UI
/// element appearing more than once in the tree.
bool detectPossibleRepeatedNavSubtree(List<SnapshotNode> nodes) {
  if (nodes.length < 20) return false;

  final groups = <String, List<SnapshotNode>>{};
  for (final node in nodes) {
    final type = (node.type ?? '').toLowerCase();
    final label = _normalizeRepeatedNodeLabel(displayNodeLabel(node));
    if (label == null) continue;
    final signature = '$type|$label';
    groups.putIfAbsent(signature, () => []).add(node);
  }

  var duplicateCount = 0;
  for (final group in groups.values) {
    if (group.length <= 1 || !_hasOverlappingDuplicateRects(group)) continue;
    duplicateCount += group.length;
  }
  return duplicateCount >= 8;
}

// ---------------------------------------------------------------------------
// Helpers (mirrors snapshot-label-signals.ts)
// ---------------------------------------------------------------------------

/// Normalize a node label for repeated-nav detection: lowercase, collapse
/// whitespace, reject email-like strings.
///
/// Returns null when the label is empty or looks like an email address.
String? _normalizeRepeatedNodeLabel(String label) {
  final normalized = label.trim().replaceAll(RegExp(r'\s+'), ' ').toLowerCase();
  if (normalized.isEmpty || _isEmailLikeLabel(normalized)) return null;
  return normalized;
}

bool _isEmailLikeLabel(String label) =>
    RegExp(r'\S+@\S+\.\S+').hasMatch(label);

// ---------------------------------------------------------------------------
// Rect overlap detection
// ---------------------------------------------------------------------------

bool _hasOverlappingDuplicateRects(List<SnapshotNode> nodes) {
  for (var left = 0; left < nodes.length; left++) {
    for (var right = left + 1; right < nodes.length; right++) {
      if (_rectsOverlap(nodes[left].rect, nodes[right].rect)) return true;
    }
  }
  return false;
}

bool _rectsOverlap(Rect? left, Rect? right) {
  if (left == null || right == null) return true;
  const tolerance = 0.5;
  return !(left.x + left.width <= right.x + tolerance ||
      right.x + right.width <= left.x + tolerance ||
      left.y + left.height <= right.y + tolerance ||
      right.y + right.height <= left.y + tolerance);
}
