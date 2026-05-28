// Port of agent-device/src/utils/scroll-edge-state.ts
library;

import '../snapshot/snapshot.dart';
import '../snapshot/tree.dart';
import '../utils/errors.dart';
import '../utils/mobile_snapshot_semantics.dart';
import '../utils/scrollable.dart';

/// Edge of a scrollable container: top or bottom.
typedef ScrollEdge = String; // 'top' | 'bottom'

/// State of a scrollable edge at a point in time.
class ScrollEdgeState {
  final bool canScroll;
  final bool emptySnapshot;
  final String signature;
  final String? scope;

  const ScrollEdgeState({
    required this.canScroll,
    required this.emptySnapshot,
    required this.signature,
    this.scope,
  });
}

/// Hint about where a scroll-to-edge should be targeted.
class ScrollEdgeTarget {
  final Point? point;
  final int? nodeIndex;

  const ScrollEdgeTarget({this.point, this.nodeIndex});

  static const ScrollEdgeTarget empty = ScrollEdgeTarget();
}

const int _scrollEdgePassLimit = 40;
const double _scrollSignatureRectPrecision = 1;

/// Analyze the current edge state for a flat snapshot node list.
ScrollEdgeState analyzeScrollEdgeState(
  List<SnapshotNode> inputNodes,
  String edge, {
  ScrollEdgeTarget target = ScrollEdgeTarget.empty,
}) {
  final nodes = _ensureSnapshotNodes(inputNodes);
  if (nodes.isEmpty) {
    return const ScrollEdgeState(
      canScroll: false,
      emptySnapshot: true,
      signature: '',
    );
  }

  final hiddenHints = deriveMobileSnapshotHiddenContentHints(nodes);
  final container = _selectScrollContainer(nodes, hiddenHints, edge, target);
  final signatureNodes =
      container != null
          ? _collectSubtreeNodes(nodes, container.index)
          : nodes;
  final signature = _buildScrollStateSignature(signatureNodes);

  if (container == null) {
    return ScrollEdgeState(
      canScroll: false,
      emptySnapshot: false,
      signature: signature,
    );
  }

  final canScroll = _hasHiddenContentAtEdge(
    container,
    hiddenHints[container.index],
    edge,
  );
  return ScrollEdgeState(
    canScroll: canScroll,
    emptySnapshot: false,
    signature: signature,
    scope: _buildScrollContainerScope(container),
  );
}

/// Capture the scroll edge state using [captureNodes] to obtain the snapshot.
///
/// Retries without scope when [scope] is set but the snapshot is empty.
Future<ScrollEdgeState> captureScrollEdgeState({
  required String edge,
  ScrollEdgeTarget target = ScrollEdgeTarget.empty,
  String? scope,
  required Future<List<SnapshotNode>> Function(String? scope) captureNodes,
}) async {
  try {
    final nodes = await captureNodes(scope);
    final state = analyzeScrollEdgeState(nodes, edge, target: target);
    if (scope != null && state.emptySnapshot) {
      return await captureScrollEdgeState(
        edge: edge,
        target: target,
        captureNodes: captureNodes,
      );
    }
    return state;
  } catch (error) {
    throw _buildScrollEdgeVerificationError(edge, scope, error);
  }
}

/// Run repeated scroll passes until the edge is reached or the limit is hit.
///
/// Returns the number of passes taken and the final scroll result.
Future<({int passes, T? result})> runScrollEdgePasses<T>({
  required String edge,
  required Future<ScrollEdgeState> Function(String? scope) captureState,
  required Future<T> Function() scroll,
}) async {
  var state = await captureState(null);
  if (state.scope != null) {
    state = await captureState(state.scope);
  }

  var passes = 0;
  T? result;
  while (state.canScroll) {
    if (passes >= _scrollEdgePassLimit) {
      throw AppError(
        AppErrorCodes.commandFailed,
        'scroll $edge reached the safety limit before the snapshot showed the edge',
        details: {
          'hint':
              'The scoped scroll container still reports hidden content. '
              'Use a smaller manual scroll + snapshot loop to inspect the current state.',
        },
      );
    }

    result = await scroll();
    passes += 1;
    state = await captureState(state.scope);
  }

  return (passes: passes, result: result);
}

/// Format the result message for a scroll command (edge or plain).
String formatScrollEdgeMessage(
  String direction,
  String? edge,
  int passes,
  double? amount,
  int? pixels,
) {
  if (edge != null && passes == 0) {
    return 'Already at $edge; no hidden content '
        '${edge == 'bottom' ? 'below' : 'above'} detected';
  }
  if (edge != null) return 'Scrolled to $edge with $passes $direction passes';
  if (pixels != null) return 'Scrolled $direction by ${pixels}px';
  if (amount != null) return 'Scrolled $direction by $amount';
  return 'Scrolled $direction';
}

// ---------------------------------------------------------------------------
// Internal helpers
// ---------------------------------------------------------------------------

AppError _buildScrollEdgeVerificationError(
  String edge,
  String? scope,
  Object cause,
) {
  if (scope != null) {
    return AppError(
      AppErrorCodes.commandFailed,
      'Failed to verify scroll $edge state for scoped container',
      details: {
        'scope': scope,
        'hint':
            'scroll $edge could not verify the scoped scroll container. '
            'Run snapshot -i -c for the current screen and retry with a visible scroll target.',
      },
      cause: cause,
    );
  }
  return AppError(
    AppErrorCodes.commandFailed,
    'Failed to verify scroll $edge state',
    details: {
      'hint':
          'scroll $edge needs a snapshot showing hidden content '
          '${edge == 'bottom' ? 'below' : 'above'} before it will move.',
    },
    cause: cause,
  );
}

/// Ensure all nodes have a non-empty ref. Nodes that already have refs are
/// returned unchanged; any without get a synthetic `e<N>` ref assigned.
List<SnapshotNode> _ensureSnapshotNodes(List<SnapshotNode> nodes) {
  return nodes.asMap().entries.map((entry) {
    final i = entry.key;
    final node = entry.value;
    if (node.ref.isNotEmpty) return node;
    return SnapshotNode(
      index: node.index,
      ref: 'e${i + 1}',
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
      parentIndex: node.parentIndex,
      pid: node.pid,
      bundleId: node.bundleId,
      appName: node.appName,
      windowTitle: node.windowTitle,
      surface: node.surface,
      hiddenContentAbove: node.hiddenContentAbove,
      hiddenContentBelow: node.hiddenContentBelow,
      presentationHints: node.presentationHints,
    );
  }).toList();
}

SnapshotNode? _selectScrollContainer(
  List<SnapshotNode> nodes,
  Map<int, HiddenContentHint> hiddenHints,
  String edge,
  ScrollEdgeTarget target,
) {
  final byIndex = buildSnapshotNodeMap(nodes);
  final scrollables =
      nodes
          .where(
            (node) =>
                isScrollableNodeLike(
                  type: node.type,
                  role: node.role,
                  subrole: node.subrole,
                ) &&
                _isUsableRect(node.rect),
          )
          .toList();

  if (scrollables.isEmpty) return null;

  final targetAncestor = _findNearestScrollableAncestor(
    target.nodeIndex,
    byIndex,
  );
  if (targetAncestor != null) return targetAncestor;

  final targetPoint = target.point;
  if (targetPoint != null) {
    final containing =
        scrollables
            .where(
              (node) => node.rect != null && _containsPoint(node.rect!, targetPoint),
            )
            .toList()
          ..sort(_compareSpecificScrollContainer);
    if (containing.isNotEmpty) {
      final withHiddenEdge = containing.firstWhere(
        (node) => _hasHiddenContentAtEdge(node, hiddenHints[node.index], edge),
        orElse: () => containing.first,
      );
      return withHiddenEdge;
    }
  }

  final withHiddenEdge =
      scrollables
          .where(
            (node) => _hasHiddenContentAtEdge(node, hiddenHints[node.index], edge),
          )
          .toList()
        ..sort(_compareBroadScrollContainer);
  if (withHiddenEdge.isNotEmpty) return withHiddenEdge.first;

  // Fall back to visible scrollables, broadest first.
  final visibleScrollables =
      scrollables
          .where((node) => isNodeVisibleInEffectiveViewport(node, nodes, byIndex))
          .toList()
        ..sort(_compareBroadScrollContainer);
  if (visibleScrollables.isNotEmpty) return visibleScrollables.first;

  final fallback = [...scrollables]..sort(_compareBroadScrollContainer);
  return fallback.isEmpty ? null : fallback.first;
}

SnapshotNode? _findNearestScrollableAncestor(
  int? nodeIndex,
  Map<int, SnapshotNode> byIndex,
) {
  if (nodeIndex == null) return null;
  SnapshotNode? node = byIndex[nodeIndex];
  while (node != null) {
    if (isScrollableNodeLike(
          type: node.type,
          role: node.role,
          subrole: node.subrole,
        ) &&
        _isUsableRect(node.rect)) {
      return node;
    }
    final parentIndex = node.parentIndex;
    node = parentIndex != null ? byIndex[parentIndex] : null;
  }
  return null;
}

List<SnapshotNode> _collectSubtreeNodes(
  List<SnapshotNode> nodes,
  int rootIndex,
) {
  final byIndex = buildSnapshotNodeMap(nodes);
  return nodes
      .where(
        (node) => node.index == rootIndex || _hasAncestor(node, rootIndex, byIndex),
      )
      .toList();
}

bool _hasAncestor(
  SnapshotNode node,
  int ancestorIndex,
  Map<int, SnapshotNode> byIndex,
) {
  int? currentParentIndex = node.parentIndex;
  while (currentParentIndex != null) {
    final current = byIndex[currentParentIndex];
    if (current == null) break;
    if (current.index == ancestorIndex) return true;
    currentParentIndex = current.parentIndex;
  }
  return false;
}

bool _hasHiddenContentAtEdge(
  SnapshotNode node,
  HiddenContentHint? hint,
  String edge,
) {
  if (edge == 'bottom') {
    return node.hiddenContentBelow == true || hint?.hiddenContentBelow == true;
  }
  return node.hiddenContentAbove == true || hint?.hiddenContentAbove == true;
}

String? _buildScrollContainerScope(SnapshotNode node) {
  final candidates = [node.identifier, node.label, node.value];
  for (final value in candidates) {
    if (value != null && _isUsefulScope(value)) return value;
  }
  return null;
}

bool _isUsefulScope(String value) {
  final trimmed = value.trim();
  if (trimmed.isEmpty || trimmed.length > 80) return false;
  if (RegExp(r'^(true|false)$', caseSensitive: false).hasMatch(trimmed)) {
    return false;
  }
  if (RegExp(r'^\d+$').hasMatch(trimmed)) return false;
  if (RegExp(r'^\d+%$').hasMatch(trimmed)) return false;
  return true;
}

String _buildScrollStateSignature(List<SnapshotNode> nodes) {
  final buffer = StringBuffer();
  for (var i = 0; i < nodes.length; i++) {
    final node = nodes[i];
    final rectSignature = node.rect != null
        ? [
            node.rect!.x,
            node.rect!.y,
            node.rect!.width,
            node.rect!.height,
          ]
            .map((v) => v.toStringAsFixed(_scrollSignatureRectPrecision.toInt()))
            .join(',')
        : '';
    if (i > 0) buffer.writeln();
    buffer.write(
      '${node.index}|'
      '${node.parentIndex ?? ''}|'
      '${node.type ?? ''}|'
      '${node.label ?? ''}|'
      '${node.value ?? ''}|'
      '$rectSignature',
    );
  }
  return buffer.toString();
}

int _compareSpecificScrollContainer(SnapshotNode a, SnapshotNode b) {
  return _rectArea(a.rect).compareTo(_rectArea(b.rect));
}

int _compareBroadScrollContainer(SnapshotNode a, SnapshotNode b) {
  return _rectArea(b.rect).compareTo(_rectArea(a.rect));
}

double _rectArea(Rect? rect) {
  return rect != null ? rect.width * rect.height : 0.0;
}

bool _containsPoint(Rect rect, Point point) {
  return point.x >= rect.x &&
      point.x <= rect.x + rect.width &&
      point.y >= rect.y &&
      point.y <= rect.y + rect.height;
}

bool _isUsableRect(Rect? rect) {
  return rect != null && rect.width > 0 && rect.height > 0;
}
