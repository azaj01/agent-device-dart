// Port of agent-device/src/platforms/android/snapshot-content-recovery.ts

import 'snapshot_types.dart';
import 'ui_hierarchy.dart';

const _androidWindowTypeApplication = 1;
const _maxReportedWindowTypes = 8;
const _minForegroundAppMeaningfulNodes = 2;
const _androidSystemPackages = {'android', 'com.android.systemui'};

/// Decision returned when the helper output is classified as needing recovery.
class AndroidHelperContentRecoveryDecision {
  final String reason;
  final String fallbackReason;
  final Map<String, Object?> diagnostics;

  const AndroidHelperContentRecoveryDecision({
    required this.reason,
    required this.fallbackReason,
    required this.diagnostics,
  });
}

/// Classify whether helper XML output should trigger a stock uiautomator
/// fallback due to missing or insufficient application content.
///
/// Returns a [AndroidHelperContentRecoveryDecision] describing the recovery
/// needed, or `null` if the helper output looks healthy.
///
/// Port of `classifyAndroidHelperContentRecovery` in
/// `snapshot-content-recovery.ts`.
AndroidHelperContentRecoveryDecision? classifyAndroidHelperContentRecovery(
  String xml,
  AndroidSnapshotBackendMetadata metadata, {
  String? foregroundAppPackage,
}) {
  if (metadata.backend != 'android-helper') return null;

  final summary = _summarizeAndroidHelperXml(xml, foregroundAppPackage);

  if (summary.nodeCount == 0 ||
      (metadata.nodeCount ?? 0) == 0 ||
      metadata.rootPresent == false) {
    return _buildRecoveryDecision(
      summary,
      metadata,
      'empty-helper-output',
      'Android snapshot helper returned no accessibility nodes',
    );
  }

  final foregroundAppMeaningfulNodeCount =
      summary.foregroundAppMeaningfulNodeCount;
  if (foregroundAppMeaningfulNodeCount != null &&
      (foregroundAppMeaningfulNodeCount == 0 ||
          (foregroundAppMeaningfulNodeCount < _minForegroundAppMeaningfulNodes &&
              summary.meaningfulNodeCount > foregroundAppMeaningfulNodeCount))) {
    return _buildRecoveryDecision(
      summary,
      metadata,
      'content-poor-app-window',
      'Android snapshot helper returned insufficient foreground app content',
    );
  }

  if (foregroundAppMeaningfulNodeCount == null &&
      summary.applicationWindowRootCount > 0 &&
      summary.applicationMeaningfulNodeCount < _minForegroundAppMeaningfulNodes) {
    return _buildRecoveryDecision(
      summary,
      metadata,
      'content-poor-app-window',
      'Android snapshot helper returned insufficient application window content',
    );
  }

  if (foregroundAppMeaningfulNodeCount == null &&
      summary.windowRootCount == 0 &&
      (metadata.windowCount ?? 0) > 1 &&
      summary.nonSystemMeaningfulNodeCount < _minForegroundAppMeaningfulNodes) {
    return _buildRecoveryDecision(
      summary,
      metadata,
      'content-poor-app-window',
      'Android snapshot helper returned insufficient application window content',
    );
  }

  if (summary.windowRootCount > 0 && summary.applicationWindowRootCount == 0) {
    return _buildRecoveryDecision(
      summary,
      metadata,
      'system-window-only',
      'Android snapshot helper returned only non-application windows',
    );
  }

  return null;
}

AndroidHelperContentRecoveryDecision _buildRecoveryDecision(
  _AndroidHelperXmlSummary summary,
  AndroidSnapshotBackendMetadata metadata,
  String reason,
  String fallbackReason,
) {
  return AndroidHelperContentRecoveryDecision(
    reason: reason,
    fallbackReason: fallbackReason,
    diagnostics: _buildRecoveryDiagnostics(summary, metadata),
  );
}

// ---------------------------------------------------------------------------
// XML summary
// ---------------------------------------------------------------------------

class _AndroidHelperXmlSummary {
  final int nodeCount;
  final int windowRootCount;
  final int applicationWindowRootCount;
  final int meaningfulNodeCount;
  final int applicationMeaningfulNodeCount;
  final int nonSystemMeaningfulNodeCount;
  final String? foregroundAppPackage;
  final int? foregroundAppMeaningfulNodeCount;
  final List<int> windowTypes;

  const _AndroidHelperXmlSummary({
    required this.nodeCount,
    required this.windowRootCount,
    required this.applicationWindowRootCount,
    required this.meaningfulNodeCount,
    required this.applicationMeaningfulNodeCount,
    required this.nonSystemMeaningfulNodeCount,
    required this.windowTypes,
    this.foregroundAppPackage,
    this.foregroundAppMeaningfulNodeCount,
  });
}

class _SummaryState {
  int nodeCount = 0;
  int windowRootCount = 0;
  int applicationWindowRootCount = 0;
  int meaningfulNodeCount = 0;
  int applicationMeaningfulNodeCount = 0;
  int nonSystemMeaningfulNodeCount = 0;
  int? foregroundAppMeaningfulNodeCount;
  String? foregroundAppPackage;
  int? currentWindowType;
  final Set<int> windowTypes = {};

  _SummaryState({String? foregroundAppPackage}) {
    if (foregroundAppPackage != null) {
      this.foregroundAppPackage = foregroundAppPackage;
      foregroundAppMeaningfulNodeCount = 0;
    }
  }
}

_AndroidHelperXmlSummary _summarizeAndroidHelperXml(
  String xml,
  String? foregroundAppPackage,
) {
  final state = _SummaryState(foregroundAppPackage: foregroundAppPackage);
  for (final node in androidUiNodes(xml)) {
    _recordSummaryNode(state, node);
  }
  return _finalizeSummary(state);
}

void _recordSummaryNode(_SummaryState state, AndroidUiNodeMetadata node) {
  state.nodeCount += 1;
  _recordWindowNode(state, node);
  _recordMeaningfulNode(state, node);
}

void _recordWindowNode(_SummaryState state, AndroidUiNodeMetadata node) {
  final wt = node.windowType;
  if (wt == null) return;
  state.currentWindowType = wt;
  state.windowRootCount += 1;
  state.windowTypes.add(wt);
  if (wt == _androidWindowTypeApplication) {
    state.applicationWindowRootCount += 1;
  }
}

void _recordMeaningfulNode(_SummaryState state, AndroidUiNodeMetadata node) {
  if (!_isMeaningfulContentNode(node)) return;
  state.meaningfulNodeCount += 1;
  if (state.currentWindowType == _androidWindowTypeApplication) {
    state.applicationMeaningfulNodeCount += 1;
  }
  if (!_isAndroidSystemPackage(node.packageName)) {
    state.nonSystemMeaningfulNodeCount += 1;
  }
  if (state.foregroundAppPackage != null &&
      node.packageName == state.foregroundAppPackage) {
    state.foregroundAppMeaningfulNodeCount =
        (state.foregroundAppMeaningfulNodeCount ?? 0) + 1;
  }
}

_AndroidHelperXmlSummary _finalizeSummary(_SummaryState state) {
  final sortedTypes = state.windowTypes.toList()..sort();
  return _AndroidHelperXmlSummary(
    nodeCount: state.nodeCount,
    windowRootCount: state.windowRootCount,
    applicationWindowRootCount: state.applicationWindowRootCount,
    meaningfulNodeCount: state.meaningfulNodeCount,
    applicationMeaningfulNodeCount: state.applicationMeaningfulNodeCount,
    nonSystemMeaningfulNodeCount: state.nonSystemMeaningfulNodeCount,
    foregroundAppPackage: state.foregroundAppPackage,
    foregroundAppMeaningfulNodeCount: state.foregroundAppMeaningfulNodeCount,
    windowTypes: sortedTypes.take(_maxReportedWindowTypes).toList(),
  );
}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

bool _isMeaningfulContentNode(AndroidUiNodeMetadata node) {
  if (node.visibleToUser == false) return false;
  return _hasText(node.text) || _hasText(node.desc) || _hasText(node.resourceId);
}

bool _hasText(String? value) {
  return value != null && value.trim().isNotEmpty;
}

bool _isAndroidSystemPackage(String? packageName) {
  return packageName == null || _androidSystemPackages.contains(packageName);
}

Map<String, Object?> _buildRecoveryDiagnostics(
  _AndroidHelperXmlSummary summary,
  AndroidSnapshotBackendMetadata metadata,
) {
  return {
    'helperNodeCount': summary.nodeCount,
    'helperWindowRootCount': summary.windowRootCount,
    'helperApplicationWindowRootCount': summary.applicationWindowRootCount,
    'helperMeaningfulNodeCount': summary.meaningfulNodeCount,
    'helperApplicationMeaningfulNodeCount': summary.applicationMeaningfulNodeCount,
    'helperNonSystemMeaningfulNodeCount': summary.nonSystemMeaningfulNodeCount,
    if (summary.foregroundAppPackage != null) ...{
      'helperForegroundAppPackage': summary.foregroundAppPackage,
      'helperForegroundAppMeaningfulNodeCount':
          summary.foregroundAppMeaningfulNodeCount,
      'helperForegroundAppMeaningfulNodeThreshold':
          _minForegroundAppMeaningfulNodes,
    },
    'helperWindowTypes': summary.windowTypes,
    if (metadata.captureMode != null) 'helperCaptureMode': metadata.captureMode,
  };
}
