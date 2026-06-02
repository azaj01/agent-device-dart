// Port of agent-device/src/platforms/android/ui-hierarchy.ts

import 'dart:math' as math;

import '../../snapshot/snapshot.dart';
import '../../utils/scrollable.dart';

/// Analysis results from Android UI hierarchy parsing.
class AndroidSnapshotAnalysis {
  final int rawNodeCount;
  final int maxDepth;

  const AndroidSnapshotAnalysis({
    required this.rawNodeCount,
    required this.maxDepth,
  });
}

/// Flat metadata for one UIAutomator XML `<node>` element.
///
/// Used by [androidUiNodes] to iterate nodes without building the full tree,
/// e.g. for fill verification.
class AndroidUiNodeMetadata {
  final String? text;
  final String? desc;
  final String? resourceId;
  final String? packageName;
  final String? className;
  final String? bounds;
  final Rect? rect;
  final bool? clickable;
  final bool? enabled;
  final bool? focusable;
  final bool? focused;
  final bool? password;
  final bool? visibleToUser;
  final int? drawingOrder;

  const AndroidUiNodeMetadata({
    required this.text,
    required this.desc,
    required this.resourceId,
    required this.packageName,
    required this.className,
    required this.bounds,
    this.rect,
    this.clickable,
    this.enabled,
    this.focusable,
    this.focused,
    this.password,
    this.visibleToUser,
    this.drawingOrder,
  });
}

/// Iterate over all `<node>` elements in [xml], yielding metadata for each.
///
/// Provides a flat iteration of UIAutomator XML nodes without building the
/// full hierarchy tree — suitable for fill verification and point-lookup uses.
Iterable<AndroidUiNodeMetadata> androidUiNodes(String xml) sync* {
  final nodeRegex = RegExp(r'<node\b[^>]*>');
  for (final match in nodeRegex.allMatches(xml)) {
    yield _readAndroidUiNodeMetadata(match[0]!);
  }
}

AndroidUiNodeMetadata _readAndroidUiNodeMetadata(String node) {
  final attrs = _parseXmlNodeAttributes(node);
  String? getAttr(String name) => attrs[name];
  bool? boolAttr(String name) {
    final raw = getAttr(name);
    if (raw == null) return null;
    return raw == 'true';
  }

  int? intAttr(String name) {
    final raw = getAttr(name);
    if (raw == null) return null;
    return int.tryParse(raw.trim());
  }

  final bounds = getAttr('bounds');
  final rect = _parseBounds(bounds);
  return AndroidUiNodeMetadata(
    text: getAttr('text'),
    desc: getAttr('content-desc'),
    resourceId: getAttr('resource-id'),
    packageName: getAttr('package'),
    className: getAttr('class'),
    bounds: bounds,
    rect: rect,
    clickable: boolAttr('clickable'),
    enabled: boolAttr('enabled'),
    focusable: boolAttr('focusable'),
    focused: boolAttr('focused'),
    password: boolAttr('password'),
    visibleToUser: boolAttr('visible-to-user'),
    drawingOrder: intAttr('drawing-order'),
  );
}

/// Android-specific node attributes extracted from UIAutomator XML.
class AndroidUiHierarchy {
  final String? type;
  final String? label;
  final String? value;
  final String? identifier;
  final String? packageName;
  final Rect? rect;
  final bool? enabled;
  final bool? hittable;

  /// Whether UIAutomator reports the node as visible to the user
  /// (`visible-to-user`). Null when the attribute is absent.
  final bool? visibleToUser;

  /// Sibling draw order (`drawing-order`); higher draws on top. Null when
  /// absent. Used to drop surfaces covered by a higher-order sibling.
  final int? drawingOrder;
  final int depth;
  final int? parentIndex;
  final bool? hiddenContentAbove;
  final bool? hiddenContentBelow;
  final List<AndroidUiHierarchy> children;

  const AndroidUiHierarchy({
    required this.type,
    required this.label,
    required this.value,
    required this.identifier,
    required this.packageName,
    required this.rect,
    required this.enabled,
    required this.hittable,
    required this.depth,
    required this.parentIndex,
    required this.hiddenContentAbove,
    required this.hiddenContentBelow,
    required this.children,
    this.visibleToUser,
    this.drawingOrder,
  });
}

/// Built snapshot including both raw nodes and source hierarchy.
class AndroidBuiltSnapshot {
  final List<RawSnapshotNode> nodes;
  final List<AndroidUiHierarchy> sourceNodes;
  final bool? truncated;
  final AndroidSnapshotAnalysis analysis;

  const AndroidBuiltSnapshot({
    required this.nodes,
    required this.sourceNodes,
    required this.truncated,
    required this.analysis,
  });
}

/// Find the center coordinates of the first node whose text or description
/// contains [query] (case-insensitive).
///
/// Returns null if no matching node is found.
({int x, int y})? findBounds(String xml, String query) {
  final q = query.toLowerCase();
  for (final node in androidUiNodes(xml)) {
    final textVal = (node.text ?? '').toLowerCase();
    final descVal = (node.desc ?? '').toLowerCase();
    if (textVal.contains(q) || descVal.contains(q)) {
      final rect = node.rect;
      if (rect != null) {
        return (
          x: (rect.x + rect.width / 2).floor(),
          y: (rect.y + rect.height / 2).floor(),
        );
      }
      return (x: 0, y: 0);
    }
  }
  return null;
}

/// Parse UIAutomator XML dump into snapshot tree and nodes.
///
/// Applies filtering rules based on [options] and returns raw nodes
/// with optional truncation indicator.
({
  List<RawSnapshotNode> nodes,
  bool? truncated,
  AndroidSnapshotAnalysis analysis,
})
parseUiHierarchy(String xml, int maxNodes, SnapshotOptions options) {
  final tree = parseUiHierarchyTree(xml);
  final built = buildUiHierarchySnapshot(tree, maxNodes, options);
  return (
    nodes: built.nodes,
    truncated: built.truncated,
    analysis: built.analysis,
  );
}

/// Build snapshot from parsed hierarchy tree.
///
/// Walks the tree applying filtering rules, memoizing interactive
/// descendant information, and respecting depth limits and node quotas.
AndroidBuiltSnapshot buildUiHierarchySnapshot(
  AndroidUiHierarchy tree,
  int maxNodes,
  SnapshotOptions options,
) {
  final analysis = _analyzeAndroidTree(tree);
  final nodes = <RawSnapshotNode>[];
  final sourceNodes = <AndroidUiHierarchy>[];
  var truncated = false;

  final maxDepth = options.depth ?? double.infinity;
  final scopedRoot = options.scope != null
      ? _findScopeNode(tree, options.scope!)
      : null;
  final roots = scopedRoot != null ? [scopedRoot] : tree.children;

  final interactiveDescendantMemo = <AndroidUiHierarchy, bool>{};
  bool hasInteractiveDescendant(AndroidUiHierarchy node) {
    if (interactiveDescendantMemo.containsKey(node)) {
      return interactiveDescendantMemo[node]!;
    }
    for (final child in node.children) {
      if (child.hittable ?? false) {
        interactiveDescendantMemo[node] = true;
        return true;
      }
      if (hasInteractiveDescendant(child)) {
        interactiveDescendantMemo[node] = true;
        return true;
      }
    }
    interactiveDescendantMemo[node] = false;
    return false;
  }

  void walk(
    AndroidUiHierarchy node,
    int depth,
    int? parentIndex, {
    bool ancestorHittable = false,
    bool ancestorCollection = false,
  }) {
    if (nodes.length >= maxNodes) {
      truncated = true;
      return;
    }
    if (depth > maxDepth) return;

    final include = (options.raw ?? false)
        ? true
        : _shouldIncludeAndroidNode(
            node,
            options,
            ancestorHittable,
            hasInteractiveDescendant(node),
            ancestorCollection,
          );

    var currentIndex = parentIndex;
    if (include) {
      currentIndex = nodes.length;
      sourceNodes.add(node);
      nodes.add(
        RawSnapshotNode(
          index: currentIndex,
          type: node.type,
          label: node.label,
          value: node.value,
          identifier: node.identifier,
          bundleId: node.packageName,
          rect: node.rect,
          enabled: node.enabled,
          hittable: node.hittable,
          depth: depth,
          parentIndex: parentIndex,
          hiddenContentAbove: node.hiddenContentAbove,
          hiddenContentBelow: node.hiddenContentBelow,
        ),
      );
    }

    final nextAncestorHittable = ancestorHittable || (node.hittable ?? false);
    final nextAncestorCollection =
        ancestorCollection || _isCollectionContainerType(node.type);

    for (final child in node.children) {
      walk(
        child,
        depth + 1,
        currentIndex,
        ancestorHittable: nextAncestorHittable,
        ancestorCollection: nextAncestorCollection,
      );
      if (truncated) return;
    }
  }

  for (final root in roots) {
    walk(root, 0, null);
    if (truncated) break;
  }

  return AndroidBuiltSnapshot(
    nodes: nodes,
    sourceNodes: sourceNodes,
    truncated: truncated ? true : null,
    analysis: analysis,
  );
}

/// Extract node attributes from an XML node string.
///
/// Returns the same [AndroidUiNodeMetadata] record used internally.
/// Public alias so test code can call this directly.
AndroidUiNodeMetadata readNodeAttributes(String node) =>
    _readAndroidUiNodeMetadata(node);

/// Parse bounds string "[x1,y1][x2,y2]" into a [Rect].
///
/// Returns null if bounds string is invalid or empty.
Rect? parseBounds(String? bounds) => _parseBounds(bounds);

Rect? _parseBounds(String? bounds) {
  if (bounds == null || bounds.isEmpty) return null;
  final match = RegExp(
    r'\[(-?\d+),(-?\d+)\]\[(-?\d+),(-?\d+)\]',
  ).firstMatch(bounds);
  if (match == null) return null;

  final x1 = double.parse(match.group(1)!);
  final y1 = double.parse(match.group(2)!);
  final x2 = double.parse(match.group(3)!);
  final y2 = double.parse(match.group(4)!);

  return Rect(
    x: x1,
    y: y1,
    width: (x2 - x1).clamp(0, double.infinity),
    height: (y2 - y1).clamp(0, double.infinity),
  );
}

/// Parse UIAutomator XML dump into a tree structure.
///
/// Uses a simple stack-based parser to handle nested `<node>` elements.
/// Self-closing nodes do not push onto the stack.
AndroidUiHierarchy parseUiHierarchyTree(String xml) {
  // Not const: `children` is mutated as we parse, so a const empty list
  // would throw at runtime on the first `add`.
  // ignore: prefer_const_constructors
  final root = AndroidUiHierarchy(
    type: null,
    label: null,
    value: null,
    identifier: null,
    packageName: null,
    depth: -1,
    parentIndex: null,
    enabled: null,
    hittable: null,
    rect: null,
    hiddenContentAbove: null,
    hiddenContentBelow: null,
    children: <AndroidUiHierarchy>[],
  );

  final stack = [root];
  final tokenRegex = RegExp(r'<node\b[^>]*>|</node>');

  for (final match in tokenRegex.allMatches(xml)) {
    final token = match[0]!;

    if (token.startsWith('</node')) {
      if (stack.length > 1) {
        stack.removeLast();
      }
      continue;
    }

    final attrs = _readAndroidUiNodeMetadata(token);
    final parent = stack.last;
    final semanticText = _firstNonEmptyAndroidText(attrs.text, attrs.desc);

    final node = AndroidUiHierarchy(
      type: attrs.className,
      label: semanticText,
      value: semanticText,
      identifier: attrs.resourceId,
      packageName: attrs.packageName,
      rect: attrs.rect,
      enabled: attrs.enabled,
      hittable: attrs.clickable ?? attrs.focusable,
      visibleToUser: attrs.visibleToUser,
      drawingOrder: attrs.drawingOrder,
      depth: parent.depth + 1,
      parentIndex: null,
      hiddenContentAbove: null,
      hiddenContentBelow: null,
      children: [],
    );

    parent.children.add(node);

    if (!token.endsWith('/>')) {
      stack.add(node);
    }
  }

  // Raw Android snapshots are uncollapsed but still agent-visible. The helper
  // can expose aria-hidden / no-hide-descendants children, so prune nodes
  // Android marks not-visible-to-user. (Ported from upstream #675.)
  _pruneAndroidInvisibleSubtrees(root);
  // UiAutomation can expose covered surfaces (e.g. background React Navigation
  // screens) in the same accessibility window. If a higher drawing-order
  // sibling fully covers a node, agents should only see the foreground one.
  _pruneAndroidCoveredSubtrees(root, <AndroidUiHierarchy, bool>{});

  return root;
}

/// Remove subtrees Android marks `visible-to-user="false"`.
void _pruneAndroidInvisibleSubtrees(AndroidUiHierarchy node) {
  node.children.removeWhere((child) => child.visibleToUser == false);
  for (final child in node.children) {
    _pruneAndroidInvisibleSubtrees(child);
  }
}

/// Drop sibling subtrees fully covered (≥90% area) by a higher drawing-order
/// sibling that carries agent-visible content. Depth-first so nested overlaps
/// resolve before their parents are evaluated.
void _pruneAndroidCoveredSubtrees(
  AndroidUiHierarchy node,
  Map<AndroidUiHierarchy, bool> agentVisibleContentMemo,
) {
  for (final child in node.children) {
    _pruneAndroidCoveredSubtrees(child, agentVisibleContentMemo);
  }
  if (node.children.length < 2) return;
  final coveringCandidates = node.children
      .where((c) => _canCoverSibling(c, agentVisibleContentMemo))
      .toList();
  if (coveringCandidates.isEmpty) return;
  node.children.removeWhere(
    (child) => _isCoveredByHigherDrawingOrderSibling(child, coveringCandidates),
  );
}

bool _isCoveredByHigherDrawingOrderSibling(
  AndroidUiHierarchy node,
  List<AndroidUiHierarchy> coveringCandidates,
) {
  final rect = node.rect;
  final order = node.drawingOrder;
  if (node.visibleToUser == false || order == null || rect == null) {
    return false;
  }
  if (!(rect.width > 0 && rect.height > 0)) return false;
  for (final sibling in coveringCandidates) {
    final siblingOrder = sibling.drawingOrder;
    if (identical(sibling, node) ||
        siblingOrder == null ||
        siblingOrder <= order) {
      continue;
    }
    if (_rectCoverage(sibling.rect!, rect) >= 0.9) return true;
  }
  return false;
}

bool _canCoverSibling(
  AndroidUiHierarchy node,
  Map<AndroidUiHierarchy, bool> memo,
) {
  return node.visibleToUser != false &&
      node.drawingOrder != null &&
      _hasPositiveRect(node) &&
      _hasAgentVisibleContent(node, memo);
}

bool _hasAgentVisibleContent(
  AndroidUiHierarchy node,
  Map<AndroidUiHierarchy, bool> memo,
) {
  final cached = memo[node];
  if (cached != null) return cached;
  final result = _computeHasAgentVisibleContent(node, memo);
  memo[node] = result;
  return result;
}

bool _computeHasAgentVisibleContent(
  AndroidUiHierarchy node,
  Map<AndroidUiHierarchy, bool> memo,
) {
  if (node.visibleToUser == false) return false;
  if (node.hittable ?? false) return true;
  final label = node.label?.trim() ?? '';
  if (label.isNotEmpty && !_isGenericAndroidId(label)) return true;
  final identifier = node.identifier?.trim() ?? '';
  if (identifier.isNotEmpty && !_isGenericAndroidId(identifier)) return true;
  return node.children.any((child) => _hasAgentVisibleContent(child, memo));
}

bool _hasPositiveRect(AndroidUiHierarchy node) {
  final rect = node.rect;
  return rect != null && rect.width > 0 && rect.height > 0;
}

double _rectCoverage(Rect coveringRect, Rect targetRect) {
  final targetArea = targetRect.width * targetRect.height;
  if (targetArea <= 0) return 0;
  return _intersectionArea(coveringRect, targetRect) / targetArea;
}

double _intersectionArea(Rect left, Rect right) {
  final xOverlap = math.max(
    0.0,
    math.min(left.x + left.width, right.x + right.width) -
        math.max(left.x, right.x),
  );
  final yOverlap = math.max(
    0.0,
    math.min(left.y + left.height, right.y + right.height) -
        math.max(left.y, right.y),
  );
  return xOverlap * yOverlap;
}

/// Check if a node should be included in the snapshot.
///
/// Applies filtering based on snapshot options and node properties,
/// considering ancestry and descendant interactivity.
bool _shouldIncludeAndroidNode(
  AndroidUiHierarchy node,
  SnapshotOptions options,
  bool ancestorHittable,
  bool descendantHittable,
  bool ancestorCollection,
) {
  final type = _normalizeAndroidType(node.type);
  final hasText = (node.label?.trim().isNotEmpty) ?? false;
  final hasId = (node.identifier?.trim().isNotEmpty) ?? false;
  final hasMeaningfulText = hasText && !_isGenericAndroidId(node.label ?? '');
  final hasMeaningfulId = hasId && !_isGenericAndroidId(node.identifier ?? '');
  final isStructural = _isStructuralAndroidType(type);
  final isVisual = type == 'imageview' || type == 'imagebutton';

  if (options.interactiveOnly ?? false) {
    if (node.hittable ?? false) return true;
    if (isScrollableType(type) && descendantHittable) {
      return true;
    }
    final proxyCandidate = hasMeaningfulText || hasMeaningfulId;
    if (!proxyCandidate) return false;
    if (isVisual) return false;
    if (isStructural && !ancestorCollection) return false;
    return ancestorHittable || descendantHittable || ancestorCollection;
  }

  if (options.compact ?? false) {
    return hasMeaningfulText || hasMeaningfulId || (node.hittable ?? false);
  }

  if (isStructural || isVisual) {
    if (node.hittable ?? false) return true;
    if (hasMeaningfulText) return true;
    if (hasMeaningfulId) return true;
    return descendantHittable;
  }

  return true;
}

String? _firstNonEmptyAndroidText(String? text, String? desc) {
  final trimmedText = text?.trim();
  if (trimmedText != null && trimmedText.isNotEmpty) {
    return trimmedText;
  }
  final trimmedDesc = desc?.trim();
  if (trimmedDesc != null && trimmedDesc.isNotEmpty) {
    return trimmedDesc;
  }
  return null;
}

bool _isCollectionContainerType(String? type) {
  if (type == null) return false;
  final normalized = _normalizeAndroidType(type);
  return normalized.contains('recyclerview') ||
      normalized.contains('listview') ||
      normalized.contains('gridview');
}

String _normalizeAndroidType(String? type) {
  if (type == null) return '';
  return type.toLowerCase();
}

bool _isStructuralAndroidType(String type) {
  final short = type.split('.').last;
  return short.contains('layout') || short == 'viewgroup' || short == 'view';
}

bool _isGenericAndroidId(String value) {
  final trimmed = value.trim();
  if (trimmed.isEmpty) return false;
  return RegExp(r'^[\w.]+:id/[\w.-]+$', caseSensitive: false).hasMatch(trimmed);
}

AndroidUiHierarchy? _findScopeNode(AndroidUiHierarchy root, String scope) {
  final query = scope.toLowerCase();
  final queue = [...root.children];
  var head = 0;

  while (head < queue.length) {
    final node = queue[head++];
    final label = (node.label ?? '').toLowerCase();
    final value = (node.value ?? '').toLowerCase();
    final identifier = (node.identifier ?? '').toLowerCase();

    if (label.contains(query) ||
        value.contains(query) ||
        identifier.contains(query)) {
      return node;
    }
    queue.addAll(node.children);
  }

  return null;
}

AndroidSnapshotAnalysis _analyzeAndroidTree(AndroidUiHierarchy root) {
  var rawNodeCount = 0;
  var maxDepth = 0;
  final stack = [...root.children];

  while (stack.isNotEmpty) {
    final node = stack.removeLast();
    rawNodeCount += 1;
    maxDepth = maxDepth > node.depth ? maxDepth : node.depth;
    stack.addAll(node.children);
  }

  return AndroidSnapshotAnalysis(
    rawNodeCount: rawNodeCount,
    maxDepth: maxDepth,
  );
}

/// Extract attributes from an XML opening tag using regex.
///
/// Handles quoted attribute values, whitespace, and XML entity decoding
/// (`&amp;`, `&lt;`, `&gt;`, `&quot;`, `&apos;`, numeric `&#N;`/`&#xN;`).
/// Returns a map of attribute names to decoded values.
Map<String, String> _parseXmlNodeAttributes(String node) {
  final attrs = <String, String>{};
  final start = node.indexOf(' ');
  final end = node.lastIndexOf('>');

  if (start < 0 || end <= start) return attrs;

  final attrRegex = RegExp(r'''([^\s=/>]+)\s*=\s*(["'])([\s\S]*?)\2''');
  var cursor = start;

  while (cursor < end) {
    // Skip whitespace
    while (cursor < end) {
      final char = node[cursor];
      if (char != ' ' && char != '\n' && char != '\r' && char != '\t') {
        break;
      }
      cursor += 1;
    }

    if (cursor >= end) break;

    final char = node[cursor];
    if (char == '/' || char == '>') break;

    final match = attrRegex.matchAsPrefix(node, cursor);
    if (match == null) break;

    attrs[match.group(1)!] = _decodeXmlAttributeValue(match.group(3)!);
    cursor = match.end;
  }

  return attrs;
}

/// Decode XML character references and named entities in an attribute value.
///
/// Port of `decodeXmlAttributeValue` from `ui-hierarchy.ts`. Handles the
/// five predefined XML entities (`&amp;` `&lt;` `&gt;` `&quot;` `&apos;`)
/// and decimal / hex numeric references (`&#10;` `&#x0A;`). Any unrecognised
/// or malformed entity is passed through verbatim.
String _decodeXmlAttributeValue(String value) {
  final ampIdx = value.indexOf('&');
  if (ampIdx < 0) return value; // fast path: no entities

  final buf = StringBuffer();
  var cursor = 0;
  while (cursor < value.length) {
    final entityStart = value.indexOf('&', cursor);
    if (entityStart < 0) {
      buf.write(value.substring(cursor));
      break;
    }
    buf.write(value.substring(cursor, entityStart));
    final entityEnd = value.indexOf(';', entityStart + 1);
    if (entityEnd < 0) {
      buf.write(value.substring(entityStart));
      break;
    }
    final raw = value.substring(entityStart + 1, entityEnd);
    final decoded = _decodeXmlEntity(raw);
    if (decoded != null) {
      buf.write(decoded);
    } else {
      buf.write(value.substring(entityStart, entityEnd + 1));
    }
    cursor = entityEnd + 1;
  }
  return buf.toString();
}

String? _decodeXmlEntity(String entity) {
  switch (entity) {
    case 'amp':
      return '&';
    case 'lt':
      return '<';
    case 'gt':
      return '>';
    case 'quot':
      return '"';
    case 'apos':
      return "'";
    default:
      return _decodeNumericXmlEntity(entity);
  }
}

String? _decodeNumericXmlEntity(String entity) {
  if (!entity.startsWith('#')) return null;
  final int radix;
  final String digits;
  if (entity.length > 2 && entity[1].toLowerCase() == 'x') {
    radix = 16;
    digits = entity.substring(2);
  } else {
    radix = 10;
    digits = entity.substring(1);
  }
  if (digits.isEmpty) return null;
  final codePoint = int.tryParse(digits, radix: radix);
  if (codePoint == null) return null;
  try {
    return String.fromCharCode(codePoint);
  } catch (_) {
    return null;
  }
}
