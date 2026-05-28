// Port of agent-device/src/platforms/fill-diagnostics.ts

import '../snapshot/snapshot.dart';

/// Cross-platform metadata for fill verification diagnostics.
///
/// Platform backends should populate whichever native identity fields they
/// have: iOS/macOS usually use [identifier], Android uses [resourceId] and
/// [packageName].
class FillDiagnosticNode {
  final String? text;
  final String? className;
  final String? identifier;
  final String? resourceId;
  final String? packageName;
  final Rect? rect;
  final bool? focused;
  final bool? password;
  final bool? inputMethodOwned;

  const FillDiagnosticNode({
    required this.text,
    this.className,
    this.identifier,
    this.resourceId,
    this.packageName,
    this.rect,
    this.focused,
    this.password,
    this.inputMethodOwned,
  });
}

/// Reason a fill verification failed.
enum FillFailureReason {
  imeCapture('ime_capture'),
  maskedUnverified('masked_unverified'),
  textMismatch('text_mismatch');

  final String value;
  const FillFailureReason(this.value);
}

/// Result of a fill verification pass.
class FillVerification<TNode extends FillDiagnosticNode> {
  final bool ok;
  final String? actual;
  final FillFailureReason? reason;
  final bool? masked;
  final TNode? targetInput;
  final TNode? actualInput;

  const FillVerification({
    required this.ok,
    required this.actual,
    this.reason,
    this.masked,
    this.targetInput,
    this.actualInput,
  });
}

/// A diagnostic details node — same as [FillDiagnosticNode] but text may be
/// redacted.
class FillDiagnosticDetailsNode<TNode extends FillDiagnosticNode> {
  final String? text;
  final bool? textRedacted;
  final TNode source;

  const FillDiagnosticDetailsNode({
    required this.source,
    required this.text,
    this.textRedacted,
  });
}

/// Combined failure details returned in error payloads.
class FillFailureDetails<TNode extends FillDiagnosticNode> {
  final FillFailureReason failureReason;
  final FillDiagnosticDetailsNode<TNode>? targetInput;
  final FillDiagnosticDetailsNode<TNode>? actualInput;
  String? hint;

  // Unmasked variant
  final String? expected;
  final String? actual;

  // Masked variant
  final int? expectedLength;
  final bool? masked;
  final int? actualLength;

  FillFailureDetails.unmasked({
    required this.failureReason,
    required this.targetInput,
    required this.actualInput,
    required this.expected,
    required this.actual,
    this.hint,
  })  : expectedLength = null,
        masked = null,
        actualLength = null;

  FillFailureDetails.masked({
    required this.failureReason,
    required this.targetInput,
    required this.actualInput,
    required this.expectedLength,
    required this.actualLength,
    this.hint,
  })  : expected = null,
        actual = null,
        masked = true;
}

/// Build a [FillFailureDetails] from an expected value and verification result.
FillFailureDetails<TNode> buildFillFailureDetails<TNode extends FillDiagnosticNode>(
  String expected,
  FillVerification<TNode>? verification,
) {
  if (verification == null) {
    return FillFailureDetails.unmasked(
      failureReason: FillFailureReason.textMismatch,
      targetInput: null,
      actualInput: null,
      expected: expected,
      actual: null,
    );
  }

  final sensitive = _isSensitiveFillVerification(verification);
  final failureReason = verification.reason ?? FillFailureReason.textMismatch;
  final targetInputNode = _toFillDiagnosticNode(verification.targetInput);
  final actualInputNode = _toFillDiagnosticNode(verification.actualInput);

  if (sensitive) {
    return FillFailureDetails.masked(
      failureReason: failureReason,
      targetInput: targetInputNode,
      actualInput: actualInputNode,
      expectedLength: expected.runes.length,
      actualLength: (verification.actual ?? '').runes.length,
    );
  }
  return FillFailureDetails.unmasked(
    failureReason: failureReason,
    targetInput: targetInputNode,
    actualInput: actualInputNode,
    expected: expected,
    actual: verification.actual,
  );
}

/// Whether a [FillDiagnosticNode] contains sensitive (masked/password) text.
bool isSensitiveFillDiagnosticNode(FillDiagnosticNode? node) {
  if (node == null) return false;
  if (node.password == true) return true;
  return _isMaskedFillText(node.text);
}

bool _isMaskedFillText(String? text) {
  if (text == null || text.isEmpty) return false;
  return text.runes.every(_isMaskCharacter);
}

FillDiagnosticDetailsNode<TNode>? _toFillDiagnosticNode<TNode extends FillDiagnosticNode>(
  TNode? node,
) {
  if (node == null) return null;
  final textRedacted = isSensitiveFillDiagnosticNode(node);
  return FillDiagnosticDetailsNode(
    source: node,
    text: textRedacted ? null : node.text,
    textRedacted: textRedacted ? true : null,
  );
}

bool _isMaskCharacter(int codePoint) {
  // Deliberately conservative: expand only for observed platform masks.
  return codePoint == 0x2022 || // •
      codePoint == 0x002A || // *
      codePoint == 0x25CF; // ●
}

bool _isSensitiveFillVerification(FillVerification verification) {
  return verification.masked == true ||
      isSensitiveFillDiagnosticNode(verification.targetInput) ||
      isSensitiveFillDiagnosticNode(verification.actualInput);
}
