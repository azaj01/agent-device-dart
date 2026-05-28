// Port of agent-device/src/daemon/wait-current-surface.ts
//
// Inspects the current UI surface after a wait timeout and attaches
// a compact summary of visible labels/buttons to the error details.
library;

import 'package:agent_device/src/backend/backend.dart';
import 'package:agent_device/src/snapshot/snapshot.dart';

/// Details about what was visible on the current surface at timeout.
class CurrentSurfaceDetails {
  final List<String> labels;
  final List<String>? buttons;

  const CurrentSurfaceDetails({required this.labels, this.buttons});

  Map<String, Object?> toJson() => <String, Object?>{
    'labels': labels,
    if (buttons != null && buttons!.isNotEmpty) 'buttons': buttons,
  };
}

const List<String> _chromeRoleMarkers = [
  'application',
  'window',
  'tabbar',
  'scrollbar',
  'image',
];
const _chromeLabels = {'tab bar'};

/// Returns true when [message] is a wait-timeout message produced by
/// [AgentDevice.wait].
bool isWaitTimeoutMessage(String message) {
  return message.contains('timed out');
}

/// Captures the current surface snapshot and extracts a compact summary of
/// visible labels and interactive buttons. Returns null when the snapshot
/// cannot be captured or produces no useful labels.
Future<({String summary, CurrentSurfaceDetails details})?> inspectCurrentSurface(
  Backend backend,
  BackendCommandContext ctx,
) async {
  final BackendSnapshotResult capture;
  try {
    capture = await backend.captureSnapshot(
      ctx,
      const BackendSnapshotOptions(interactiveOnly: true, compact: true),
    );
  } catch (_) {
    return null;
  }

  final rawNodes = capture.nodes;
  if (rawNodes == null || rawNodes.isEmpty) return null;

  final nodes = rawNodes.whereType<SnapshotNode>().toList();
  if (nodes.isEmpty) return null;

  final orderedNodes = [...nodes]..sort(_compareSurfacePriority);

  final labels = _topSurfaceTexts(orderedNodes, 6, includeIdentifiers: true);
  if (labels.isEmpty) return null;

  final contentNodes =
      orderedNodes.where((n) => !_isChromeLikeNode(n)).toList();
  final summaryLabels = _topSurfaceTexts(
    contentNodes,
    4,
    includeIdentifiers: false,
  );
  final buttons = _topSurfaceTexts(
    orderedNodes.where(_isButtonLikeNode).toList(),
    4,
    includeIdentifiers: true,
  );
  final summary =
      (summaryLabels.isNotEmpty ? summaryLabels : labels.take(4).toList()).join(
        ', ',
      );

  return (
    summary: summary,
    details: CurrentSurfaceDetails(
      labels: labels,
      buttons: buttons.isNotEmpty ? buttons : null,
    ),
  );
}

List<String> _topSurfaceTexts(
  List<SnapshotNode> nodes,
  int limit, {
  required bool includeIdentifiers,
}) {
  final seen = <String>{};
  final result = <String>[];
  for (final node in nodes) {
    final text = _extractSurfaceText(node, includeIdentifiers: includeIdentifiers);
    if (text.isEmpty || seen.contains(text)) continue;
    seen.add(text);
    result.add(text);
    if (result.length >= limit) break;
  }
  return result;
}

int _compareSurfacePriority(SnapshotNode a, SnapshotNode b) {
  final diff = _surfacePriority(a) - _surfacePriority(b);
  if (diff != 0) return diff;
  return _compareSurfaceOrder(a, b);
}

int _surfacePriority(SnapshotNode node) {
  final hasHumanText =
      _extractSurfaceText(node, includeIdentifiers: false).isNotEmpty;
  final chromePenalty = _isChromeLikeNode(node) ? 2 : 0;
  return chromePenalty + (hasHumanText ? 0 : 1);
}

int _compareSurfaceOrder(SnapshotNode a, SnapshotNode b) {
  final aRect = a.rect;
  final bRect = b.rect;
  if (aRect != null && bRect != null) {
    final yDiff = (aRect.y - bRect.y).toInt();
    if (yDiff != 0) return yDiff;
    return (aRect.x - bRect.x).toInt();
  }
  if (aRect != null) return -1;
  if (bRect != null) return 1;
  final depthDiff = (a.depth ?? 0) - (b.depth ?? 0);
  if (depthDiff != 0) return depthDiff;
  return a.index - b.index;
}

String _extractSurfaceText(
  SnapshotNode node, {
  required bool includeIdentifiers,
}) {
  final candidates = includeIdentifiers
      ? [node.label, node.value, node.identifier]
      : [node.label, node.value];
  final value = candidates
      .map((c) => (c is String ? c.trim() : ''))
      .firstWhere((c) => c.isNotEmpty, orElse: () => '');
  if (value.isEmpty) return '';
  return value.replaceAll(RegExp(r'\s+'), ' ').substring(0, value.length.clamp(0, 80));
}

bool _isChromeLikeNode(SnapshotNode node) {
  final roleText = _normalizeType(
    '${node.type ?? ''} ${node.role ?? ''} ${node.subrole ?? ''}',
  );
  final label =
      '${node.label ?? ''} ${node.value ?? ''}'.trim().toLowerCase();
  return _chromeRoleMarkers.any((m) => roleText.contains(m)) ||
      _chromeLabels.contains(label) ||
      label.endsWith('.fill');
}

bool _isButtonLikeNode(SnapshotNode node) {
  final roleText =
      '${node.type ?? ''} ${node.role ?? ''} ${node.subrole ?? ''}';
  return _normalizeType(roleText).contains('button');
}

/// Normalize a type string to its last dot-separated component, lower-cased.
String _normalizeType(String type) {
  var normalized = type.toLowerCase();
  if (normalized.contains('.')) {
    final lastDot = normalized.lastIndexOf('.');
    if (lastDot != -1) {
      normalized = normalized.substring(lastDot + 1);
    }
  }
  return normalized;
}
