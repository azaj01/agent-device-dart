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

/// The device viewport bounds. Derived from the largest node extent in the
/// snapshot rather than `nodes.first`: the two CLIs order the tree differently
/// (npm emits the full-window root first; the Dart port may emit a smaller
/// foreground container first), so the first node's rect is not a reliable
/// screen-size proxy. The maximum right/bottom edge across all nodes is, and
/// is identical in shape across both CLIs.
({double w, double h})? screenBounds(Map<String, dynamic>? envelope) {
  var w = 0.0;
  var h = 0.0;
  for (final n in nodesOf(envelope)) {
    final r = n['rect'];
    if (r is! Map) continue;
    final x = r['x'] as num?;
    final y = r['y'] as num?;
    final rw = r['width'] as num?;
    final rh = r['height'] as num?;
    if (x == null || y == null || rw == null || rh == null) continue;
    final right = x.toDouble() + rw.toDouble();
    final bottom = y.toDouble() + rh.toDouble();
    if (right > w) w = right;
    if (bottom > h) h = bottom;
  }
  if (w <= 0 || h <= 0) return null;
  return (w: w, h: h);
}

/// Centre point of the node identified by [id], or null if absent, rect-less,
/// or off-screen.
///
/// Off-screen elements are reported differently per platform: Flutter gives a
/// degenerate (zero-size) rect, while iOS/RN gives a real rect in content
/// coordinates that can lie beyond the viewport. Both are rejected — a
/// zero-size rect, or a centre outside the screen bounds — so callers never tap
/// a point that isn't actually visible (and `revealId` knows to scroll).
/// Rect values may be `int` (npm) or `double` (Dart).
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
  final cx = x.toDouble() + w.toDouble() / 2;
  final cy = y.toDouble() + h.toDouble() / 2;
  final b = screenBounds(envelope);
  if (b != null && (cx < 0 || cy < 0 || cx > b.w || cy > b.h)) return null; // scrolled out of view
  return (x: cx, y: cy);
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
