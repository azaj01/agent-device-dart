// Port of agent-device/src/daemon/android-system-dialog.ts

import '../../snapshot/processing.dart' show pruneGroupNodes;
import '../../snapshot/snapshot.dart'
    show SnapshotNode, SnapshotOptions, attachRefs, centerOfRect;
import '../../utils/diagnostics.dart'
    show DiagnosticLevel, EmitDiagnosticOptions, emitDiagnostic;
import '../../utils/errors.dart' show AppError, AppErrorCodes;
import '../../utils/exec.dart' show ExecOptions, runCmd;
import 'adb.dart' show adbArgs;
import 'app_lifecycle.dart'
    show
        AndroidBlockingDialogFocus,
        getAndroidAppState,
        getAndroidBlockingDialogFocus,
        openAndroidApp;
import 'snapshot.dart' show AndroidSnapshotOptions, snapshotAndroid;

// ---------------------------------------------------------------------------
// Constants
// ---------------------------------------------------------------------------

final _androidBlockingModalPattern = RegExp(
  r"\bis(?:n(?:'|&apos;|&#39;)?t| not)\s+responding\b",
  caseSensitive: false,
);
final _androidCloseAppPattern = RegExp(r'^close app$', caseSensitive: false);
const int _androidModalPollMs = 500;
const int _androidModalPollAttempts = 12;
const String _androidBlockingDialogHint =
    'Wait for Android to recover, close the dialog, restart the app, or reboot the emulator, then retry.';

// ---------------------------------------------------------------------------
// Public types
// ---------------------------------------------------------------------------

/// Result of attempting to recover a blocking system dialog.
typedef AndroidBlockingDialogRecoveryResult = String; // 'absent' | 'recovered' | 'failed'

/// Result of checking dialog readiness before/after a command.
sealed class AndroidBlockingDialogReadinessResult {
  const AndroidBlockingDialogReadinessResult();
}

/// No blocking dialog was detected — the command may proceed.
class AndroidBlockingDialogClear extends AndroidBlockingDialogReadinessResult {
  const AndroidBlockingDialogClear();
}

/// An ANR was detected and auto-recovered — the command may proceed with a warning.
class AndroidBlockingDialogRecovered
    extends AndroidBlockingDialogReadinessResult {
  final String warning;
  const AndroidBlockingDialogRecovered({required this.warning});
}

// ---------------------------------------------------------------------------
// Session context
// ---------------------------------------------------------------------------

/// Minimal session context passed to system-dialog helpers.
///
/// Corresponds to the subset of `SessionState` consumed by
/// `android-system-dialog.ts`. In the Dart port there is no single
/// `SessionState` object; callers build this from [BackendCommandContext]
/// and, for [recording], from the on-disk recorder record.
class AndroidSystemDialogSession {
  /// ADB device serial.
  final String deviceId;

  /// Package name of the session's app, if one was opened.
  final String? appBundleId;

  /// Whether a recording is currently in progress for this session.
  final bool recording;

  /// Session name (used for diagnostics).
  final String? sessionName;

  const AndroidSystemDialogSession({
    required this.deviceId,
    this.appBundleId,
    this.recording = false,
    this.sessionName,
  });
}

// ---------------------------------------------------------------------------
// Public API
// ---------------------------------------------------------------------------

/// Attempt to recover a blocking system dialog during recording.
///
/// Only runs when [session.recording] is true. Finds the "Close App" button,
/// taps it, waits for the dialog to dismiss, then relaunches the session app.
///
/// Returns `'absent'` if no dialog was found, `'recovered'` on success,
/// or `'failed'` if any step fails.
///
/// Port of `recoverAndroidBlockingSystemDialog` in `android-system-dialog.ts`.
Future<AndroidBlockingDialogRecoveryResult> recoverAndroidBlockingSystemDialog(
  AndroidSystemDialogSession session,
) async {
  if (!session.recording) return 'absent';

  try {
    final nodes = await _readAndroidSnapshotNodes(session.deviceId);
    final closeAppButton = _findCloseAppButton(nodes);
    if (closeAppButton?.rect == null) return 'absent';

    final tapResult = await _tapAndroidDialogButton(
      session.deviceId,
      closeAppButton!,
    );
    if (!tapResult.ok) {
      emitDiagnostic(
        EmitDiagnosticOptions(
          level: DiagnosticLevel.warn,
          phase: 'android_blocking_dialog_tap_failed',
          data: {
            'session': session.sessionName,
            'deviceId': session.deviceId,
            'exitCode': tapResult.exitCode,
            'stdout': tapResult.stdout,
            'stderr': tapResult.stderr,
          },
        ),
      );
      return 'failed';
    }

    final dismissed = await _waitForBlockingDialogToDismiss(session.deviceId);
    if (!dismissed) {
      emitDiagnostic(
        EmitDiagnosticOptions(
          level: DiagnosticLevel.warn,
          phase: 'android_blocking_dialog_still_present',
          data: {
            'session': session.sessionName,
            'deviceId': session.deviceId,
          },
        ),
      );
      return 'failed';
    }

    if (session.appBundleId != null) {
      await openAndroidApp(session.deviceId, session.appBundleId!);
      final focused = await _waitForAndroidAppFocus(session, session.appBundleId!);
      if (!focused) {
        emitDiagnostic(
          EmitDiagnosticOptions(
            level: DiagnosticLevel.warn,
            phase: 'android_blocking_dialog_relaunch_unfocused',
            data: {
              'session': session.sessionName,
              'deviceId': session.deviceId,
              'appBundleId': session.appBundleId,
            },
          ),
        );
        return 'failed';
      }
    }

    emitDiagnostic(
      EmitDiagnosticOptions(
        level: DiagnosticLevel.warn,
        phase: 'android_blocking_dialog_recovered',
        data: {
          'session': session.sessionName,
          'deviceId': session.deviceId,
          'appBundleId': session.appBundleId,
          'x': tapResult.x,
          'y': tapResult.y,
        },
      ),
    );
    return 'recovered';
  } catch (error) {
    emitDiagnostic(
      EmitDiagnosticOptions(
        level: DiagnosticLevel.warn,
        phase: 'android_blocking_dialog_recovery_failed',
        data: {
          'session': session.sessionName,
          'deviceId': session.deviceId,
          'error': error is Error ? error.toString() : '$error',
        },
      ),
    );
    return 'failed';
  }
}

/// Ensure no blocking dialog is present before/after a command.
///
/// - If no blocking dialog is focused: returns [AndroidBlockingDialogClear].
/// - If the focused dialog belongs to the session app (ANR) and recovery
///   succeeds: returns [AndroidBlockingDialogRecovered] with a warning.
/// - Otherwise: throws [AppError] describing the blocking dialog.
///
/// Port of `ensureAndroidBlockingSystemDialogReady` in `android-system-dialog.ts`.
Future<AndroidBlockingDialogReadinessResult>
ensureAndroidBlockingSystemDialogReady({
  required AndroidSystemDialogSession session,
  required String command,
  required String phase, // 'before-command' | 'after-command'
}) async {
  final focus = await getAndroidBlockingDialogFocus(session.deviceId);
  if (focus == null) return const AndroidBlockingDialogClear();

  if (_isSessionAppAnr(session, focus)) {
    final recovered =
        await _recoverAppOwnedAndroidBlockingSystemDialogSafely(session);
    if (recovered) {
      final warning =
          'Recovered Android app ANR before $command: closed and relaunched ${session.appBundleId}.';
      if (phase == 'before-command') {
        return AndroidBlockingDialogRecovered(warning: warning);
      }
      throw _androidBlockingDialogError(
        session: session,
        command: command,
        focus: focus,
        message:
            'Android app ANR appeared after $command; ${session.appBundleId} was closed and relaunched. Retry the command against the fresh app session.',
        hint:
            'Retry the command. If the ANR returns, inspect app logs or restart the emulator.',
      );
    }

    throw _androidBlockingDialogError(
      session: session,
      command: command,
      focus: focus,
      message:
          'Android app ANR blocked $command: ${_formatAndroidBlockingDialogFocus(focus)}. Automatic recovery failed.',
      hint: _androidBlockingDialogHint,
    );
  }

  throw _androidBlockingDialogError(
    session: session,
    command: command,
    focus: focus,
    message:
        'Android system dialog is blocking $command: ${_formatAndroidBlockingDialogFocus(focus)}.',
    hint: _androidBlockingDialogHint,
  );
}

// ---------------------------------------------------------------------------
// Internal helpers
// ---------------------------------------------------------------------------

Future<bool> _recoverAppOwnedAndroidBlockingSystemDialogSafely(
  AndroidSystemDialogSession session,
) async {
  try {
    return await _recoverAppOwnedAndroidBlockingSystemDialog(session);
  } catch (error) {
    emitDiagnostic(
      EmitDiagnosticOptions(
        level: DiagnosticLevel.warn,
        phase: 'android_app_anr_recovery_failed',
        data: {
          'session': session.sessionName,
          'deviceId': session.deviceId,
          'appBundleId': session.appBundleId,
          'error': error is Error ? error.toString() : '$error',
        },
      ),
    );
    return false;
  }
}

bool _isSessionAppAnr(
  AndroidSystemDialogSession session,
  AndroidBlockingDialogFocus focus,
) {
  return session.appBundleId != null &&
      focus.package == session.appBundleId;
}

Future<bool> _recoverAppOwnedAndroidBlockingSystemDialog(
  AndroidSystemDialogSession session,
) async {
  if (session.appBundleId == null) return false;

  final nodes = await _readAndroidSnapshotNodes(session.deviceId);
  final closeAppButton = _findCloseAppButton(
    nodes,
    requireDialogSignal: false,
  );
  if (closeAppButton?.rect == null) return false;

  final tapResult = await _tapAndroidDialogButton(
    session.deviceId,
    closeAppButton!,
  );
  if (!tapResult.ok) return false;

  await openAndroidApp(session.deviceId, session.appBundleId!);
  final focused = await _waitForAndroidAppFocus(
    session,
    session.appBundleId!,
    requireNoBlockingDialog: true,
  );
  if (focused) {
    emitDiagnostic(
      EmitDiagnosticOptions(
        level: DiagnosticLevel.warn,
        phase: 'android_app_anr_recovered',
        data: {
          'session': session.sessionName,
          'deviceId': session.deviceId,
          'appBundleId': session.appBundleId,
          'x': tapResult.x,
          'y': tapResult.y,
        },
      ),
    );
  }
  return focused;
}

AppError _androidBlockingDialogError({
  required AndroidSystemDialogSession session,
  required String command,
  required AndroidBlockingDialogFocus focus,
  required String message,
  required String hint,
}) {
  return AppError(
    AppErrorCodes.commandFailed,
    message,
    details: <String, Object?>{
      'command': command,
      'expectedPackage': session.appBundleId,
      'focusedPackage': focus.package,
      'focusedWindow': focus.focusedWindow,
      'rawFocus': focus.raw,
      'hint': hint,
    },
  );
}

String _formatAndroidBlockingDialogFocus(AndroidBlockingDialogFocus focus) {
  return focus.package != null
      ? '${focus.focusedWindow} (package ${focus.package})'
      : focus.focusedWindow;
}

Future<List<SnapshotNode>> _readAndroidSnapshotNodes(String deviceId) async {
  final rawSnapshot = await snapshotAndroid(
    deviceId,
    options: const AndroidSnapshotOptions(
      snapshot: SnapshotOptions(interactiveOnly: false, compact: false),
    ),
  );
  return attachRefs(pruneGroupNodes(rawSnapshot.nodes));
}

/// Result of tapping a dialog button.
sealed class _DialogButtonTapResult {
  const _DialogButtonTapResult();

  bool get ok;
}

class _DialogButtonTapOk extends _DialogButtonTapResult {
  final double x;
  final double y;
  const _DialogButtonTapOk({required this.x, required this.y});

  @override
  bool get ok => true;
}

class _DialogButtonTapFailed extends _DialogButtonTapResult {
  final int exitCode;
  final String stdout;
  final String stderr;
  const _DialogButtonTapFailed({
    required this.exitCode,
    required this.stdout,
    required this.stderr,
  });

  @override
  bool get ok => false;
}

extension _TapResultCoords on _DialogButtonTapResult {
  double? get x => this is _DialogButtonTapOk
      ? (this as _DialogButtonTapOk).x
      : null;
  double? get y => this is _DialogButtonTapOk
      ? (this as _DialogButtonTapOk).y
      : null;
  int get exitCode => this is _DialogButtonTapFailed
      ? (this as _DialogButtonTapFailed).exitCode
      : 0;
  String get stdout => this is _DialogButtonTapFailed
      ? (this as _DialogButtonTapFailed).stdout
      : '';
  String get stderr => this is _DialogButtonTapFailed
      ? (this as _DialogButtonTapFailed).stderr
      : '';
}

Future<_DialogButtonTapResult> _tapAndroidDialogButton(
  String deviceId,
  SnapshotNode button,
) async {
  final rect = button.rect;
  if (rect == null) {
    return const _DialogButtonTapFailed(
      exitCode: 1,
      stdout: '',
      stderr: 'button has no rect',
    );
  }
  final center = centerOfRect(rect);
  final x = center.x;
  final y = center.y;
  final result = await runCmd(
    'adb',
    adbArgs(deviceId, [
      'shell',
      'input',
      'tap',
      '${x.round()}',
      '${y.round()}',
    ]),
    const ExecOptions(allowFailure: true),
  );
  if (result.exitCode != 0) {
    return _DialogButtonTapFailed(
      exitCode: result.exitCode,
      stdout: result.stdout.trim(),
      stderr: result.stderr.trim(),
    );
  }
  return _DialogButtonTapOk(x: x, y: y);
}

SnapshotNode? _findCloseAppButton(
  List<SnapshotNode> nodes, {
  bool requireDialogSignal = true,
}) {
  if (requireDialogSignal && !_containsBlockingDialog(nodes)) {
    return null;
  }
  for (final node in nodes) {
    if (_readNodeTextParts(node).any(
          (text) => _androidCloseAppPattern.hasMatch(text),
        ) &&
        node.rect != null) {
      return node;
    }
  }
  return null;
}

Future<bool> _waitForBlockingDialogToDismiss(String deviceId) async {
  for (var attempt = 0; attempt < _androidModalPollAttempts; attempt++) {
    final nodes = await _readAndroidSnapshotNodes(deviceId);
    if (!_containsBlockingDialog(nodes)) return true;
    await Future<void>.delayed(
      const Duration(milliseconds: _androidModalPollMs),
    );
  }
  final nodes = await _readAndroidSnapshotNodes(deviceId);
  return !_containsBlockingDialog(nodes);
}

Future<bool> _waitForAndroidAppFocus(
  AndroidSystemDialogSession session,
  String appBundleId, {
  bool requireNoBlockingDialog = false,
}) async {
  for (var attempt = 0; attempt < _androidModalPollAttempts; attempt++) {
    if (await _isAndroidAppFocused(
      session,
      appBundleId,
      requireNoBlockingDialog: requireNoBlockingDialog,
    )) {
      return true;
    }
    await Future<void>.delayed(
      const Duration(milliseconds: _androidModalPollMs),
    );
  }
  return _isAndroidAppFocused(
    session,
    appBundleId,
    requireNoBlockingDialog: requireNoBlockingDialog,
  );
}

Future<bool> _isAndroidAppFocused(
  AndroidSystemDialogSession session,
  String appBundleId, {
  bool requireNoBlockingDialog = false,
}) async {
  if (requireNoBlockingDialog) {
    final blocking = await getAndroidBlockingDialogFocus(session.deviceId);
    if (blocking != null) return false;
  }
  final state = await getAndroidAppState(session.deviceId);
  return state.package == appBundleId;
}

String _readNodeText(SnapshotNode node) {
  return _readNodeTextParts(node).join(' ').trim();
}

List<String> _readNodeTextParts(SnapshotNode node) {
  final parts = <String?>[];
  parts.add(node.label);
  parts.add(node.identifier);
  final value = node.value;
  if (value is String && value.trim().isNotEmpty) {
    parts.add(value);
  }
  return parts
      .whereType<String>()
      .where((part) => part.trim().isNotEmpty)
      .map((part) => part.trim())
      .toList();
}

bool _containsBlockingDialog(List<SnapshotNode> nodes) {
  return nodes.any((node) {
    final text = _readNodeText(node);
    return text.isNotEmpty && _androidBlockingModalPattern.hasMatch(text);
  });
}
