// Port of agent-device/src/platforms/ios/runner-failure-diagnostics.ts
// (commits 4f0886d1 + 8de4dddd). Classifies a failed iOS runner command from
// the tail of the runner log so a target-app crash surfaces as
// IOS_TARGET_APP_CRASH with an actionable hint, instead of a generic failure.

import 'dart:convert';
import 'dart:io';

import '../../utils/errors.dart';

const int _runnerLogTailBytes = 64 * 1024;

class _RunnerFailureDiagnostic {
  final String? code;
  final String reason;
  final String hint;

  const _RunnerFailureDiagnostic({
    this.code,
    required this.reason,
    required this.hint,
  });
}

const String _iosTargetAxCrashHint =
    'The target iOS app appears to have crashed while XCTest/AXRuntime read '
    'accessibility attributes. This is usually a simulator/XCTest/runtime or '
    'app accessibility payload issue, not a text-entry failure. Reproduce on '
    'the latest stable simulator runtime, reinstall the app, and capture the '
    'app crash from Console.app or ~/Library/Logs/DiagnosticReports with the '
    'exact command, selector/ref, app build, Xcode, and simulator runtime.';

const String _iosTargetAppCrashHint =
    'The target iOS app appears to have crashed while the runner was executing '
    'the command. Reopen or reinstall the app, retry on a fresh/latest stable '
    'simulator runtime, and capture the app crash from Console.app or '
    '~/Library/Logs/DiagnosticReports with the exact command, selector/ref, '
    'app build, Xcode, and simulator runtime.';

/// Enrich [error] with crash diagnostics derived from the runner log at
/// [logPath]. Returns the original error unchanged when there is no log or no
/// crash evidence; otherwise returns a new [AppError] with a (possibly
/// reclassified) code, an appended `hint`, and a `runnerFailureReason`.
Future<AppError> enrichRunnerFailureFromLog({
  required AppError error,
  String? logPath,
}) async {
  final diagnostic = await _resolveRunnerFailureDiagnostic(logPath);
  if (diagnostic == null) return error;

  final existingDetails = error.details ?? const <String, Object?>{};
  final existingHint = existingDetails['hint'];
  return AppError(
    diagnostic.code ?? error.code,
    error.message,
    details: {
      ...existingDetails,
      'hint': existingHint is String
          ? '$existingHint ${diagnostic.hint}'
          : diagnostic.hint,
      'runnerFailureReason': diagnostic.reason,
    },
    cause: error,
  );
}

Future<_RunnerFailureDiagnostic?> _resolveRunnerFailureDiagnostic(
  String? logPath,
) async {
  if (logPath == null || logPath.isEmpty) return null;
  final tail = await _readFileTail(logPath, _runnerLogTailBytes);
  if (tail == null) return null;
  return _classifyRunnerFailureLog(tail);
}

_RunnerFailureDiagnostic? _classifyRunnerFailureLog(String logText) {
  final normalized = logText.toLowerCase();
  if (_isAxRuntimeAccessibilityCrash(normalized)) {
    return const _RunnerFailureDiagnostic(
      code: AppErrorCodes.iosTargetAppCrash,
      reason: 'target_app_axruntime_coretext_crash',
      hint: _iosTargetAxCrashHint,
    );
  }
  if (_isTargetAppCrash(normalized)) {
    return const _RunnerFailureDiagnostic(
      code: AppErrorCodes.iosTargetAppCrash,
      reason: 'target_app_crash',
      hint: _iosTargetAppCrashHint,
    );
  }
  return null;
}

bool _isAxRuntimeAccessibilityCrash(String normalized) {
  return normalized.contains('axruntime') &&
      normalized.contains('coretext') &&
      (normalized.contains('attributesforelement') ||
          normalized.contains('axuielementcopymultipleattributevalues') ||
          normalized.contains('reconstitutedsmuggledctfontfromdictionary') ||
          normalized.contains(
            'reconstitutedsmuggledattributedstringfromdictionary',
          ));
}

// Tightened in 8de4dddd: dropped the loose `crashed` + `xctest` heuristic to
// avoid misclassifying ordinary XCTest-recorded failures as app crashes.
bool _isTargetAppCrash(String normalized) {
  return normalized.contains('process crashed') ||
      normalized.contains('the application under test') ||
      normalized.contains('terminated unexpectedly') ||
      (normalized.contains('exception type:') &&
          normalized.contains('thread 0 crashed'));
}

Future<String?> _readFileTail(String filePath, int maxBytes) async {
  RandomAccessFile? handle;
  try {
    final file = File(filePath);
    final size = await file.length();
    final start = size - maxBytes < 0 ? 0 : size - maxBytes;
    final length = size - start;
    if (length <= 0) return null;

    handle = await file.open();
    await handle.setPosition(start);
    final bytes = await handle.read(length);
    return utf8.decode(bytes, allowMalformed: true);
  } catch (_) {
    return null;
  } finally {
    await handle?.close();
  }
}
