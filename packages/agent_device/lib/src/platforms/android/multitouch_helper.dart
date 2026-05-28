// Port of agent-device/src/platforms/android/multitouch-helper.ts
//
// Deviations from upstream:
// - Remote manifest fetch is omitted; the Dart port always uses the locally
//   bundled APK under `android-multitouch-helper/` (mirrors snapshot helper).
// - `crypto` hash uses `package:crypto` (sha256 streamed from file).
// - SHA-256 verification mirrors snapshot_helper_artifact.dart pattern.
// - `installAndroidAdbPackage` maps to `adb(['install', '-r', '-t', apkPath])`.
// - `resolveAndroidTouchInjector` (provider override) is not ported — the
//   Dart backend always calls the built-in multitouch helper directly.

import 'dart:convert';
import 'dart:io';

import 'package:agent_device/src/native/resolve.dart';
import 'package:agent_device/src/utils/errors.dart';
import 'package:agent_device/src/utils/exec.dart';
import 'package:crypto/crypto.dart';
import 'package:meta/meta.dart';
import 'package:path/path.dart' as p;

import 'adb.dart';
import 'snapshot_helper_types.dart';

// ---------------------------------------------------------------------------
// Constants
// ---------------------------------------------------------------------------

const _kMultitouchHelperName = 'android-multitouch-helper';
const _kMultitouchHelperPackage =
    'com.callstack.agentdevice.multitouchhelper';
const _kMultitouchHelperRunner =
    'com.callstack.agentdevice.multitouchhelper/.MultiTouchInstrumentation';
const _kMultitouchHelperProtocol = 'android-multitouch-helper-v1';
const _kInstallTimeoutMs = 30000;
const _kGestureTimeoutMs = 15000;
const _kDefaultDurationMs = 300;
const _kDefaultRadius = 160;
const _kRotateMaxDegreesPerFrame = 3;
const _kRotateFrameIntervalMs = 16;
const _kRotateMaxDurationMs = 2400;

// ---------------------------------------------------------------------------
// Types
// ---------------------------------------------------------------------------

/// Parsed manifest describing the multitouch helper APK artifact.
class AndroidMultitouchHelperManifest {
  final String name;
  final String version;
  final String assetName;
  final String sha256;
  final String packageName;
  final int versionCode;
  final String instrumentationRunner;
  final String statusProtocol;

  const AndroidMultitouchHelperManifest({
    required this.name,
    required this.version,
    required this.assetName,
    required this.sha256,
    required this.packageName,
    required this.versionCode,
    required this.instrumentationRunner,
    required this.statusProtocol,
  });
}

/// A resolved helper APK path + its manifest.
class AndroidMultitouchHelperArtifact {
  final String apkPath;
  final AndroidMultitouchHelperManifest manifest;

  const AndroidMultitouchHelperArtifact({
    required this.apkPath,
    required this.manifest,
  });
}

/// Internal gesture request shape sent to the APK.
sealed class _MultitouchHelperGestureRequest {
  const _MultitouchHelperGestureRequest();

  Map<String, Object?> toJson();
}

class _PinchRequest extends _MultitouchHelperGestureRequest {
  final int x;
  final int y;
  final double scale;
  final int radius;
  final int durationMs;

  const _PinchRequest({
    required this.x,
    required this.y,
    required this.scale,
    required this.radius,
    required this.durationMs,
  });

  Map<String, Object?> toJson() => {
    'kind': 'pinch',
    'x': x,
    'y': y,
    'scale': scale,
    'radius': radius,
    'durationMs': durationMs,
  };
}

class _RotateRequest extends _MultitouchHelperGestureRequest {
  final int x;
  final int y;
  final double degrees;
  final int radius;
  final int durationMs;

  const _RotateRequest({
    required this.x,
    required this.y,
    required this.degrees,
    required this.radius,
    required this.durationMs,
  });

  Map<String, Object?> toJson() => {
    'kind': 'rotate',
    'x': x,
    'y': y,
    'degrees': degrees,
    'radius': radius,
    'durationMs': durationMs,
  };
}

class _TransformRequest extends _MultitouchHelperGestureRequest {
  final int x;
  final int y;
  final int dx;
  final int dy;
  final double scale;
  final double degrees;
  final int durationMs;

  const _TransformRequest({
    required this.x,
    required this.y,
    required this.dx,
    required this.dy,
    required this.scale,
    required this.degrees,
    required this.durationMs,
  });

  Map<String, Object?> toJson() => {
    'kind': 'transform',
    'x': x,
    'y': y,
    'dx': dx,
    'dy': dy,
    'scale': scale,
    'degrees': degrees,
    'durationMs': durationMs,
  };
}

// ---------------------------------------------------------------------------
// Public option types
// ---------------------------------------------------------------------------

class AndroidPinchGestureOptions {
  final double scale;
  final double? x;
  final double? y;
  final int? durationMs;

  const AndroidPinchGestureOptions({
    required this.scale,
    this.x,
    this.y,
    this.durationMs,
  });
}

class AndroidRotateGestureOptions {
  final double degrees;
  final double? x;
  final double? y;
  final double? velocity;
  final int? durationMs;

  const AndroidRotateGestureOptions({
    required this.degrees,
    this.x,
    this.y,
    this.velocity,
    this.durationMs,
  });
}

class AndroidTransformGestureOptions {
  final double x;
  final double y;
  final double dx;
  final double dy;
  final double scale;
  final double degrees;
  final int? durationMs;

  const AndroidTransformGestureOptions({
    required this.x,
    required this.y,
    required this.dx,
    required this.dy,
    required this.scale,
    required this.degrees,
    this.durationMs,
  });
}

// ---------------------------------------------------------------------------
// High-level gesture entry points
// ---------------------------------------------------------------------------

/// Execute a pinch gesture on Android using the multitouch helper APK.
Future<Map<String, Object?>> pinchAndroid(
  String serial,
  AndroidPinchGestureOptions options,
) async {
  if (!options.scale.isFinite || options.scale <= 0) {
    throw AppError(
      AppErrorCodes.invalidArgs,
      'gesture pinch requires scale > 0',
    );
  }
  final center = await _resolveGestureCenter(serial, options.x, options.y);
  return _runAndroidMultiTouchGesture(
    serial,
    _PinchRequestInput(
      x: center.x,
      y: center.y,
      scale: options.scale,
      durationMs: options.durationMs,
    ),
  );
}

/// Execute a rotate gesture on Android using the multitouch helper APK.
Future<Map<String, Object?>> rotateGestureAndroid(
  String serial,
  AndroidRotateGestureOptions options,
) async {
  if (!options.degrees.isFinite) {
    throw AppError(
      AppErrorCodes.invalidArgs,
      'gesture rotate requires finite degrees',
    );
  }
  if (options.velocity != null &&
      (!options.velocity!.isFinite || options.velocity == 0)) {
    throw AppError(
      AppErrorCodes.invalidArgs,
      'gesture rotate velocity must be a non-zero number',
    );
  }
  final center = await _resolveGestureCenter(serial, options.x, options.y);
  return _runAndroidMultiTouchGesture(
    serial,
    _RotateRequestInput(
      x: center.x,
      y: center.y,
      degrees: options.degrees,
      durationMs: options.durationMs,
    ),
  );
}

/// Execute a transform gesture on Android using the multitouch helper APK.
Future<Map<String, Object?>> transformGestureAndroid(
  String serial,
  AndroidTransformGestureOptions options,
) async {
  if (!options.scale.isFinite || options.scale <= 0) {
    throw AppError(
      AppErrorCodes.invalidArgs,
      'gesture transform requires scale > 0',
    );
  }
  if (!options.degrees.isFinite) {
    throw AppError(
      AppErrorCodes.invalidArgs,
      'gesture transform requires finite degrees',
    );
  }
  if (![options.x, options.y, options.dx, options.dy].every(
    (v) => v.isFinite,
  )) {
    throw AppError(
      AppErrorCodes.invalidArgs,
      'gesture transform requires finite x y dx dy',
    );
  }
  return _runAndroidMultiTouchGesture(
    serial,
    _TransformRequestInput(
      x: options.x,
      y: options.y,
      dx: options.dx,
      dy: options.dy,
      scale: options.scale,
      degrees: options.degrees,
      durationMs: options.durationMs,
    ),
  );
}

// ---------------------------------------------------------------------------
// Internal request input types (mirrors TS AndroidTouchGestureRequest)
// ---------------------------------------------------------------------------

sealed class _GestureRequestInput {
  const _GestureRequestInput();
  int? get durationMs;
  double get degrees => 0;
}

class _PinchRequestInput extends _GestureRequestInput {
  final double x;
  final double y;
  final double scale;
  @override
  final int? durationMs;

  const _PinchRequestInput({
    required this.x,
    required this.y,
    required this.scale,
    this.durationMs,
  });
}

class _RotateRequestInput extends _GestureRequestInput {
  final double x;
  final double y;
  @override
  final double degrees;
  @override
  final int? durationMs;

  const _RotateRequestInput({
    required this.x,
    required this.y,
    required this.degrees,
    this.durationMs,
  });
}

class _TransformRequestInput extends _GestureRequestInput {
  final double x;
  final double y;
  final double dx;
  final double dy;
  final double scale;
  @override
  final double degrees;
  @override
  final int? durationMs;

  const _TransformRequestInput({
    required this.x,
    required this.y,
    required this.dx,
    required this.dy,
    required this.scale,
    required this.degrees,
    this.durationMs,
  });
}

// ---------------------------------------------------------------------------
// Core execution
// ---------------------------------------------------------------------------

Future<Map<String, Object?>> _runAndroidMultiTouchGesture(
  String serial,
  _GestureRequestInput input,
) async {
  final adb = _makeAdbExecutor(serial);
  final artifact = await _resolveArtifact();
  final deviceKey = 'android:$serial';

  await _ensureMultitouchHelper(
    adb: adb,
    artifact: artifact,
    deviceKey: deviceKey,
  );

  return _runGesture(
    adb: adb,
    request: _normalizeRequest(input),
    packageName: artifact.manifest.packageName,
    instrumentationRunner: artifact.manifest.instrumentationRunner,
  );
}

AndroidAdbExecutor _makeAdbExecutor(String serial) {
  return (List<String> args, {bool allowFailure = false, int? timeoutMs}) async {
    final r = await runCmd(
      'adb',
      adbArgs(serial, args),
      ExecOptions(
        allowFailure: allowFailure,
        timeoutMs: timeoutMs ?? 30000,
      ),
    );
    return AdbResult(
      exitCode: r.exitCode,
      stdout: r.stdout,
      stderr: r.stderr,
    );
  };
}

_MultitouchHelperGestureRequest _normalizeRequest(_GestureRequestInput input) {
  final durationMs = _resolveDurationMs(input);
  switch (input) {
    case _PinchRequestInput():
      return _PinchRequest(
        x: input.x.round(),
        y: input.y.round(),
        scale: input.scale,
        radius: _kDefaultRadius,
        durationMs: durationMs,
      );
    case _RotateRequestInput():
      return _RotateRequest(
        x: input.x.round(),
        y: input.y.round(),
        degrees: input.degrees,
        radius: _kDefaultRadius,
        durationMs: durationMs,
      );
    case _TransformRequestInput():
      return _TransformRequest(
        x: input.x.round(),
        y: input.y.round(),
        dx: input.dx.round(),
        dy: input.dy.round(),
        scale: input.scale,
        degrees: input.degrees,
        durationMs: durationMs,
      );
  }
}

int _resolveDurationMs(_GestureRequestInput input) {
  if (input.durationMs != null) return input.durationMs!;
  if (input is _PinchRequestInput) return _kDefaultDurationMs;
  // Angle-based duration for rotate/transform.
  final degrees = input.degrees.abs();
  final angleBasedDuration =
      ((degrees / _kRotateMaxDegreesPerFrame).ceil() *
          _kRotateFrameIntervalMs);
  return _kRotateMaxDurationMs.clamp(
    _kDefaultDurationMs,
    _kRotateMaxDurationMs,
  ) == _kRotateMaxDurationMs
      ? angleBasedDuration.clamp(
          _kDefaultDurationMs,
          _kRotateMaxDurationMs,
        )
      : _kDefaultDurationMs;
}

/// Run the gesture via `adb shell am instrument`.
Future<Map<String, Object?>> _runGesture({
  required AndroidAdbExecutor adb,
  required _MultitouchHelperGestureRequest request,
  required String packageName,
  required String instrumentationRunner,
}) async {
  final payload = jsonEncode({
    'protocol': _kMultitouchHelperProtocol,
    ...request.toJson(),
  });
  final payloadBase64 = base64Encode(utf8.encode(payload));

  final result = await adb(
    [
      'shell',
      'am',
      'instrument',
      '-w',
      '-e',
      'payloadBase64',
      payloadBase64,
      instrumentationRunner,
    ],
    allowFailure: true,
    timeoutMs: _kGestureTimeoutMs,
  );

  Map<String, Object?> output;
  try {
    output = _parseOutput('${result.stdout}\n${result.stderr}');
  } catch (error) {
    throw AppError(
      AppErrorCodes.commandFailed,
      result.exitCode == 0
          ? 'Android multi-touch helper output could not be parsed'
          : 'Android multi-touch helper failed before returning parseable output',
      details: {
        'stdout': result.stdout,
        'stderr': result.stderr,
        'exitCode': result.exitCode,
      },
    );
  }

  if (result.exitCode != 0) {
    throw AppError(
      AppErrorCodes.commandFailed,
      'Android multi-touch helper failed',
      details: {
        'stdout': result.stdout,
        'stderr': result.stderr,
        'exitCode': result.exitCode,
        'helper': output,
      },
    );
  }
  return output;
}

// ---------------------------------------------------------------------------
// Output parsing
// ---------------------------------------------------------------------------

/// Parse `INSTRUMENTATION_RESULT: key=value` lines from raw adb output.
Map<String, Object?> _parseOutput(String raw) {
  final records = _parseInstrumentationResults(raw);
  final finalResult = records.firstWhere(
    (r) => r['agentDeviceProtocol'] == _kMultitouchHelperProtocol,
    orElse: () => <String, String>{},
  );
  if (finalResult.isEmpty) {
    throw AppError(
      AppErrorCodes.commandFailed,
      'Android multi-touch helper did not return a final result',
    );
  }
  final ok = finalResult['ok'];
  if (ok != 'true') {
    final message = finalResult['message'];
    final errorType = finalResult['errorType'];
    final msg =
        (message != null && message != 'null')
            ? message
            : errorType ?? 'Android multi-touch helper returned an error';
    throw AppError(AppErrorCodes.commandFailed, msg, details: {
      'errorType': errorType,
      'helper': finalResult,
    });
  }
  return {
    'kind': finalResult['kind'],
    'helperApiVersion': finalResult['helperApiVersion'],
    if (_parseOptionalInt(finalResult['injectedEvents']) != null)
      'injectedEvents': _parseOptionalInt(finalResult['injectedEvents']),
    if (_parseOptionalInt(finalResult['elapsedMs']) != null)
      'elapsedMs': _parseOptionalInt(finalResult['elapsedMs']),
  };
}

List<Map<String, String>> _parseInstrumentationResults(String raw) {
  final results = <Map<String, String>>[];
  Map<String, String>? current;
  for (final line in raw.split(RegExp(r'\r?\n'))) {
    if (line.startsWith('INSTRUMENTATION_RESULT: ')) {
      current ??= {};
      _readKeyValue(line.substring('INSTRUMENTATION_RESULT: '.length), current);
    } else if (line.startsWith('INSTRUMENTATION_CODE: ') && current != null) {
      results.add(current);
      current = null;
    }
  }
  if (current != null) results.add(current);
  return results;
}

void _readKeyValue(String line, Map<String, String> target) {
  final separator = line.indexOf('=');
  if (separator >= 0) {
    target[line.substring(0, separator)] = line.substring(separator + 1);
  }
}

int? _parseOptionalInt(String? value) {
  if (value == null) return null;
  return int.tryParse(value);
}

// ---------------------------------------------------------------------------
// Gesture center resolution
// ---------------------------------------------------------------------------

class _Point {
  final double x;
  final double y;
  const _Point({required this.x, required this.y});
}

Future<_Point> _resolveGestureCenter(
  String serial,
  double? x,
  double? y,
) async {
  if (x != null && y != null) return _Point(x: x, y: y);
  // Query screen size via wm size.
  final r = await runCmd(
    'adb',
    adbArgs(serial, ['shell', 'wm', 'size']),
    const ExecOptions(allowFailure: true, timeoutMs: 5000),
  );
  final match = RegExp(
    r'Physical size:\s*(\d+)x(\d+)',
  ).firstMatch(r.stdout);
  if (match != null) {
    final w = double.tryParse(match.group(1)!) ?? 1080;
    final h = double.tryParse(match.group(2)!) ?? 1920;
    return _Point(x: w / 2, y: h / 2);
  }
  // Fallback
  return const _Point(x: 540, y: 960);
}

// ---------------------------------------------------------------------------
// Install / artifact resolution
// ---------------------------------------------------------------------------

// In-memory cache to avoid re-installing on every gesture.
final _installedMultitouchHelpers = <String>{};

Future<void> _ensureMultitouchHelper({
  required AndroidAdbExecutor adb,
  required AndroidMultitouchHelperArtifact artifact,
  required String deviceKey,
}) async {
  final packageName = artifact.manifest.packageName;
  final versionCode = artifact.manifest.versionCode;
  final cacheKey = '$deviceKey\x00$packageName\x00$versionCode';

  if (_installedMultitouchHelpers.contains(cacheKey)) return;

  final installedVersionCode = await _readInstalledVersionCode(adb, packageName);
  if (installedVersionCode != null && installedVersionCode >= versionCode) {
    _installedMultitouchHelpers.add(cacheKey);
    return;
  }

  // Verify APK checksum before installing.
  await _verifyArtifact(artifact);

  // Install with `adb install -r -t <apkPath>`.
  final result = await adb(
    ['install', '-r', '-t', artifact.apkPath],
    allowFailure: true,
    timeoutMs: _kInstallTimeoutMs,
  );
  if (result.exitCode != 0) {
    throw AppError(
      AppErrorCodes.commandFailed,
      'Failed to install Android multi-touch helper',
      details: {
        'packageName': packageName,
        'versionCode': versionCode,
        'stdout': result.stdout,
        'stderr': result.stderr,
        'exitCode': result.exitCode,
      },
    );
  }
  _installedMultitouchHelpers.add(cacheKey);
}

/// Reset the in-memory install cache (for tests).
void resetAndroidMultitouchHelperInstallCache() {
  _installedMultitouchHelpers.clear();
}

Future<int?> _readInstalledVersionCode(
  AndroidAdbExecutor adb,
  String packageName,
) async {
  final result = await adb(
    [
      'shell',
      'cmd',
      'package',
      'list',
      'packages',
      '--show-versioncode',
      packageName,
    ],
    allowFailure: true,
    timeoutMs: 5000,
  );
  if (result.exitCode != 0) return null;
  final combined = '${result.stdout}\n${result.stderr}';
  final match = RegExp(
    'package:${RegExp.escape(packageName)}(?:\\s|\$).*versionCode:(\\d+)',
  ).firstMatch(combined);
  return match != null ? int.tryParse(match.group(1)!) : null;
}

Future<void> _verifyArtifact(AndroidMultitouchHelperArtifact artifact) async {
  final actual = await _sha256File(artifact.apkPath);
  if (actual != artifact.manifest.sha256) {
    throw AppError(
      AppErrorCodes.commandFailed,
      'Android multi-touch helper APK checksum mismatch',
      details: {
        'apkPath': artifact.apkPath,
        'expectedSha256': artifact.manifest.sha256,
        'actualSha256': actual,
      },
    );
  }
}

Future<String> _sha256File(String filePath) async {
  final input = File(filePath).openRead();
  final digest = await sha256.bind(input).first;
  return digest.toString();
}

// ---------------------------------------------------------------------------
// Artifact resolution
// ---------------------------------------------------------------------------

Future<AndroidMultitouchHelperArtifact> _resolveArtifact() async {
  // Try pre-built APK from the unified resolver.
  final apkPath = await resolveNativeAsset(
    'android-multitouch-helper/android-multitouch-helper.apk',
  );
  final manifestPath = await resolveNativeAsset(
    'android-multitouch-helper/android-multitouch-helper.manifest.json',
  );
  if (apkPath != null && manifestPath != null) {
    try {
      final manifest = _parseManifest(
        jsonDecode(File(manifestPath).readAsStringSync()),
      );
      return AndroidMultitouchHelperArtifact(
        apkPath: apkPath,
        manifest: manifest,
      );
    } catch (_) {}
  }

  // Try versioned APK from repo-root dist/ layout.
  final helperDir = await resolveNativeAssetDir('android-multitouch-helper');
  if (helperDir != null) {
    final distDir = p.join(helperDir, 'dist');
    final fromDist = _readBundledArtifact(distDir);
    if (fromDist != null) return fromDist;
    final fromDir = _readBundledArtifact(helperDir);
    if (fromDir != null) return fromDir;
  }

  throw AppError(
    AppErrorCodes.unsupportedOperation,
    'gesture pinch/rotate/transform on Android requires the bundled '
    'Android multi-touch helper artifact, but it was not found or could '
    'not be read. Run the build script at '
    'lib/src/native/android-multitouch-helper/build-android-multitouch-helper.sh '
    'to generate it.',
  );
}

AndroidMultitouchHelperArtifact? _readBundledArtifact(String dir) {
  try {
    final d = Directory(dir);
    if (!d.existsSync()) return null;
    final manifestFiles = d
        .listSync()
        .whereType<File>()
        .where((f) => p.basename(f.path).endsWith('.manifest.json'))
        .toList();
    if (manifestFiles.isEmpty) return null;
    final manifestFile = manifestFiles.first;
    final manifest = _parseManifest(
      jsonDecode(manifestFile.readAsStringSync()),
    );
    final apkName = manifest.assetName;
    final apkPath = p.join(dir, apkName);
    if (!File(apkPath).existsSync()) return null;
    return AndroidMultitouchHelperArtifact(apkPath: apkPath, manifest: manifest);
  } catch (_) {
    return null;
  }
}

AndroidMultitouchHelperManifest _parseManifest(Object? value) {
  if (value == null || value is! Map) {
    throw AppError(
      AppErrorCodes.invalidArgs,
      'Android multi-touch helper manifest must be an object.',
    );
  }
  final r = value.cast<String, Object?>();
  return AndroidMultitouchHelperManifest(
    name: _readLiteral(r['name'], 'name', _kMultitouchHelperName),
    version: _readString(r['version'], 'version'),
    assetName: _readString(r['assetName'], 'assetName'),
    sha256: _readSha256(r['sha256']),
    packageName: _readLiteral(
      r['packageName'],
      'packageName',
      _kMultitouchHelperPackage,
    ),
    versionCode: _readNumber(r['versionCode'], 'versionCode'),
    instrumentationRunner: _readLiteral(
      r['instrumentationRunner'],
      'instrumentationRunner',
      _kMultitouchHelperRunner,
    ),
    statusProtocol: _readLiteral(
      r['statusProtocol'],
      'statusProtocol',
      _kMultitouchHelperProtocol,
    ),
  );
}

// ---------------------------------------------------------------------------
// Manifest field parsers
// ---------------------------------------------------------------------------

String _readString(Object? value, String field) {
  if (value is! String || value.trim().isEmpty) {
    throw AppError(
      AppErrorCodes.invalidArgs,
      'Android multi-touch helper manifest $field is required.',
    );
  }
  return value;
}

int _readNumber(Object? value, String field) {
  if (value is! num || value != value.truncate()) {
    throw AppError(
      AppErrorCodes.invalidArgs,
      'Android multi-touch helper manifest $field must be an integer.',
    );
  }
  return value.toInt();
}

String _readLiteral(Object? value, String field, String expected) {
  if (value != expected) {
    throw AppError(
      AppErrorCodes.invalidArgs,
      'Android multi-touch helper manifest $field must be "$expected".',
    );
  }
  return expected;
}

String _readSha256(Object? value) {
  final raw = _readString(value, 'sha256').trim().toLowerCase();
  if (raw.length != 64 || !_isLowerHex(raw)) {
    throw AppError(
      AppErrorCodes.invalidArgs,
      'Android multi-touch helper manifest sha256 must be a 64-character hex string.',
    );
  }
  return raw;
}

bool _isLowerHex(String value) {
  for (final char in value.runes) {
    final isDigit = char >= 0x30 && char <= 0x39;
    final isHexLower = char >= 0x61 && char <= 0x66;
    if (!isDigit && !isHexLower) return false;
  }
  return true;
}

// ---------------------------------------------------------------------------
// Test-visible entry points
// ---------------------------------------------------------------------------

/// Parse a manifest from a raw decoded JSON map. Visible for testing.
@visibleForTesting
AndroidMultitouchHelperManifest parseAndroidMultitouchHelperManifestForTest(
  Object? value,
) => _parseManifest(value);

/// Parse raw adb instrumentation output into a result map. Visible for testing.
@visibleForTesting
Map<String, Object?> parseAndroidMultitouchHelperOutputForTest(String raw) =>
    _parseOutput(raw);
