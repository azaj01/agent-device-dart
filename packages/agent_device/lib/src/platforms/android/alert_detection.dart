// Port of agent-device/src/platforms/android/alert-detection.ts

import 'dart:collection' show LinkedHashSet;

import '../../backend/options.dart' show AlertPlatform, AlertSource, BackendAlertInfo;
import '../../snapshot/snapshot.dart' show Point, RawSnapshotNode, Rect;

typedef AndroidAlertButtonRole = String; // 'accept' | 'dismiss' | 'neutral'

/// A detected button in an Android alert dialog.
class AndroidAlertButton {
  final String label;
  final double x;
  final double y;
  final AndroidAlertButtonRole role;

  const AndroidAlertButton({
    required this.label,
    required this.x,
    required this.y,
    required this.role,
  });
}

/// Full metadata about an Android alert including buttons.
class AndroidAlertInfo {
  final String? title;
  final String? message;
  final List<String> buttons;
  final AlertPlatform platform;
  final AlertSource source;
  final String? packageName;

  const AndroidAlertInfo({
    this.title,
    this.message,
    required this.buttons,
    required this.platform,
    required this.source,
    this.packageName,
  });

  BackendAlertInfo toBackendAlertInfo() => BackendAlertInfo(
    title: title,
    message: message,
    buttons: buttons,
    platform: platform,
    source: source,
    packageName: packageName,
  );
}

/// Candidate alert found in the UI hierarchy.
class AndroidAlertCandidate {
  final AndroidAlertInfo alert;
  final List<AndroidAlertButton> buttons;

  const AndroidAlertCandidate({required this.alert, required this.buttons});
}

// ---------------------------------------------------------------------------
// Constants
// ---------------------------------------------------------------------------

final _androidPermissionPackages = const {
  'com.android.permissioncontroller',
  'com.google.android.permissioncontroller',
  'com.google.android.packageinstaller',
  'com.android.packageinstaller',
};

final _androidSystemDialogPackages = const {
  'android',
  'com.android.systemui',
};

final _androidAlertIdPattern = RegExp(
  r'^android:id\/(?:alertTitle|message|button[123]|parentPanel|buttonPanel|contentPanel)$',
  caseSensitive: false,
);

final _androidAlertButtonIdPattern = RegExp(
  r'^android:id\/button[123]$',
  caseSensitive: false,
);

final _androidPermissionIdPattern = RegExp(
  r'(?:^|:)id\/permission_',
  caseSensitive: false,
);

final _androidBlockingDialogPattern = RegExp(
  r"\b(?:is(?:n't| not) responding|keeps stopping|has stopped|close app|app info)\b",
  caseSensitive: false,
);

final _acceptLabelPattern = RegExp(
  r'^(?:ok|allow|allow all|while using the app|only this time|yes|continue|save|confirm|turn on|open settings)$',
  caseSensitive: false,
);

final _dismissLabelPattern = RegExp(
  r"^(?:cancel|deny|don.t allow|don't allow|not now|no|dismiss|close|close app|later|skip)$",
  caseSensitive: false,
);

// ---------------------------------------------------------------------------
// Public API
// ---------------------------------------------------------------------------

/// Find an Android alert candidate in [nodes].
///
/// Returns null if no alert-like UI is detected.
///
/// Port of `findAndroidAlertCandidate` in `alert-detection.ts`.
AndroidAlertCandidate? findAndroidAlertCandidate(List<RawSnapshotNode> nodes) {
  final candidate = _findAndroidAlertNodes(nodes);
  final candidateNodes = candidate.nodes;
  if (candidateNodes.isEmpty) return null;

  final buttons = _findAlertButtons(candidateNodes);
  final textNodes = candidateNodes
      .where((node) => _readNodeText(node).isNotEmpty && !_isButtonLike(node))
      .toList();
  final title = _chooseAlertTitle(textNodes);
  final message = _chooseAlertMessage(textNodes, title);
  final packageName = _choosePackageName(candidateNodes);
  return AndroidAlertCandidate(
    alert: AndroidAlertInfo(
      title: title,
      message: message,
      buttons: buttons.map((b) => b.label).toList(),
      platform: AlertPlatform.android,
      source: candidate.source,
      packageName: packageName,
    ),
    buttons: buttons,
  );
}

/// Choose which button to tap for [action] ('accept' or 'dismiss').
///
/// Returns null if no suitable button is found.
///
/// Port of `chooseAndroidAlertButton` in `alert-detection.ts`.
AndroidAlertButton? chooseAndroidAlertButton(
  List<AndroidAlertButton> buttons,
  String action,
) {
  final role = action == 'accept' ? 'accept' : 'dismiss';
  final exact = buttons.where((b) => b.role == role).firstOrNull;
  if (exact != null) return exact;
  if (action == 'dismiss') {
    return buttons.where((b) => b.role == 'neutral').firstOrNull;
  }
  // Single-button Android dialogs commonly expose the only affirmative path as OK.
  return buttons.length == 1 ? buttons[0] : null;
}

// ---------------------------------------------------------------------------
// Alert node detection
// ---------------------------------------------------------------------------

({List<RawSnapshotNode> nodes, AlertSource source}) _findAndroidAlertNodes(
  List<RawSnapshotNode> nodes,
) {
  final permissionNodes =
      nodes.where((node) => _isAndroidPermissionNode(node)).toList();
  if (permissionNodes.isNotEmpty) {
    return (nodes: permissionNodes, source: AlertSource.permission);
  }

  final systemDialogNodes = _findSystemDialogNodes(nodes);
  if (systemDialogNodes.isNotEmpty) {
    return (nodes: systemDialogNodes, source: AlertSource.systemDialog);
  }

  return (nodes: _findNativeDialogNodes(nodes), source: AlertSource.nativeDialog);
}

List<RawSnapshotNode> _findNativeDialogNodes(List<RawSnapshotNode> nodes) {
  final dialogNodes =
      nodes.where((node) => _isAndroidDialogType(node.type ?? '')).toList();
  final alertIdNodes = nodes
      .where((node) => _androidAlertIdPattern.hasMatch(node.identifier ?? ''))
      .toList();
  final List<RawSnapshotNode> signalNodes;
  if (dialogNodes.isNotEmpty) {
    signalNodes = [...dialogNodes, ...alertIdNodes];
  } else {
    signalNodes = _correlatedAndroidAlertIdNodes(alertIdNodes);
  }
  if (signalNodes.isEmpty) return const [];
  final rootIndex = _findCommonAncestorIndex(nodes, signalNodes);
  if (rootIndex == null) return signalNodes;
  return _collectDescendants(nodes, rootIndex);
}

bool _isAndroidDialogType(String type) {
  return RegExp(
    r'(?:^|[.$])[^.]*Dialog$',
    caseSensitive: false,
  ).hasMatch(type);
}

List<RawSnapshotNode> _correlatedAndroidAlertIdNodes(
  List<RawSnapshotNode> nodes,
) {
  final hasButton = nodes.any(
    (node) => _androidAlertButtonIdPattern.hasMatch(node.identifier ?? ''),
  );
  final hasContent = nodes.any(
    (node) => !_androidAlertButtonIdPattern.hasMatch(node.identifier ?? ''),
  );
  return hasButton && hasContent ? nodes : const [];
}

List<RawSnapshotNode> _findSystemDialogNodes(List<RawSnapshotNode> nodes) {
  final signalNodes =
      nodes.where((node) => _isAndroidSystemDialogNode(node)).toList();
  if (signalNodes.isEmpty) return const [];
  final rootIndex = _findCommonAncestorIndex(nodes, signalNodes);
  if (rootIndex == null) return signalNodes;
  return _collectDescendants(nodes, rootIndex)
      .where(
        (node) =>
            node.bundleId != null &&
            _androidSystemDialogPackages.contains(node.bundleId),
      )
      .toList();
}

// ---------------------------------------------------------------------------
// Button detection
// ---------------------------------------------------------------------------

List<AndroidAlertButton> _findAlertButtons(List<RawSnapshotNode> nodes) {
  final seen = <String>{};
  final buttons = <AndroidAlertButton>[];
  for (final node in nodes) {
    final label = _readNodeText(node);
    if (label.isEmpty || node.rect == null || !_isButtonLike(node)) continue;
    final normalized = label.trim().toLowerCase();
    if (normalized.isEmpty || seen.contains(normalized)) continue;
    seen.add(normalized);
    final point = _centerOfRect(node.rect!);
    buttons.add(
      AndroidAlertButton(
        label: label,
        x: point.x,
        y: point.y,
        role: _classifyAndroidAlertButton(node, label),
      ),
    );
  }
  return buttons;
}

AndroidAlertButtonRole _classifyAndroidAlertButton(
  RawSnapshotNode node,
  String label,
) {
  final identifier = node.identifier ?? '';
  final roleFromId = _classifyAndroidAlertButtonById(identifier);
  if (roleFromId != null) return roleFromId;
  if (_acceptLabelPattern.hasMatch(label.trim())) return 'accept';
  if (_dismissLabelPattern.hasMatch(label.trim())) return 'dismiss';
  return 'neutral';
}

AndroidAlertButtonRole? _classifyAndroidAlertButtonById(String identifier) {
  if (RegExp(r'(?:^|:)id\/button1$', caseSensitive: false).hasMatch(identifier)) {
    return 'accept';
  }
  if (RegExp(r'(?:^|:)id\/button2$', caseSensitive: false).hasMatch(identifier)) {
    return 'dismiss';
  }
  if (RegExp(r'(?:^|:)id\/button3$', caseSensitive: false).hasMatch(identifier)) {
    return 'neutral';
  }
  if (RegExp(
    r'(?:^|:)id\/permission_allow',
    caseSensitive: false,
  ).hasMatch(identifier)) {
    return 'accept';
  }
  if (RegExp(
    r'(?:^|:)id\/permission_deny',
    caseSensitive: false,
  ).hasMatch(identifier)) {
    return 'dismiss';
  }
  return null;
}

// ---------------------------------------------------------------------------
// Text extraction
// ---------------------------------------------------------------------------

String? _chooseAlertTitle(List<RawSnapshotNode> nodes) {
  final explicit = nodes
      .where(
        (node) => RegExp(
          r'(?:^|:)id\/(?:alertTitle|permission_message)$',
          caseSensitive: false,
        ).hasMatch(node.identifier ?? ''),
      )
      .firstOrNull;
  final fromExplicit = _readNodeText(explicit);
  if (fromExplicit.isNotEmpty) return fromExplicit;
  final fromFirst = nodes.isNotEmpty ? _readNodeText(nodes[0]) : '';
  return fromFirst.isNotEmpty ? fromFirst : null;
}

String? _chooseAlertMessage(
  List<RawSnapshotNode> nodes,
  String? title,
) {
  final parts = nodes
      .map(_readNodeText)
      .where((text) => text.isNotEmpty && text != title)
      .toList();
  if (parts.isEmpty) return null;
  return LinkedHashSet<String>.from(parts).join('\n');
}

// ---------------------------------------------------------------------------
// Tree traversal helpers
// ---------------------------------------------------------------------------

int? _findCommonAncestorIndex(
  List<RawSnapshotNode> nodes,
  List<RawSnapshotNode> signalNodes,
) {
  if (signalNodes.isEmpty) return null;
  final first = signalNodes[0];
  final common = _ancestorIndexes(nodes, first.index);
  for (final signal in signalNodes.skip(1)) {
    final ancestors = _ancestorIndexes(nodes, signal.index).toSet();
    common.removeWhere((idx) => !ancestors.contains(idx));
  }
  return common.isNotEmpty ? common.last : null;
}

List<int> _ancestorIndexes(List<RawSnapshotNode> nodes, int index) {
  final byIndex = <int, RawSnapshotNode>{
    for (final node in nodes) node.index: node,
  };
  final result = <int>[];
  var current = byIndex[index];
  while (current != null) {
    result.add(current.index);
    final parent = current.parentIndex;
    current = parent == null ? null : byIndex[parent];
  }
  return result.reversed.toList();
}

List<RawSnapshotNode> _collectDescendants(
  List<RawSnapshotNode> nodes,
  int rootIndex,
) {
  final childrenByParent = <int, List<RawSnapshotNode>>{};
  for (final node in nodes) {
    final parent = node.parentIndex;
    if (parent == null) continue;
    (childrenByParent[parent] ??= []).add(node);
  }

  final descendants = <int>{rootIndex};
  final pending = [rootIndex];
  var head = 0;
  while (head < pending.length) {
    final idx = pending[head++];
    for (final child in childrenByParent[idx] ?? const <RawSnapshotNode>[]) {
      if (descendants.add(child.index)) {
        pending.add(child.index);
      }
    }
  }
  return nodes.where((node) => descendants.contains(node.index)).toList();
}

// ---------------------------------------------------------------------------
// Node predicates
// ---------------------------------------------------------------------------

bool _isAndroidPermissionNode(RawSnapshotNode node) {
  final packageName = node.bundleId ?? '';
  return _androidPermissionPackages.contains(packageName) ||
      _androidPermissionIdPattern.hasMatch(node.identifier ?? '');
}

bool _isAndroidSystemDialogNode(RawSnapshotNode node) {
  final packageName = node.bundleId ?? '';
  return _androidSystemDialogPackages.contains(packageName) &&
      _androidBlockingDialogPattern.hasMatch(_readNodeText(node));
}

bool _isButtonLike(RawSnapshotNode node) {
  final type = node.type ?? '';
  final identifier = node.identifier ?? '';
  return (node.hittable ?? false) ||
      RegExp(r'\bbutton\b', caseSensitive: false).hasMatch(type) ||
      _androidAlertButtonIdPattern.hasMatch(identifier) ||
      RegExp(
        r'(?:^|:)id\/permission_(?:allow|deny)',
        caseSensitive: false,
      ).hasMatch(identifier);
}

String _readNodeText(RawSnapshotNode? node) {
  if (node == null) return '';
  final label = node.label;
  if (label != null && label.trim().isNotEmpty) return label.trim();
  final value = node.value;
  if (value != null && value.trim().isNotEmpty) return value.trim();
  return '';
}

String? _choosePackageName(List<RawSnapshotNode> nodes) {
  return nodes.where((node) => node.bundleId != null).firstOrNull?.bundleId;
}

// ---------------------------------------------------------------------------
// Geometry helper
// ---------------------------------------------------------------------------

Point _centerOfRect(Rect rect) => Point(
  x: rect.x + rect.width / 2,
  y: rect.y + rect.height / 2,
);
