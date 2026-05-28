// Port of agent-device/src/platforms/android/alert.ts

import '../../backend/options.dart' show BackendAlertAction;
import '../../utils/errors.dart' show AppError, AppErrorCodes;
import 'alert_detection.dart';
import 'input_actions.dart' show backAndroid, pressAndroid;
import 'snapshot.dart' show AndroidSnapshotOptions, snapshotAndroid;

const _alertPollIntervalMs = 300;
const _defaultAlertTimeoutMs = 10000;
const _alertActionRetryMs = 2000;

// ---------------------------------------------------------------------------
// Result types
// ---------------------------------------------------------------------------

/// Result of an Android alert operation.
sealed class AndroidAlertResult {
  const AndroidAlertResult();
}

class AndroidAlertStatusResult extends AndroidAlertResult {
  final AndroidAlertInfo? alert;
  final String? message;

  const AndroidAlertStatusResult({this.alert, this.message});

  Map<String, Object?> toJson() => <String, Object?>{
    'kind': 'alertStatus',
    'platform': 'android',
    'action': 'get',
    'alert': alert?.toBackendAlertInfo().toJson(),
    if (message != null) 'message': message,
  };
}

class AndroidAlertWaitResult extends AndroidAlertResult {
  final AndroidAlertInfo alert;
  final int waitedMs;
  final String? message;

  const AndroidAlertWaitResult({
    required this.alert,
    required this.waitedMs,
    this.message,
  });

  Map<String, Object?> toJson() => <String, Object?>{
    'kind': 'alertWait',
    'platform': 'android',
    'action': 'wait',
    'alert': alert.toBackendAlertInfo().toJson(),
    'waitedMs': waitedMs,
    if (message != null) 'message': message,
  };
}

class AndroidAlertHandledResult extends AndroidAlertResult {
  final String action; // 'accept' | 'dismiss'
  final AndroidAlertInfo alert;
  final String button;
  final String? message;

  const AndroidAlertHandledResult({
    required this.action,
    required this.alert,
    required this.button,
    this.message,
  });

  Map<String, Object?> toJson() => <String, Object?>{
    'kind': 'alertHandled',
    'platform': 'android',
    'action': action,
    'handled': true,
    'alert': alert.toBackendAlertInfo().toJson(),
    'button': button,
    if (message != null) 'message': message,
  };
}

// ---------------------------------------------------------------------------
// Public API
// ---------------------------------------------------------------------------

/// Handle an Android alert for the given [action].
///
/// Port of `handleAndroidAlert` in `alert.ts`.
Future<AndroidAlertResult> handleAndroidAlert(
  String serial,
  BackendAlertAction action, {
  int? timeoutMs,
}) async {
  if (action == BackendAlertAction.wait) {
    return await _waitForAndroidAlert(
      serial,
      timeoutMs ?? _defaultAlertTimeoutMs,
    );
  }
  if (action == BackendAlertAction.get) {
    final candidate = await _readAndroidAlertCandidate(serial);
    return _buildAndroidAlertStatusResponse(candidate?.alert);
  }
  return await _handleAndroidAlertAction(serial, action);
}

// ---------------------------------------------------------------------------
// Internal helpers
// ---------------------------------------------------------------------------

Future<AndroidAlertResult> _waitForAndroidAlert(
  String serial,
  int timeoutMs,
) async {
  final start = DateTime.now().millisecondsSinceEpoch;
  final candidate = await _pollAndroidAlertCandidate(serial, timeoutMs);
  if (candidate == null) {
    throw AppError(AppErrorCodes.commandFailed, 'alert wait timed out');
  }
  return AndroidAlertWaitResult(
    alert: candidate.alert,
    waitedMs: DateTime.now().millisecondsSinceEpoch - start,
    message: 'Alert visible',
  );
}

Future<AndroidAlertResult> _handleAndroidAlertAction(
  String serial,
  BackendAlertAction action,
) async {
  final candidate = await _pollAndroidAlertCandidate(
    serial,
    _alertActionRetryMs,
  );
  if (candidate == null) {
    throw AppError(
      AppErrorCodes.commandFailed,
      'alert not found',
      details: {
        'hint':
            'If a sheet is visible in snapshot but alert reports no alert, '
            'it is likely app-owned UI. Use snapshot -i and press the visible '
            'label/ref.',
      },
    );
  }

  final actionStr = action == BackendAlertAction.accept ? 'accept' : 'dismiss';
  final button = chooseAndroidAlertButton(candidate.buttons, actionStr);
  if (button != null) {
    await pressAndroid(serial, button.x.round(), button.y.round());
    return _buildAndroidAlertHandledResponse(
      actionStr,
      candidate.alert,
      button.label,
    );
  }

  if (action == BackendAlertAction.dismiss) {
    await backAndroid(serial);
    return _buildAndroidAlertHandledResponse(
      actionStr,
      candidate.alert,
      'Back',
    );
  }

  throw AppError(
    AppErrorCodes.commandFailed,
    'alert accept found an alert but no accept button',
    details: {
      'alert': candidate.alert.toBackendAlertInfo().toJson(),
      'hint':
          'Inspect alert get --json for visible buttons, then use press by '
          'visible label/ref if needed.',
    },
  );
}

Future<AndroidAlertCandidate?> _pollAndroidAlertCandidate(
  String serial,
  int timeoutMs,
) async {
  final start = DateTime.now().millisecondsSinceEpoch;
  while (DateTime.now().millisecondsSinceEpoch - start < timeoutMs) {
    final candidate = await _readAndroidAlertCandidate(serial);
    if (candidate != null) return candidate;
    await Future<void>.delayed(
      const Duration(milliseconds: _alertPollIntervalMs),
    );
  }
  return null;
}

Future<AndroidAlertCandidate?> _readAndroidAlertCandidate(
  String serial,
) async {
  final result = await snapshotAndroid(
    serial,
    options: const AndroidSnapshotOptions(
      helperWaitForIdleTimeoutMs: 0,
      includeHiddenContentHints: false,
    ),
  );
  return findAndroidAlertCandidate(result.nodes);
}

AndroidAlertStatusResult _buildAndroidAlertStatusResponse(
  AndroidAlertInfo? alert,
) => AndroidAlertStatusResult(
  alert: alert,
  message: alert != null ? 'Alert visible' : 'No alert visible',
);

AndroidAlertHandledResult _buildAndroidAlertHandledResponse(
  String action,
  AndroidAlertInfo alert,
  String button,
) => AndroidAlertHandledResult(
  action: action,
  alert: alert,
  button: button,
  message: 'Alert ${action}ed',
);
