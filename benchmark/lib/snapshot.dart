/// Helpers for reading the accessibility snapshot envelope, which is identical
/// in shape across both CLIs: `data.nodes[]`, each node carrying `identifier`,
/// `label`, `value`, `type`, `ref`, and a `rect`.
library;

/// A point on screen, in device-independent points.
typedef Point = ({double x, double y});

/// Extract `data.nodes` from a parsed snapshot envelope.
List<Map<String, dynamic>> nodesOf(Map<String, dynamic>? envelope) {
  final data = envelope?['data'];
  final nodes = (data is Map) ? data['nodes'] : null;
  if (nodes is! List) return const [];
  return nodes.whereType<Map>().map((n) => n.cast<String, dynamic>()).toList();
}

/// The first node whose accessibility identifier equals [id].
Map<String, dynamic>? nodeById(Map<String, dynamic>? envelope, String id) {
  for (final n in nodesOf(envelope)) {
    if (n['identifier'] == id) return n;
  }
  return null;
}

/// True if any node in the snapshot carries [id] as its identifier.
bool hasId(Map<String, dynamic>? envelope, String id) => nodeById(envelope, id) != null;

/// The set of accessibility identifiers present in the snapshot.
Set<String> identifiersOf(Map<String, dynamic>? envelope) => {
      for (final n in nodesOf(envelope))
        if (n['identifier'] is String) n['identifier'] as String,
    };

/// Centre point of the node identified by [id], or null if absent, rect-less,
/// or off-screen. Off-screen elements are reported by the runner with a
/// degenerate (zero-size) rect, so those are treated as unreachable rather than
/// tapped at (0,0). Rect values may be `int` (npm) or `double` (Dart).
Point? centerById(Map<String, dynamic>? envelope, String id) {
  final node = nodeById(envelope, id);
  final rect = node?['rect'];
  if (rect is! Map) return null;
  final x = rect['x'] as num?;
  final y = rect['y'] as num?;
  final w = rect['width'] as num?;
  final h = rect['height'] as num?;
  if (x == null || y == null || w == null || h == null) return null;
  if (w <= 0 || h <= 0) return null; // off-screen / not laid out
  return (x: x.toDouble() + w.toDouble() / 2, y: y.toDouble() + h.toDouble() / 2);
}

/// Concatenated `label` + `value` text of every node, for substring assertions
/// about screen state (e.g. "did the submission summary appear?").
String allText(Map<String, dynamic>? envelope) {
  final buf = StringBuffer();
  for (final n in nodesOf(envelope)) {
    final label = n['label'];
    final value = n['value'];
    if (label is String) buf.writeln(label);
    if (value is String) buf.writeln(value);
  }
  return buf.toString();
}

/// Text (label/value) of the node identified by [id], if any.
String? textOfId(Map<String, dynamic>? envelope, String id) {
  final node = nodeById(envelope, id);
  if (node == null) return null;
  final label = node['label'];
  final value = node['value'];
  return [if (label is String) label, if (value is String) value].join(' ').trim();
}
