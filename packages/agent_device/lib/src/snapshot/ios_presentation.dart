// Port of agent-device/src/daemon/snapshot-presentation/ios/index.ts
// (includes actions.ts, noise.ts, rows.ts, scroll.ts in one file)
library;

import '../snapshot/presentation_tree.dart';
import '../snapshot/processing.dart' show normalizeType;
import '../snapshot/snapshot.dart';

// ---------------------------------------------------------------------------
// Entry point
// ---------------------------------------------------------------------------

/// Apply the iOS interactive snapshot presentation pipeline to [nodes].
///
/// Runs three ordered rules:
/// 1. Noise suppression (status bar, keyboard, structural identifiers, etc.)
/// 2. Implicit scrollable action labelling
/// 3. Table/collection row collapsing
///
/// Returns the original list unchanged when [nodes] is empty or when no
/// rules produce any changes.
List<RawSnapshotNode> presentIosInteractiveSnapshot(List<RawSnapshotNode> nodes) {
  if (nodes.isEmpty) return nodes;

  final replacements = <int, RawSnapshotNode>{};
  final suppressedIndexes = <int>{};
  final context = SnapshotTreeRuleContext(
    replacements: replacements,
    suppressedIndexes: suppressedIndexes,
  );

  _collectIosPresentationNoiseSuppression(nodes, context);
  _collectIosImplicitScrollableActions(nodes, context);
  _collectIosRowPresentation(nodes, context);

  if (suppressedIndexes.isEmpty && replacements.isEmpty) return nodes;

  final filtered = nodes
      .where((node) => !suppressedIndexes.contains(node.index))
      .map((node) => replacements[node.index] ?? node)
      .toList();

  return reindexSnapshotNodesWithSuppressedParents(
    filtered,
    suppressedIndexes,
    nodes,
  );
}

// ---------------------------------------------------------------------------
// Rule 1 – Noise suppression (noise.ts + scroll.ts)
// ---------------------------------------------------------------------------

void _collectIosPresentationNoiseSuppression(
  List<RawSnapshotNode> nodes,
  SnapshotTreeRuleContext context,
) {
  final suppressed = context.suppressedIndexes;
  _collectIosOffscreenKeyboardSuppression(nodes, suppressed);
  _collectIosStructuralIdentifierSuppression(nodes, suppressed);
  _collectIosScrollIndicatorPresentation(nodes, context);
  _collectIosSearchToolbarSuppression(nodes, suppressed);
  _collectIosActionWrapperSuppression(nodes, context);
  _collectIosReactNativeOverlayWrapperSuppression(nodes, suppressed);
  _collectIosRepeatedStaticSuppression(nodes, suppressed);
}

// -- Offscreen keyboard --

void _collectIosOffscreenKeyboardSuppression(
  List<RawSnapshotNode> nodes,
  Set<int> suppressedIndexes,
) {
  final viewport = findLargestViewportRect(nodes);
  if (viewport == null) return;
  final screenBottom = viewport.y + viewport.height;

  for (var position = 0; position < nodes.length; position++) {
    final node = nodes[position];
    if (!_isOffscreenKeyboardNode(node, screenBottom)) continue;

    suppressedIndexes.add(node.index);
    _suppressOffscreenKeyboardAncestors(node, nodes, suppressedIndexes, screenBottom);
    for (final descendant in collectDescendants(nodes, position)) {
      suppressedIndexes.add(descendant.index);
    }
  }
}

bool _isOffscreenKeyboardNode(RawSnapshotNode node, double screenBottom) {
  if (node.rect == null || normalizeType(node.type ?? '') != 'keyboard') return false;
  return node.rect!.y >= screenBottom;
}

void _suppressOffscreenKeyboardAncestors(
  RawSnapshotNode node,
  List<RawSnapshotNode> nodes,
  Set<int> suppressedIndexes,
  double screenBottom,
) {
  final byIndex = <int, RawSnapshotNode>{for (final n in nodes) n.index: n};
  var parentIndex = node.parentIndex;
  while (parentIndex != null) {
    final parent = byIndex[parentIndex];
    if (parent?.rect == null || parent!.rect!.y < screenBottom) break;
    suppressedIndexes.add(parent.index);
    parentIndex = parent.parentIndex;
  }
}

// -- Structural identifiers (no label/value, has identifier) --

void _collectIosStructuralIdentifierSuppression(
  List<RawSnapshotNode> nodes,
  Set<int> suppressedIndexes,
) {
  for (final node in nodes) {
    if (normalizeType(node.type ?? '') != 'other') continue;
    if (node.hittable == true || (node.label?.trim().isNotEmpty ?? false) ||
        (node.value?.trim().isNotEmpty ?? false)) {
      continue;
    }
    if (node.identifier?.trim().isNotEmpty ?? false) {
      suppressedIndexes.add(node.index);
    }
  }
}

// -- Scroll indicator (scroll.ts) --

void _collectIosScrollIndicatorPresentation(
  List<RawSnapshotNode> nodes,
  SnapshotTreeRuleContext context,
) {
  final byIndex = <int, RawSnapshotNode>{for (final n in nodes) n.index: n};
  for (final node in nodes) {
    if (!_isIosScrollIndicatorNode(node)) continue;
    _collectIosScrollIndicatorNodePresentation(node, byIndex, context);
  }
}

bool _isIosScrollIndicatorNode(RawSnapshotNode node) {
  final label = node.label?.trim();
  return label != null && label.isNotEmpty && _isSystemScrollIndicatorLabel(label);
}

bool _isSystemScrollIndicatorLabel(String label) {
  final normalized = label.trim().toLowerCase();
  if (normalized.isEmpty) return false;
  return RegExp(r'^(vertical|horizontal)\s+scroll\s+bar(?:,?\s*\d+\s+pages?)?$')
      .hasMatch(normalized);
}

void _collectIosScrollIndicatorNodePresentation(
  RawSnapshotNode node,
  Map<int, RawSnapshotNode> byIndex,
  SnapshotTreeRuleContext context,
) {
  if (!isScrollableSnapshotType(node.type)) {
    context.suppressedIndexes.add(node.index);
  }

  final directions = _inferVerticalScrollIndicatorDirections(
    node.label?.trim() ?? '',
    node.value,
  );
  if (directions == null) return;

  final container = findNearestScrollableContainer(
    node,
    byIndex,
    includeSelf: true,
  );
  if (container == null) return;

  _applyScrollIndicatorReplacement(context, container, node, directions);
}

void _applyScrollIndicatorReplacement(
  SnapshotTreeRuleContext context,
  RawSnapshotNode container,
  RawSnapshotNode indicator,
  ({bool above, bool below}) directions,
) {
  mergeReplacement(
    context.replacements,
    container,
    rect: _deriveScrollableViewportRect(container.rect, indicator.rect) ?? container.rect,
    hiddenContentAbove: _mergeHiddenContentFlag(container.hiddenContentAbove, directions.above),
    hiddenContentBelow: _mergeHiddenContentFlag(container.hiddenContentBelow, directions.below),
  );
}

bool? _mergeHiddenContentFlag(bool? existing, bool inferred) =>
    (existing == true || inferred) ? true : null;

Rect? _deriveScrollableViewportRect(Rect? containerRect, Rect? indicatorRect) {
  if (containerRect == null || indicatorRect == null) return null;
  if (indicatorRect.height <= 0 || indicatorRect.height >= containerRect.height) return null;
  if (indicatorRect.y < containerRect.y ||
      indicatorRect.y > containerRect.y + containerRect.height) {
    return null;
  }
  return Rect(
    x: containerRect.x,
    y: indicatorRect.y,
    width: containerRect.width,
    height: (indicatorRect.height)
        .clamp(0.0, containerRect.y + containerRect.height - indicatorRect.y),
  );
}

({bool above, bool below})? _inferVerticalScrollIndicatorDirections(
  String label,
  String? value,
) {
  final normalizedLabel = label.trim().toLowerCase();
  if (!normalizedLabel.contains('vertical scroll bar')) return null;
  final scrollPercent = _parsePercentValue(value);
  if (scrollPercent == null) return null;
  if (scrollPercent <= 1) return (above: false, below: true);
  if (scrollPercent >= 99) return (above: true, below: false);
  return (above: true, below: true);
}

double? _parsePercentValue(String? value) {
  if (value == null || value.isEmpty) return null;
  final match = RegExp(r'^(\d{1,3})%$').firstMatch(value.trim());
  if (match == null) return null;
  return double.tryParse(match.group(1)!);
}

// -- Search toolbar suppression --

void _collectIosSearchToolbarSuppression(
  List<RawSnapshotNode> nodes,
  Set<int> suppressedIndexes,
) {
  for (var position = 0; position < nodes.length; position++) {
    final node = nodes[position];
    if (normalizeType(node.type ?? '') != 'searchfield') continue;

    if (node.label == 'Search') {
      _suppressSearchToolbarDescendants(nodes, position, null, suppressedIndexes);
      continue;
    }
    if (node.label != 'Toolbar') continue;

    final descendants = collectDescendants(nodes, position);
    final innerSearch = descendants.firstWhereOrNull(
      (c) => normalizeType(c.type ?? '') == 'searchfield' && c.label == 'Search',
    );
    if (innerSearch == null) continue;

    suppressedIndexes.add(node.index);
    _suppressToolbarAncestors(node, nodes, suppressedIndexes);
    _suppressSearchToolbarDescendants(nodes, position, innerSearch.index, suppressedIndexes);
  }
}

void _suppressSearchToolbarDescendants(
  List<RawSnapshotNode> nodes,
  int position,
  int? keptSearchIndex,
  Set<int> suppressedIndexes,
) {
  for (final descendant in collectDescendants(nodes, position)) {
    if (descendant.index == keptSearchIndex) continue;
    if (_shouldSuppressIosSearchToolbarDescendant(descendant)) {
      suppressedIndexes.add(descendant.index);
    }
  }
}

void _suppressToolbarAncestors(
  RawSnapshotNode node,
  List<RawSnapshotNode> nodes,
  Set<int> suppressedIndexes,
) {
  final byIndex = <int, RawSnapshotNode>{for (final n in nodes) n.index: n};
  var current = node;
  while (current.parentIndex != null) {
    final parent = byIndex[current.parentIndex];
    if (parent == null || parent.label != 'Toolbar') return;
    suppressedIndexes.add(parent.index);
    current = parent;
  }
}

bool _shouldSuppressIosSearchToolbarDescendant(RawSnapshotNode node) {
  final type = normalizeType(node.type ?? '');
  if (type == 'button') return false;
  if (type == 'image') return true;
  return node.label == 'Search';
}

// -- Action wrapper suppression --

void _collectIosActionWrapperSuppression(
  List<RawSnapshotNode> nodes,
  SnapshotTreeRuleContext context,
) {
  _forEachOtherNodeWithLabel(nodes, (node, nodeLabel, position) {
    final semanticDescendant = collectDescendants(nodes, position).firstWhereOrNull(
      (descendant) =>
          isSemanticActionNode(descendant) &&
          descendant.label?.trim() == nodeLabel &&
          (areRectsApproximatelyEqual(descendant.rect, node.rect) ||
              _isIosBackdropDismissWrapper(node, descendant)),
    );
    if (semanticDescendant != null) {
      context.suppressedIndexes.add(node.index);
    }
  });
}

bool _isIosBackdropDismissWrapper(RawSnapshotNode node, RawSnapshotNode descendant) {
  if (descendant.label?.trim() != node.label?.trim()) return false;
  final descendantType = normalizeType(descendant.type ?? '');
  return _isNamedButtonBackdrop(node, descendantType) ||
      descendantType == 'textfield' ||
      _isFullscreenActionLabelWrapper(node, descendantType, descendant);
}

bool _isNamedButtonBackdrop(RawSnapshotNode node, String descendantType) {
  final label = node.label?.trim();
  return descendantType == 'button' && (label == 'Dismiss' || label == 'Back');
}

bool _isFullscreenActionLabelWrapper(
  RawSnapshotNode node,
  String descendantType,
  RawSnapshotNode descendant,
) {
  if (descendantType != 'button') return false;
  if (node.rect == null || descendant.rect == null) return false;
  return node.rect!.x == 0 &&
      node.rect!.y == 0 &&
      node.rect!.width >= 300 &&
      node.rect!.height >= 600 &&
      descendant.rect!.width < node.rect!.width;
}

// -- React Native overlay wrapper suppression --

void _collectIosReactNativeOverlayWrapperSuppression(
  List<RawSnapshotNode> nodes,
  Set<int> suppressedIndexes,
) {
  _forEachOtherNodeWithLabel(nodes, (node, nodeLabel, position) {
    if (!_isReactNativeCollapsedWarningLabel(nodeLabel) ||
        !_isFullScreenOverlayRect(node.rect)) {
      return;
    }
    final hasVisibleBannerDescendant = collectDescendants(nodes, position).any(
      (descendant) =>
          descendant.label?.trim() == nodeLabel &&
          _isReactNativeCollapsedWarningBanner(descendant),
    );
    if (hasVisibleBannerDescendant) {
      suppressedIndexes.add(node.index);
    }
  });
}

bool _isFullScreenOverlayRect(Rect? rect) {
  if (rect == null) return false;
  return rect.x <= 1 && rect.y <= 1 && rect.width >= 300 && rect.height >= 600;
}

bool _isReactNativeCollapsedWarningBanner(RawSnapshotNode node) {
  if (node.rect == null) return false;
  return node.rect!.width >= 120 &&
      node.rect!.height >= 36 &&
      node.rect!.height <= 180;
}

bool _isReactNativeCollapsedWarningLabel(String rawLabel) {
  final label = rawLabel.trim().toLowerCase();
  if (label.isEmpty) return false;
  return label.contains('open debugger to view warnings') ||
      RegExp(r'^!,\s+').hasMatch(label) ||
      RegExp(r'^(warn|warning|error):\s+').hasMatch(label) ||
      RegExp(r'\b(?:possible\s+)?unhandled (?:promise )?rejection\b').hasMatch(label) ||
      label.contains('getsnapshot should be cached to avoid an infinite loop') ||
      label.contains('unique "key" prop') ||
      label.contains("unique 'key' prop") ||
      label.contains('virtualizedlists should never be nested') ||
      label.contains('failed prop type');
}

// -- Repeated static suppression --

void _collectIosRepeatedStaticSuppression(
  List<RawSnapshotNode> nodes,
  Set<int> suppressedIndexes,
) {
  for (var position = 0; position < nodes.length; position++) {
    final node = nodes[position];
    final nodeLabel = node.label?.trim();
    if (suppressedIndexes.contains(node.index) || nodeLabel == null || nodeLabel.isEmpty) {
      continue;
    }
    _collectRepeatedStaticSuppressionForNode(
      nodes,
      position,
      node,
      nodeLabel,
      suppressedIndexes,
    );
  }
}

void _collectRepeatedStaticSuppressionForNode(
  List<RawSnapshotNode> nodes,
  int position,
  RawSnapshotNode node,
  String nodeLabel,
  Set<int> suppressedIndexes,
) {
  final descendants = collectDescendants(nodes, position);
  final type = normalizeType(node.type ?? '');

  if (type == 'statictext' || type == 'link') {
    _suppressRepeatedStaticDescendants(descendants, nodeLabel, suppressedIndexes);
    return;
  }
  if (type != 'other') return;

  if (_hasEquivalentSemanticDescendant(descendants, nodeLabel)) {
    suppressedIndexes.add(node.index);
    return;
  }
  _suppressRepeatedStaticDescendants(descendants, nodeLabel, suppressedIndexes);
}

bool _hasEquivalentSemanticDescendant(
  List<RawSnapshotNode> descendants,
  String nodeLabel,
) {
  return descendants.any((descendant) {
    final type = normalizeType(descendant.type ?? '');
    return (type == 'link' ||
            type == 'searchfield' ||
            isScrollableSnapshotType(descendant.type)) &&
        descendant.label?.trim() == nodeLabel;
  });
}

void _suppressRepeatedStaticDescendants(
  List<RawSnapshotNode> descendants,
  String label,
  Set<int> suppressedIndexes,
) {
  for (final descendant in descendants) {
    if (isRepeatedStaticNode(descendant, label)) {
      suppressedIndexes.add(descendant.index);
    }
  }
}

// ---------------------------------------------------------------------------
// Rule 2 – Implicit scrollable actions (actions.ts)
// ---------------------------------------------------------------------------

void _collectIosImplicitScrollableActions(
  List<RawSnapshotNode> nodes,
  SnapshotTreeRuleContext context,
) {
  final byIndex = <int, RawSnapshotNode>{for (final n in nodes) n.index: n};
  final viewport = findLargestViewportRect(byIndex.values);
  for (final node in nodes) {
    if (!_isImplicitScrollableAction(node, byIndex, viewport)) continue;
    mergeReplacement(context.replacements, node, type: 'Cell');
  }
}

bool _isImplicitScrollableAction(
  RawSnapshotNode node,
  Map<int, RawSnapshotNode> byIndex,
  Rect? viewport,
) {
  if (normalizeType(node.type ?? '') != 'other') return false;
  if (node.enabled == false || node.rect == null) return false;
  if (!_isMeaningfulImplicitActionLabel(node.label)) return false;
  if (findNearestAncestor(node, byIndex, _isImplicitActionScrollAncestor) == null) return false;
  if (!_isRowSizedImplicitAction(node)) return false;
  if (isMostlyViewportSizedRect(node.rect, viewport)) return false;
  return true;
}

bool _isRowSizedImplicitAction(RawSnapshotNode node) {
  if (node.rect == null) return false;
  return node.rect!.height >= 44 &&
      node.rect!.height <= 160 &&
      node.rect!.width >= 120;
}

bool _isImplicitActionScrollAncestor(RawSnapshotNode node) {
  final type = normalizeType(node.type ?? '');
  return type == 'scrollview' || type == 'scrollarea';
}

bool _isMeaningfulImplicitActionLabel(String? label) {
  final trimmed = label?.trim();
  if (trimmed == null || trimmed.isEmpty) return false;
  if (RegExp(r'^(toolbar|window|application)$', caseSensitive: false).hasMatch(trimmed)) {
    return false;
  }
  if (trimmed.startsWith('!,')) return false;
  if (RegExp(r'debugger|fast refresh', caseSensitive: false).hasMatch(trimmed)) return false;
  return true;
}

// ---------------------------------------------------------------------------
// Rule 3 – Row presentation (rows.ts)
// ---------------------------------------------------------------------------

void _collectIosRowPresentation(
  List<RawSnapshotNode> nodes,
  SnapshotTreeRuleContext context,
) {
  for (var position = 0; position < nodes.length; position++) {
    final row = nodes[position];
    final rowLabel = row.label?.trim();
    if (row.rect == null || rowLabel == null || rowLabel.isEmpty) continue;
    _collectIosRowPresentationForNode(nodes, position, row, rowLabel, context);
  }
}

void _collectIosRowPresentationForNode(
  List<RawSnapshotNode> nodes,
  int position,
  RawSnapshotNode row,
  String rowLabel,
  SnapshotTreeRuleContext context,
) {
  final descendants = collectDescendants(nodes, position);
  final rowType = normalizeType(row.type ?? '');

  if (rowType == 'button') {
    _suppressRepeatedRowDescendants(descendants, rowLabel, context.suppressedIndexes, row);
    return;
  }
  if (rowType != 'cell') return;

  if (_collectSwitchRowPresentation(descendants, row, rowLabel, context)) return;
  _collectButtonRowPresentation(descendants, row, rowLabel, context);
}

bool _collectSwitchRowPresentation(
  List<RawSnapshotNode> descendants,
  RawSnapshotNode row,
  String rowLabel,
  SnapshotTreeRuleContext context,
) {
  final switchControl = descendants.firstWhereOrNull(
    (c) => _isIosRowSwitchCandidate(c, row, rowLabel),
  );
  if (switchControl == null) return false;

  final rowButton = descendants.firstWhereOrNull(
    (c) => _isIosRowButtonCandidate(c, row, rowLabel),
  );
  final promotedIdentifier =
      switchControl.identifier != null && switchControl.identifier!.isNotEmpty
          ? null
          : (rowButton?.identifier?.isNotEmpty == true
              ? rowButton!.identifier
              : (row.identifier?.isNotEmpty == true ? row.identifier : null));

  if (promotedIdentifier != null) {
    mergeReplacement(context.replacements, switchControl, identifier: promotedIdentifier);
  }

  context.suppressedIndexes.add(row.index);
  _suppressSwitchRowDescendants(
    descendants,
    row,
    rowLabel,
    switchControl,
    context.suppressedIndexes,
  );
  return true;
}

void _collectButtonRowPresentation(
  List<RawSnapshotNode> descendants,
  RawSnapshotNode row,
  String rowLabel,
  SnapshotTreeRuleContext context,
) {
  final rowButton = descendants.firstWhereOrNull(
    (c) => _isIosRowButtonCandidate(c, row, rowLabel),
  );

  if (rowButton == null) {
    if (descendants.any(isDisabledChevronButton)) {
      _suppressRepeatedRowDescendants(descendants, rowLabel, context.suppressedIndexes, row);
    }
    return;
  }

  final rowIdentifier = row.identifier?.trim();
  final buttonIdentifier = rowButton.identifier?.trim();
  if ((rowIdentifier == null || rowIdentifier.isEmpty) &&
      buttonIdentifier != null &&
      buttonIdentifier.isNotEmpty) {
    mergeReplacement(context.replacements, row, identifier: buttonIdentifier);
  }

  context.suppressedIndexes.add(rowButton.index);
  _suppressRepeatedRowDescendants(
    descendants.where((d) => d.index != rowButton.index).toList(),
    rowLabel,
    context.suppressedIndexes,
    row,
  );
}

void _suppressSwitchRowDescendants(
  List<RawSnapshotNode> descendants,
  RawSnapshotNode row,
  String rowLabel,
  RawSnapshotNode switchControl,
  Set<int> suppressedIndexes,
) {
  for (final descendant in descendants) {
    if (descendant.index == switchControl.index) continue;
    if (_isIosRowButtonCandidate(descendant, row, rowLabel) ||
        _isEmptyRowButtonWrapper(descendant, row) ||
        _isIosSwitchValueDescendant(descendant, switchControl) ||
        shouldSuppressRepeatedTextDescendant(descendant, rowLabel)) {
      suppressedIndexes.add(descendant.index);
    }
  }
}

void _suppressRepeatedRowDescendants(
  List<RawSnapshotNode> descendants,
  String rowLabel,
  Set<int> suppressedIndexes,
  RawSnapshotNode? row,
) {
  for (final descendant in descendants) {
    if (shouldSuppressRepeatedTextDescendant(descendant, rowLabel) ||
        (row != null && _isEmptyRowButtonWrapper(descendant, row))) {
      suppressedIndexes.add(descendant.index);
    }
  }
}

bool _isIosRowButtonCandidate(
  RawSnapshotNode candidate,
  RawSnapshotNode row,
  String rowLabel,
) {
  if (normalizeType(candidate.type ?? '') != 'button') return false;
  final rowIdentifier = row.identifier?.trim();
  final candidateIdentifier = candidate.identifier?.trim();
  if (rowIdentifier != null &&
      rowIdentifier.isNotEmpty &&
      candidateIdentifier != null &&
      candidateIdentifier.isNotEmpty &&
      rowIdentifier == candidateIdentifier) {
    return true;
  }
  final candidateLabel = candidate.label?.trim();
  return candidateLabel == rowLabel && areRectsApproximatelyEqual(candidate.rect, row.rect);
}

bool _isEmptyRowButtonWrapper(RawSnapshotNode node, RawSnapshotNode row) {
  return normalizeType(node.type ?? '') == 'button' &&
      (node.label?.trim().isEmpty ?? true) &&
      (node.value?.trim().isEmpty ?? true) &&
      areRectsApproximatelyEqual(node.rect, row.rect);
}

bool _isIosRowSwitchCandidate(
  RawSnapshotNode candidate,
  RawSnapshotNode row,
  String rowLabel,
) {
  if (normalizeType(candidate.type ?? '') != 'switch') return false;
  final rowIdentifier = row.identifier?.trim();
  final candidateIdentifier = candidate.identifier?.trim();
  if (rowIdentifier != null &&
      rowIdentifier.isNotEmpty &&
      candidateIdentifier != null &&
      candidateIdentifier.isNotEmpty &&
      rowIdentifier == candidateIdentifier) {
    return true;
  }
  return candidate.label?.trim() == rowLabel;
}

bool _isIosSwitchValueDescendant(RawSnapshotNode node, RawSnapshotNode switchControl) {
  if (normalizeType(node.type ?? '') != 'switch') return false;
  if (node.index == switchControl.index) return false;
  final label = node.label?.trim();
  return label == switchControl.value?.trim() || label == '0' || label == '1';
}

// ---------------------------------------------------------------------------
// Internal helpers
// ---------------------------------------------------------------------------

void _forEachOtherNodeWithLabel(
  List<RawSnapshotNode> nodes,
  void Function(RawSnapshotNode node, String label, int position) visitor,
) {
  for (var position = 0; position < nodes.length; position++) {
    final node = nodes[position];
    final label = node.label?.trim();
    if (label != null && label.isNotEmpty && normalizeType(node.type ?? '') == 'other') {
      visitor(node, label, position);
    }
  }
}

extension on List<RawSnapshotNode> {
  RawSnapshotNode? firstWhereOrNull(bool Function(RawSnapshotNode) test) {
    for (final item in this) {
      if (test(item)) return item;
    }
    return null;
  }
}
