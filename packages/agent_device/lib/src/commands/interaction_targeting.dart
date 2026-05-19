// Port of agent-device/src/commands/interaction-targeting.ts
library;

import 'package:agent_device/src/snapshot/processing.dart';
import 'package:agent_device/src/snapshot/snapshot.dart';

/// List of semantic role fragments that should be preferred as touch targets.
/// These represent interactive elements that have well-defined touch surfaces.
const List<String> semanticTouchRoleFragments = [
  'button',
  'link',
  'menuitem',
  'tabitem',
  'textfield',
  'searchfield',
  'securetextfield',
  'checkbox',
  'radio',
  'switch',
  'cell',
];

/// Reason why a node was selected as the actionable touch target.
enum ActionableTouchResolutionReason {
  /// A descendant with the same rect as the original node.
  sameRectDescendant('same-rect-descendant'),

  /// The node itself is a semantic touch target.
  semanticTarget('semantic-target'),

  /// A hittable ancestor was used as the target.
  hittableAncestor('hittable-ancestor'),

  /// An overly broad ancestor was rejected and the original node was used.
  overlyBroadAncestor('overly-broad-ancestor'),

  /// The original node was used as-is.
  original('original');

  final String value;
  const ActionableTouchResolutionReason(this.value);
}

/// Result of resolving a node to an actionable touch target.
class ActionableTouchResolution {
  /// The resolved node to use as the touch target.
  final SnapshotNode node;

  /// The reason this node was selected.
  final ActionableTouchResolutionReason reason;

  const ActionableTouchResolution({required this.node, required this.reason});
}

/// Resolve a node to the best actionable touch target according to the
/// semantic touch target resolution policy.
///
/// Returns [ActionableTouchResolution] with the resolved node and reason.
/// The policy prioritizes:
/// 1. Same-rect descendants (drill down to the most specific element)
/// 2. Semantic touch targets (elements with well-defined roles)
/// 3. Hittable ancestors (climb up to find a tappable surface)
/// 4. Rejecting overly broad ancestors (e.g., screen-filling containers)
ActionableTouchResolution resolveActionableTouchResolution(
  List<SnapshotNode> nodes,
  SnapshotNode node,
) {
  // Try to find a more specific descendant with the same rect.
  final descendant = _findPreferredActionableDescendant(nodes, node);
  if (descendant != null &&
      descendant.rect != null &&
      _resolveRectCenter(descendant.rect!) != null) {
    return ActionableTouchResolution(
      node: descendant,
      reason: ActionableTouchResolutionReason.sameRectDescendant,
    );
  }

  // Check if the node itself is a semantic touch target.
  if (_isSemanticTouchTarget(node) &&
      node.rect != null &&
      _resolveRectCenter(node.rect!) != null) {
    return ActionableTouchResolution(
      node: node,
      reason: ActionableTouchResolutionReason.semanticTarget,
    );
  }

  // Try to find a hittable ancestor.
  final ancestor = findNearestHittableAncestor(nodes, node);
  if (ancestor != null &&
      ancestor.rect != null &&
      _resolveRectCenter(ancestor.rect!) != null) {
    // Check if this ancestor is overly broad.
    if (_isOverlyBroadAncestor(node, ancestor, nodes)) {
      return ActionableTouchResolution(
        node: node,
        reason: ActionableTouchResolutionReason.overlyBroadAncestor,
      );
    }
    return ActionableTouchResolution(
      node: ancestor,
      reason: ActionableTouchResolutionReason.hittableAncestor,
    );
  }

  // Fall back to the original node.
  return ActionableTouchResolution(
    node: node,
    reason: ActionableTouchResolutionReason.original,
  );
}

/// Resolve a node to the best actionable touch target (returns just the node).
/// This is the public API for runtime callers.
SnapshotNode resolveActionableTouchNode(
  List<SnapshotNode> nodes,
  SnapshotNode node,
) {
  return resolveActionableTouchResolution(nodes, node).node;
}

/// Find a preferred actionable descendant with the same rect as the node.
/// Walks down the tree through children with the same rect until a more
/// specific (different) child is not found.
SnapshotNode? _findPreferredActionableDescendant(
  List<SnapshotNode> nodes,
  SnapshotNode node,
) {
  final targetRect = _normalizeRect(node.rect);
  if (targetRect == null) return null;

  var current = node;
  final visited = <String>{};

  while (!visited.contains(current.ref)) {
    visited.add(current.ref);

    // Find children with the same rect.
    final sameRectChildren = nodes.where((candidate) {
      if (candidate.parentIndex != current.index || !candidate.hittable!) {
        return false;
      }
      final candidateRect = _normalizeRect(candidate.rect);
      if (candidateRect == null) return false;
      return _areRectsApproximatelyEqual(candidateRect, targetRect);
    }).toList();

    // If there's not exactly one same-rect child, stop searching.
    if (sameRectChildren.length != 1) {
      break;
    }

    current = sameRectChildren[0];
  }

  // Return the deepest same-rect descendant, or null if none found.
  return current == node ? null : current;
}

/// Check if a node is a semantic touch target based on its type, role, or subrole.
bool _isSemanticTouchTarget(SnapshotNode node) {
  final roles = [
    node.type ?? '',
    node.role ?? '',
    node.subrole ?? '',
  ].map((v) => _normalizeType(v)).toList();

  return roles.any(_isSemanticTouchRole);
}

/// Check if a role string matches a semantic touch role.
bool _isSemanticTouchRole(String role) {
  // Match 'tab' exactly so broad roles like 'table' or 'tabbar' don't match.
  if (role == 'tab') return true;

  // Match if the role contains any of the semantic fragments.
  return semanticTouchRoleFragments.any((fragment) => role.contains(fragment));
}

/// Check if two rects are approximately equal (within 0.5 units tolerance).
bool _areRectsApproximatelyEqual(Rect left, Rect right) {
  const tolerance = 0.5;
  return (left.x - right.x).abs() <= tolerance &&
      (left.y - right.y).abs() <= tolerance &&
      (left.width - right.width).abs() <= tolerance &&
      (left.height - right.height).abs() <= tolerance;
}

/// Check if an ancestor is overly broad (screen-sized or viewport-sized).
/// An overly broad ancestor is one that covers most/all of the viewport
/// but the child is much smaller.
bool _isOverlyBroadAncestor(
  SnapshotNode node,
  SnapshotNode ancestor,
  List<SnapshotNode> nodes,
) {
  final nodeRect = _normalizeRect(node.rect);
  final ancestorRect = _normalizeRect(ancestor.rect);
  if (nodeRect == null || ancestorRect == null) return false;

  final rootViewportRect = _resolveRootViewportRect(nodes, nodeRect);
  if (rootViewportRect == null) return false;

  // Check if the ancestor covers the viewport.
  if (!_isRectViewportSized(ancestorRect, rootViewportRect)) {
    return false;
  }

  // If the rects are approximately equal, the ancestor is not overly broad.
  return !_areRectsApproximatelyEqual(nodeRect, ancestorRect);
}

/// Resolve the root viewport rect (application or window node) containing the target.
Rect? _resolveRootViewportRect(List<SnapshotNode> nodes, Rect targetRect) {
  final targetCenter = centerOfRect(targetRect);

  final viewportRects = <Rect>[];
  for (final node in nodes) {
    final type = (node.type ?? '').toLowerCase();
    if (!type.contains('application') && !type.contains('window')) {
      continue;
    }
    final rect = _normalizeRect(node.rect);
    if (rect != null) {
      viewportRects.add(rect);
    }
  }

  if (viewportRects.isEmpty) return null;

  // Find viewports that contain the target center.
  final containingRects = <Rect>[];
  for (final rect in viewportRects) {
    if (_containsPoint(rect, targetCenter.x, targetCenter.y)) {
      containingRects.add(rect);
    }
  }

  // Prefer a containing viewport, fall back to largest viewport.
  final candidates = containingRects.isNotEmpty
      ? containingRects
      : viewportRects;
  return _pickLargestRect(candidates);
}

/// Check if a rect covers most of its viewport (>= 90% of viewport, >= 80% of rect).
bool _isRectViewportSized(Rect rect, Rect viewportRect) {
  final overlapArea = _intersectionArea(rect, viewportRect);
  final rectArea = rect.width * rect.height;
  final viewportArea = viewportRect.width * viewportRect.height;

  if (overlapArea <= 0 || rectArea <= 0 || viewportArea <= 0) return false;

  final viewportCoverage = overlapArea / viewportArea;
  final rectCoverage = overlapArea / rectArea;

  return viewportCoverage >= 0.9 && rectCoverage >= 0.8;
}

/// Calculate the intersection area of two rects.
double _intersectionArea(Rect left, Rect right) {
  final xMax = ((left.x + left.width) < (right.x + right.width))
      ? (left.x + left.width)
      : (right.x + right.width);
  final xMin = left.x > right.x ? left.x : right.x;
  final yMax = ((left.y + left.height) < (right.y + right.height))
      ? (left.y + left.height)
      : (right.y + right.height);
  final yMin = left.y > right.y ? left.y : right.y;

  final xOverlap = (xMax - xMin).clamp(0.0, double.infinity);
  final yOverlap = (yMax - yMin).clamp(0.0, double.infinity);

  return xOverlap * yOverlap;
}

/// Check if a point is inside a rect.
bool _containsPoint(Rect rect, double x, double y) {
  return x >= rect.x &&
      x <= rect.x + rect.width &&
      y >= rect.y &&
      y <= rect.y + rect.height;
}

/// Pick the largest rect from a list (by area).
Rect? _pickLargestRect(List<Rect> rects) {
  Rect? best;
  var bestArea = -1.0;
  for (final rect in rects) {
    final area = rect.width * rect.height;
    if (area > bestArea) {
      best = rect;
      bestArea = area;
    }
  }
  return best;
}

/// Normalize a rect by checking all values are finite and positive.
Rect? _normalizeRect(Rect? rect) {
  if (rect == null) return null;
  final x = rect.x;
  final y = rect.y;
  final width = rect.width;
  final height = rect.height;

  if (!x.isFinite || !y.isFinite || !width.isFinite || !height.isFinite) {
    return null;
  }

  if (width < 0 || height < 0) return null;

  return rect;
}

/// Resolve the center of a rect, returning null if invalid.
Point? _resolveRectCenter(Rect rect) {
  final normalized = _normalizeRect(rect);
  if (normalized == null) return null;

  final center = centerOfRect(normalized);

  if (!center.x.isFinite || !center.y.isFinite) return null;

  return center;
}

/// Normalize a type string for comparison (lowercase, extract suffix after dot).
String _normalizeType(String type) {
  if (type.isEmpty) return '';

  var normalized = type.toLowerCase();

  // Extract the last component after a dot (e.g. 'android.widget.Button' -> 'button').
  if (normalized.contains('.')) {
    final lastDot = normalized.lastIndexOf('.');
    if (lastDot != -1 && lastDot < normalized.length - 1) {
      normalized = normalized.substring(lastDot + 1);
    }
  }

  return normalized;
}
