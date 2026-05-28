// Port of agent-device/src/platforms/android/fill-verification.ts

import '../../snapshot/snapshot.dart';
import '../../utils/diagnostics.dart';
import '../../utils/timeouts.dart';
import '../fill_diagnostics.dart';
import 'device_input_state.dart';
import 'input_ownership.dart';
import 'snapshot.dart';
import 'ui_hierarchy.dart';

/// Android-specific fill verification result node.
///
/// Extends [FillDiagnosticNode] with Android-specific fields ([rect], [area]).
/// The [focused], [password], and [inputMethodOwned] fields from the parent
/// are always non-null for Android nodes — pass them as required in the
/// constructor and they are stored via the parent's nullable fields.
class AndroidFillVerificationNode extends FillDiagnosticNode {
  // Non-null rect is required for Android verification nodes.
  // Stored via super.rect which is Rect? — callers should use [verificationRect].
  final int area;

  const AndroidFillVerificationNode({
    required super.text,
    required super.className,
    required super.resourceId,
    required super.packageName,
    required Rect rect,
    required bool focused,
    required bool password,
    required bool inputMethodOwned,
    required this.area,
    super.identifier,
  }) : super(
          rect: rect,
          focused: focused,
          password: password,
          inputMethodOwned: inputMethodOwned,
        );

  /// The bounding rect — guaranteed non-null for Android verification nodes.
  Rect get verificationRect => rect!;
}

/// Fill verification result for Android.
typedef AndroidFillVerification
    = FillVerification<AndroidFillVerificationNode>;

class _AndroidFillVerificationCandidate extends AndroidFillVerificationNode {
  final bool editText;

  const _AndroidFillVerificationCandidate({
    required super.text,
    required super.className,
    required super.resourceId,
    required super.packageName,
    required super.rect,
    required super.focused,
    required super.password,
    required super.inputMethodOwned,
    required super.area,
    required this.editText,
  });
}

class _AndroidTextAtPointInspection {
  final AndroidFillVerificationNode? targetInput;
  final AndroidFillVerificationNode? actualInput;

  const _AndroidTextAtPointInspection({
    required this.targetInput,
    required this.actualInput,
  });
}

class _AndroidTextAtPointScan {
  _AndroidFillVerificationCandidate? focusedEdit;
  _AndroidFillVerificationCandidate? editAtPoint;
  _AndroidFillVerificationCandidate? anyAtPoint;

  _AndroidTextAtPointScan();
}

class AndroidFillVerificationContext {
  final String? activeInputMethodPackage;

  const AndroidFillVerificationContext({this.activeInputMethodPackage});
}

/// Verify that Android fill put the expected text into the field at (x, y).
///
/// Retries with exponential delays to allow for IME settling.
Future<AndroidFillVerification> verifyAndroidFilledText(
  String serial,
  int x,
  int y,
  String expected,
) async {
  const verificationDelaysMs = [0, 150, 350];
  AndroidFillVerification? lastVerification;
  AndroidFillVerification? stableVerification;
  final context = await _readAndroidFillVerificationContext(serial);

  for (final delayMs in verificationDelaysMs) {
    if (delayMs > 0) {
      await sleep(Duration(milliseconds: delayMs));
    }
    final verification = await _inspectAndroidFilledText(
      serial,
      x,
      y,
      expected,
      context,
    );
    lastVerification = verification;
    if (verification.reason == FillFailureReason.imeCapture) {
      return verification;
    }
    if (verification.ok) {
      stableVerification = verification;
    } else {
      stableVerification = null;
    }
  }

  return stableVerification ??
      lastVerification ??
      const FillVerification(
        ok: false,
        actual: null,
        reason: FillFailureReason.textMismatch,
        targetInput: null,
        actualInput: null,
      );
}

/// Read text at (x, y) from the live UI hierarchy.
Future<String?> readAndroidTextAtPoint(String serial, int x, int y) async {
  return readAndroidTextAtPointInHierarchy(
    await dumpUiHierarchy(serial),
    x,
    y,
  );
}

/// Verify fill in a captured XML hierarchy string.
AndroidFillVerification verifyAndroidFilledTextInHierarchy(
  String xml,
  int x,
  int y,
  String expected, {
  AndroidFillVerificationContext context =
      const AndroidFillVerificationContext(),
}) {
  final inspection = _inspectAndroidTextAtPointInHierarchy(xml, x, y, context);
  if (_isAndroidImeCapture(inspection)) {
    return FillVerification(
      ok: false,
      actual: inspection.actualInput?.text,
      reason: FillFailureReason.imeCapture,
      targetInput: inspection.targetInput,
      actualInput: inspection.actualInput,
    );
  }

  return _maskedAndroidFillVerification(inspection, expected) ??
      _textAndroidFillVerification(inspection, expected);
}

/// Read text at (x, y) from a captured XML hierarchy string.
String? readAndroidTextAtPointInHierarchy(String xml, int x, int y) {
  return _inspectAndroidTextAtPointInHierarchy(xml, x, y).actualInput?.text;
}

/// Human-readable fill failure message for [verification].
String androidFillFailureMessage(AndroidFillVerification? verification) {
  if (verification?.reason == FillFailureReason.imeCapture) {
    return 'Android fill input was captured by the active keyboard instead of the app field';
  }
  if (verification?.reason == FillFailureReason.maskedUnverified) {
    return 'Android fill verification could not confirm masked text value';
  }
  return 'Android fill verification failed';
}

/// Build structured failure details for an [AndroidFillVerification].
FillFailureDetails<AndroidFillVerificationNode> androidFillFailureDetails(
  String expected,
  AndroidFillVerification? verification,
) {
  final details = buildFillFailureDetails(expected, verification);
  if (verification?.reason == FillFailureReason.imeCapture) {
    details.hint =
        'The focused input belongs to the Android keyboard/IME, not the app field. '
        'Disable handwriting/stylus input or switch to a standard IME, then retry fill.';
  }
  return details;
}

// ===== Private helpers =====

Future<AndroidFillVerification> _inspectAndroidFilledText(
  String serial,
  int x,
  int y,
  String expected,
  AndroidFillVerificationContext context,
) async {
  return verifyAndroidFilledTextInHierarchy(
    await dumpUiHierarchy(serial),
    x,
    y,
    expected,
    context: context,
  );
}

_AndroidTextAtPointInspection _inspectAndroidTextAtPointInHierarchy(
  String xml,
  int x,
  int y, [
  AndroidFillVerificationContext context =
      const AndroidFillVerificationContext(),
]) {
  final scan = _AndroidTextAtPointScan();

  for (final node in androidUiNodes(xml)) {
    final candidate = _androidFillCandidateFromNode(node, context);
    if (candidate != null) {
      _updateAndroidTextAtPointScan(scan, candidate, x, y);
    }
  }

  return _androidTextAtPointInspection(scan);
}

bool _isAndroidImeCapture(_AndroidTextAtPointInspection inspection) {
  final targetInput = inspection.targetInput;
  final actualInput = inspection.actualInput;
  if (targetInput == null || actualInput == null) return false;
  if (identical(actualInput, targetInput)) return false;
  return (actualInput.inputMethodOwned ?? false) &&
      !(targetInput.inputMethodOwned ?? false);
}

AndroidFillVerification? _maskedAndroidFillVerification(
  _AndroidTextAtPointInspection inspection,
  String expected,
) {
  final actualInput = inspection.actualInput;
  if (actualInput == null || !_isMaskedAndroidInput(actualInput)) return null;
  final actual = actualInput.text;
  final actualLength = (actual ?? '').runes.length;
  final expectedLength = expected.runes.length;
  final matched = actual != null &&
      actualLength > 0 &&
      expectedLength > 0 &&
      actualLength == expectedLength;
  return FillVerification(
    ok: matched,
    actual: actual,
    reason: matched ? null : FillFailureReason.maskedUnverified,
    masked: true,
    targetInput: inspection.targetInput,
    actualInput: actualInput,
  );
}

AndroidFillVerification _textAndroidFillVerification(
  _AndroidTextAtPointInspection inspection,
  String expected,
) {
  final actual = inspection.actualInput?.text;
  return FillVerification(
    ok: _isAcceptableAndroidFillMatch(actual, expected),
    actual: actual,
    reason: FillFailureReason.textMismatch,
    targetInput: inspection.targetInput,
    actualInput: inspection.actualInput,
  );
}

bool _isAcceptableAndroidFillMatch(String? actual, String expected) {
  if (actual == expected) return true;
  final normalizedActual = _normalizeFillVerificationText(actual);
  final normalizedExpected = _normalizeFillVerificationText(expected);
  if (normalizedActual.isEmpty || normalizedExpected.isEmpty) return false;
  if (normalizedActual == normalizedExpected) return true;
  if (_isSentenceAutocapitalizeMatch(normalizedActual, normalizedExpected)) {
    return true;
  }
  return false;
}

String _normalizeFillVerificationText(String? value) {
  return (value ?? '').replaceAll(RegExp(r'\s+'), ' ').trim();
}

bool _isSentenceAutocapitalizeMatch(String actual, String expected) {
  if (actual.length != expected.length || actual.isEmpty) return false;
  if (actual.substring(1) != expected.substring(1)) return false;
  final actualFirst = actual[0];
  final expectedFirst = expected[0];
  return expectedFirst == expectedFirst.toLowerCase() &&
      actualFirst == expectedFirst.toUpperCase();
}

_AndroidFillVerificationCandidate? _androidFillCandidateFromNode(
  AndroidUiNodeMetadata node,
  AndroidFillVerificationContext context,
) {
  final rect = node.rect;
  if (rect == null) return null;
  final text = node.text ?? '';
  final area = (rect.width * rect.height).abs().clamp(1.0, double.infinity).toInt();
  return _AndroidFillVerificationCandidate(
    text: text.isNotEmpty ? text : null,
    className: node.className,
    resourceId: node.resourceId,
    packageName: node.packageName,
    rect: rect,
    focused: node.focused ?? false,
    password: node.password == true,
    inputMethodOwned: isAndroidInputMethodOwnedNode(
      packageName: node.packageName,
      resourceId: node.resourceId,
      activeInputMethodPackage: context.activeInputMethodPackage,
    ),
    area: area,
    editText: _isEditTextClass(node.className ?? ''),
  );
}

Future<AndroidFillVerificationContext> _readAndroidFillVerificationContext(
  String serial,
) async {
  try {
    final state = await getAndroidKeyboardState(serial);
    return AndroidFillVerificationContext(
      activeInputMethodPackage: state.inputMethodPackage,
    );
  } catch (error) {
    emitDiagnostic(
      EmitDiagnosticOptions(
        level: DiagnosticLevel.warn,
        phase: 'android_fill_verification_input_method_probe_failed',
        data: {
          'error': error is Exception ? error.toString() : error.toString(),
        },
      ),
    );
    return const AndroidFillVerificationContext();
  }
}

void _updateAndroidTextAtPointScan(
  _AndroidTextAtPointScan scan,
  _AndroidFillVerificationCandidate candidate,
  int x,
  int y,
) {
  final containsPoint = _containsAndroidPoint(candidate.verificationRect, x, y);
  if (containsPoint && candidate.editText) {
    scan.editAtPoint = _smallerAndroidFillCandidate(
      scan.editAtPoint,
      candidate,
    );
  }
  if ((candidate.focused ?? false) && candidate.editText) {
    scan.focusedEdit = _smallerAndroidFillCandidate(
      scan.focusedEdit,
      candidate,
    );
    return;
  }
  if (containsPoint && candidate.text != null) {
    scan.anyAtPoint = _smallerAndroidFillCandidate(
      scan.anyAtPoint,
      candidate,
    );
  }
}

bool _containsAndroidPoint(Rect rect, int x, int y) {
  return x >= rect.x &&
      x <= rect.x + rect.width &&
      y >= rect.y &&
      y <= rect.y + rect.height;
}

_AndroidFillVerificationCandidate _smallerAndroidFillCandidate(
  _AndroidFillVerificationCandidate? current,
  _AndroidFillVerificationCandidate next,
) {
  return current != null && current.area < next.area ? current : next;
}

_AndroidTextAtPointInspection _androidTextAtPointInspection(
  _AndroidTextAtPointScan scan,
) {
  final targetInput = scan.editAtPoint ?? scan.anyAtPoint;
  final focusedInput =
      (scan.focusedEdit?.text != null) ? scan.focusedEdit : null;
  return _AndroidTextAtPointInspection(
    targetInput: targetInput,
    actualInput: focusedInput ?? targetInput,
  );
}

bool _isEditTextClass(String className) {
  final lower = className.toLowerCase();
  return lower.contains('edittext') || lower.contains('textfield');
}

bool _isMaskedAndroidInput(AndroidFillVerificationNode node) {
  return isSensitiveFillDiagnosticNode(node);
}
