// Port of agent-device/src/platforms/android/input-actions.ts

import 'dart:async';

import '../../core/device_rotation.dart';
import '../../core/scroll_gesture.dart';
import '../../utils/diagnostics.dart';
import '../../utils/errors.dart';
import '../../utils/exec.dart';
import '../../utils/timeouts.dart';
import 'adb.dart';
import 'device_input_state.dart';
import 'fill_verification.dart' as fill_verification;
import 'input_ownership.dart';

/// Tap at the specified coordinates.
Future<void> pressAndroid(String serial, int x, int y) async {
  await runCmd(
    'adb',
    adbArgs(serial, ['shell', 'input', 'tap', x.toString(), y.toString()]),
  );
}

/// Swipe from (x1, y1) to (x2, y2) over the specified duration.
Future<void> swipeAndroid(
  String serial,
  int x1,
  int y1,
  int x2,
  int y2, [
  int durationMs = 250,
]) async {
  await runCmd(
    'adb',
    adbArgs(serial, [
      'shell',
      'input',
      'swipe',
      x1.toString(),
      y1.toString(),
      x2.toString(),
      y2.toString(),
      durationMs.toString(),
    ]),
  );
}

/// Press the back button.
Future<void> backAndroid(String serial) async {
  await runCmd('adb', adbArgs(serial, ['shell', 'input', 'keyevent', '4']));
}

/// Press the home button.
Future<void> homeAndroid(String serial) async {
  await runCmd('adb', adbArgs(serial, ['shell', 'input', 'keyevent', '3']));
}

/// Rotate the device to the specified orientation.
Future<void> rotateAndroid(String serial, DeviceRotation orientation) async {
  final userRotation = _resolveAndroidUserRotation(orientation);
  await runCmd(
    'adb',
    adbArgs(serial, [
      'shell',
      'settings',
      'put',
      'system',
      'accelerometer_rotation',
      '0',
    ]),
  );
  await runCmd(
    'adb',
    adbArgs(serial, [
      'shell',
      'settings',
      'put',
      'system',
      'user_rotation',
      userRotation,
    ]),
  );
}

/// Press the app switcher button.
Future<void> appSwitcherAndroid(String serial) async {
  await runCmd('adb', adbArgs(serial, ['shell', 'input', 'keyevent', '187']));
}

/// Long press at the specified coordinates.
Future<void> longPressAndroid(
  String serial,
  int x,
  int y, [
  int durationMs = 800,
]) async {
  await runCmd(
    'adb',
    adbArgs(serial, [
      'shell',
      'input',
      'swipe',
      x.toString(),
      y.toString(),
      x.toString(),
      y.toString(),
      durationMs.toString(),
    ]),
  );
}

/// Type text with optional per-character delay.
Future<void> typeAndroid(String serial, String text, [int delayMs = 0]) async {
  _assertAndroidShellTextSupported(text);
  await _assertAndroidShellInputIsAppOwned(serial, 'type');
  if (delayMs > 0 && text.runes.length > 1) {
    await _typeAndroidShell(serial, 'type', text, 1, delayMs);
    return;
  }
  await _typeAndroidShell(serial, 'type', text, _androidInputTextChunkSize, 0);
}

/// Focus on the specified coordinates (equivalent to press).
Future<void> focusAndroid(String serial, int x, int y) async {
  await pressAndroid(serial, x, y);
}

/// Fill a text field by focusing, clearing, and typing text.
Future<void> fillAndroid(
  String serial,
  int x,
  int y,
  String text, [
  int delayMs = 0,
]) async {
  _assertAndroidShellTextSupported(text);

  final textCodePointLength = text.runes.length;
  final attempts =
      <
        ({
          int clearPadding,
          int minClear,
          int maxClear,
          int chunkSize,
          int inputDelayMs,
        })
      >[
        (
          clearPadding: 12,
          minClear: 8,
          maxClear: 48,
          chunkSize: delayMs > 0 ? 1 : _androidInputTextChunkSize,
          inputDelayMs: delayMs,
        ),
        (
          clearPadding: 24,
          minClear: 16,
          maxClear: 96,
          chunkSize: delayMs > 0 ? 1 : 4,
          inputDelayMs: delayMs > 0 ? delayMs : 15,
        ),
      ];

  fill_verification.AndroidFillVerification? lastVerification;

  for (final attempt in attempts) {
    await focusAndroid(serial, x, y);
    final clearCount = _clampCount(
      textCodePointLength + attempt.clearPadding,
      attempt.minClear,
      attempt.maxClear,
    );
    await _clearFocusedText(serial, clearCount);
    await _typeAndroidShell(
      serial,
      'fill',
      text,
      attempt.chunkSize,
      attempt.inputDelayMs,
    );
    final verification = await fill_verification.verifyAndroidFilledText(
      serial,
      x,
      y,
      text,
    );
    lastVerification = verification;
    if (verification.ok) return;
  }

  final failureMsg = fill_verification.androidFillFailureMessage(
    lastVerification,
  );
  throw AppError(
    AppErrorCodes.commandFailed,
    failureMsg,
    details: {
      'expected': text,
      'actual': lastVerification?.actual,
    },
  );
}

/// Scroll in the specified direction with optional amount or pixel override.
Future<Map<String, Object?>> scrollAndroid(
  String serial,
  ScrollDirection direction, {
  double? amount,
  double? pixels,
  int? durationMs,
}) async {
  final size = await getAndroidScreenSize(serial);
  final plan = buildScrollGesturePlan(
    ScrollGestureOptions(
      direction: direction,
      amount: amount,
      pixels: pixels,
      referenceWidth: size['width']!,
      referenceHeight: size['height']!,
    ),
  );

  // `adb shell input swipe` takes the gesture duration in ms; default to 300
  // when the caller does not request one.
  final swipeDurationMs = durationMs ?? 300;
  await runCmd(
    'adb',
    adbArgs(serial, [
      'shell',
      'input',
      'swipe',
      plan.x1.toString(),
      plan.y1.toString(),
      plan.x2.toString(),
      plan.y2.toString(),
      swipeDurationMs.toString(),
    ]),
  );

  return {
    'direction': plan.direction.value,
    'x1': plan.x1,
    'y1': plan.y1,
    'x2': plan.x2,
    'y2': plan.y2,
    'pixels': plan.pixels,
    'durationMs': swipeDurationMs,
    'referenceWidth': plan.referenceWidth,
    'referenceHeight': plan.referenceHeight,
  };
}

/// Get the physical screen size.
Future<Map<String, int>> getAndroidScreenSize(String serial) async {
  final result = await runCmd('adb', adbArgs(serial, ['shell', 'wm', 'size']));
  final match = RegExp(
    r'Physical size:\s*(\d+)x(\d+)',
  ).firstMatch(result.stdout);
  if (match == null) {
    throw AppError(AppErrorCodes.commandFailed, 'Unable to read screen size');
  }
  return {
    'width': int.parse(match.group(1)!),
    'height': int.parse(match.group(2)!),
  };
}

/// Read text content at the specified point from the UI hierarchy.
Future<String?> readAndroidTextAtPoint(String serial, int x, int y) {
  return fill_verification.readAndroidTextAtPoint(serial, x, y);
}

// ===== Private helpers =====

const int _androidInputTextChunkSize = 8;

String _resolveAndroidUserRotation(DeviceRotation orientation) {
  return switch (orientation) {
    DeviceRotation.portrait => '0',
    DeviceRotation.landscapeLeft => '1',
    DeviceRotation.portraitUpsideDown => '2',
    DeviceRotation.landscapeRight => '3',
  };
}

Future<void> _assertAndroidShellInputIsAppOwned(
  String serial,
  String action,
) async {
  AndroidKeyboardState state;
  try {
    state = await getAndroidKeyboardState(serial);
  } catch (error) {
    emitDiagnostic(
      EmitDiagnosticOptions(
        level: DiagnosticLevel.warn,
        phase: 'android_input_ownership_probe_failed',
        data: {
          'action': action,
          'error': error is Exception
              ? error.toString()
              : String.fromCharCode(error as int),
        },
      ),
    );
    return;
  }
  if (state.inputOwner != AndroidInputOwner.ime) return;
  throw AppError(
    AppErrorCodes.commandFailed,
    'KEYBOARD_OVERLAY_BLOCKING: Android text input is blocked because the focused input belongs to the active keyboard/IME.',
    details: {
      'failureReason': 'ime_capture',
      'action': action,
      'inputOwner': state.inputOwner.value,
      'inputType': state.inputType,
      'type': state.type?.value,
      'inputMethodPackage': state.inputMethodPackage,
      'focusedPackage': state.focusedPackage,
      'focusedResourceId': state.focusedResourceId,
      'nextAction':
          'Focused input appears to be owned by the keyboard/IME; dismiss or change the IME before retrying text entry.',
    },
  );
}

Future<void> _typeAndroidShell(
  String serial,
  String action,
  String text,
  int chunkSize,
  int delayMs,
) async {
  final parts = text.split('\n');
  for (int partIndex = 0; partIndex < parts.length; partIndex++) {
    final part = parts[partIndex];
    final chunks = _chunkAndroidInputText(part, chunkSize);
    for (int chunkIndex = 0; chunkIndex < chunks.length; chunkIndex++) {
      final chunk = chunks[chunkIndex];
      await _typeAndroidShellChunk(serial, chunk);
      if (delayMs > 0 &&
          (chunkIndex + 1 < chunks.length || partIndex + 1 < parts.length)) {
        await sleep(Duration(milliseconds: delayMs));
      }
    }
    if (partIndex + 1 < parts.length) {
      await runCmd(
        'adb',
        adbArgs(serial, ['shell', 'input', 'keyevent', 'ENTER']),
      );
    }
  }
  _emitAndroidTextDiagnostic(action, 'adb-shell', text);
}

Future<void> _typeAndroidShellChunk(String serial, String text) async {
  if (text.isEmpty) return;
  try {
    await runCmd(
      'adb',
      adbArgs(serial, [
        'shell',
        'input',
        'text',
        _encodeAndroidInputText(text),
      ]),
    );
  } catch (error) {
    if (_isAndroidInputTextUnsupported(error)) {
      throw _unsupportedAndroidShellTextError(text, error);
    }
    rethrow;
  }
}

void _assertAndroidShellTextSupported(String text) {
  if (_isAndroidShellTextSupported(text)) return;
  throw _unsupportedAndroidShellTextError(text);
}

bool _isAndroidShellTextSupported(String text) {
  for (final char in text.runes) {
    final code = char;
    if (code == 0x0A) continue; // newline
    if (code < 0x20 || code > 0x7e) {
      return false;
    }
  }
  return true;
}

String _encodeAndroidInputText(String text) {
  return text.replaceAll(' ', '%s');
}

bool _isAndroidInputTextUnsupported(Object error) {
  if (error is! AppError) return false;
  if (error.code != AppErrorCodes.commandFailed) return false;
  final rawStderr = error.details?['stderr'];
  final stderr = (rawStderr is String ? rawStderr : '').toLowerCase();
  if (stderr.contains("exception occurred while executing 'text'")) return true;
  if (stderr.contains('nullpointerexception') &&
      stderr.contains('inputshellcommand.sendtext')) {
    return true;
  }
  return false;
}

AppError _unsupportedAndroidShellTextError(String text, [Object? cause]) {
  return AppError(
    AppErrorCodes.commandFailed,
    'Android text input requires provider-native text injection for non-ASCII/control characters; the current adb-shell fallback supports ASCII text only.',
    details: {
      'backend': 'adb-shell',
      'textLength': text.runes.length,
      'textPreview': text.substring(0, text.length.clamp(0, 32)),
    },
    cause: cause is Exception ? cause : null,
  );
}

List<String> _chunkAndroidInputText(String text, int chunkSize) {
  final size = chunkSize.clamp(1, double.infinity).toInt();
  final chunks = <String>[];
  final chars = text.runes.map((r) => String.fromCharCode(r)).toList();
  for (int i = 0; i < chars.length; i += size) {
    chunks.add(chars.sublist(i, (i + size).clamp(0, chars.length)).join());
  }
  return chunks.isNotEmpty ? chunks : [''];
}

void _emitAndroidTextDiagnostic(String action, String backend, String text) {
  emitDiagnostic(
    EmitDiagnosticOptions(
      phase: 'android_text_injection',
      data: {
        'action': action,
        'backend': backend,
        'textLength': text.runes.length,
      },
    ),
  );
}

Future<void> _clearFocusedText(String serial, int count) async {
  final deletes = (count).clamp(0, double.infinity).toInt();
  await runCmd(
    'adb',
    adbArgs(serial, ['shell', 'input', 'keyevent', 'KEYCODE_MOVE_END']),
    const ExecOptions(allowFailure: true),
  );
  const batchSize = 24;
  for (int i = 0; i < deletes; i += batchSize) {
    final size = (batchSize).clamp(0, deletes - i);
    final keyEvents = List<String>.filled(size, 'KEYCODE_DEL');
    await runCmd(
      'adb',
      adbArgs(serial, ['shell', 'input', 'keyevent', ...keyEvents]),
      const ExecOptions(allowFailure: true),
    );
  }
}

int _clampCount(int value, int min, int max) {
  return value.clamp(min, max);
}
