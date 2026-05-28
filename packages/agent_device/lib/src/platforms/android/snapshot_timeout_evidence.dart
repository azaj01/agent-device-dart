// Port of agent-device/src/daemon/android-snapshot-timeout-evidence.ts

import 'dart:io';

import 'package:path/path.dart' as p;

import '../../utils/diagnostics.dart';
import '../../utils/errors.dart';
import '../../utils/logger.dart';
import 'screenshot.dart';

/// Payload describing the result of an Android snapshot timeout screenshot
/// capture attempt.
///
/// One of three shapes:
/// - Capture failed: [captureFailed] is true, [error] holds the reason.
/// - Captured but no session snapshot to annotate overlay refs from:
///   [path] is set, [overlayRefSource] is 'unavailable'.
/// - Captured with overlay ref annotation result: [path] is set,
///   [overlayRefSource] is 'session-snapshot', [overlayRefsAnnotated]
///   reflects whether refs were drawn.
class AndroidSnapshotTimeoutEvidence {
  /// True when the fallback screenshot capture itself failed.
  final bool? captureFailed;

  /// Error message when [captureFailed] is true.
  final String? error;

  /// Path to the captured screenshot file.
  final String? path;

  /// Whether overlay ref annotation was requested (always true when [path] set).
  final bool? overlayRefsRequested;

  /// Where overlay refs came from: 'unavailable' or 'session-snapshot'.
  final String? overlayRefSource;

  /// Whether overlay refs were successfully annotated onto the screenshot.
  final bool? overlayRefsAnnotated;

  /// Number of overlay refs annotated.
  final int? overlayRefCount;

  /// Error encountered while annotating overlay refs, if any.
  final String? overlayAnnotationError;

  const AndroidSnapshotTimeoutEvidence({
    this.captureFailed,
    this.error,
    this.path,
    this.overlayRefsRequested,
    this.overlayRefSource,
    this.overlayRefsAnnotated,
    this.overlayRefCount,
    this.overlayAnnotationError,
  });

  Map<String, Object?> toJson() => <String, Object?>{
    if (captureFailed != null) 'captureFailed': captureFailed,
    if (error != null) 'error': error,
    if (path != null) 'path': path,
    if (overlayRefsRequested != null) 'overlayRefsRequested': overlayRefsRequested,
    if (overlayRefSource != null) 'overlayRefSource': overlayRefSource,
    if (overlayRefsAnnotated != null) 'overlayRefsAnnotated': overlayRefsAnnotated,
    if (overlayRefCount != null) 'overlayRefCount': overlayRefCount,
    if (overlayAnnotationError != null) 'overlayAnnotationError': overlayAnnotationError,
  };
}

/// If [error] is an Android snapshot timeout error, captures a fallback
/// screenshot and returns an enhanced [AppError] with timeout evidence in
/// its details.
///
/// Returns null when the error is not a recognized Android snapshot timeout,
/// so callers can `rethrow` the original in that case.
///
/// Port of `maybeBuildAndroidSnapshotTimeoutFailure` from
/// `android-snapshot-timeout-evidence.ts`, adapted for the Dart port where
/// there is no daemon response type — instead the evidence is attached as
/// extra details on the rethrown [AppError].
Future<AppError?> maybeBuildAndroidSnapshotTimeoutError({
  required Object error,
  required String serial,
}) async {
  if (!_isAndroidSnapshotTimeoutError(error)) return null;
  final appErr = asAppError(error);

  final evidence = await _captureAndroidSnapshotTimeoutEvidence(serial);

  return AppError(
    appErr.code,
    appErr.message,
    details: {
      ...(appErr.details ?? {}),
      'androidSnapshotTimeoutScreenshot': evidence.toJson(),
    },
    cause: appErr.cause,
  );
}

// ---------------------------------------------------------------------------
// Internal helpers
// ---------------------------------------------------------------------------

Future<AndroidSnapshotTimeoutEvidence>
_captureAndroidSnapshotTimeoutEvidence(String serial) async {
  try {
    final tempDir = await Directory.systemTemp.createTemp(
      'agent-device-android-snapshot-timeout-',
    );
    final screenshotPath = p.join(
      tempDir.path,
      'snapshot-timeout-overlay-refs.png',
    );
    // Use stabilize=false to avoid repeating the accessibility stabilization
    // timeout that this fallback is trying to document.
    await screenshotAndroid(serial, screenshotPath, false);

    if (!File(screenshotPath).existsSync()) {
      throw AppError(
        AppErrorCodes.commandFailed,
        'Snapshot timeout screenshot file not found after capture',
        details: {'path': screenshotPath},
      );
    }

    // The Dart port has no session snapshot overlay-ref annotation yet
    // (that machinery lives in the daemon layer), so we report
    // overlayRefSource as 'unavailable'.
    final evidence = AndroidSnapshotTimeoutEvidence(
      path: screenshotPath,
      overlayRefsRequested: true,
      overlayRefSource: 'unavailable',
      overlayRefsAnnotated: false,
      overlayRefCount: 0,
    );

    emitDiagnostic(
      EmitDiagnosticOptions(
        level: DiagnosticLevel.warn,
        phase: 'android_snapshot_timeout_screenshot_captured',
        data: {
          'path': screenshotPath,
          'overlayRefCount': evidence.overlayRefCount,
          'overlayRefsAnnotated': evidence.overlayRefsAnnotated,
        },
      ),
    );
    return evidence;
  } catch (error) {
    final normalized = normalizeError(error);
    logger.trace(
      '[snapshot] Android snapshot timeout screenshot failed: ${normalized.message}',
    );
    emitDiagnostic(
      EmitDiagnosticOptions(
        level: DiagnosticLevel.warn,
        phase: 'android_snapshot_timeout_screenshot_failed',
        data: {'error': normalized.message},
      ),
    );
    return AndroidSnapshotTimeoutEvidence(
      captureFailed: true,
      error: normalized.message,
    );
  }
}

/// True when [error] is an Android accessibility snapshot timeout.
bool _isAndroidSnapshotTimeoutError(Object error) {
  if (error is! AppError) return false;
  if (error.code != AppErrorCodes.commandFailed) return false;
  return _hasKnownAndroidSnapshotTimeoutMessage(error) ||
      _hasHelperTimeoutDetails(error.details?['helper']) ||
      _hasUiAutomatorDumpTimeoutDetails(error.details);
}

bool _hasKnownAndroidSnapshotTimeoutMessage(AppError error) {
  final text =
      '${error.message}\n${error.details?['hint'] ?? ''}';
  if (RegExp(r'Android UI hierarchy dump timed out', caseSensitive: false)
      .hasMatch(text)) {
    return true;
  }
  if (RegExp(r'Stock UIAutomator fallback was skipped', caseSensitive: false)
      .hasMatch(text)) {
    return true;
  }
  return RegExp(
    r'Android accessibility snapshots can be blocked',
    caseSensitive: false,
  ).hasMatch(text);
}

bool _hasHelperTimeoutDetails(Object? helper) {
  if (helper == null || helper is! Map) return false;
  final helperMap = helper as Map<Object?, Object?>;
  final errorType = '${helperMap['errorType'] ?? ''}';
  final message = '${helperMap['message'] ?? ''}';
  return RegExp(r'TimeoutException', caseSensitive: false).hasMatch(errorType) ||
      RegExp(r'timed out', caseSensitive: false).hasMatch(message);
}

bool _hasUiAutomatorDumpTimeoutDetails(Map<String, Object?>? details) {
  if (details == null) return false;
  final timeoutMs = details['timeoutMs'];
  final cmd = details['cmd'];
  final args = _normalizeArgList(details['args']);
  return timeoutMs is int &&
      cmd == 'adb' &&
      args.contains('uiautomator') &&
      args.contains('dump');
}

List<String> _normalizeArgList(Object? rawArgs) {
  if (rawArgs is List) return rawArgs.map((e) => '$e').toList();
  if (rawArgs is String) return rawArgs.split(RegExp(r'\s+'));
  return [];
}
