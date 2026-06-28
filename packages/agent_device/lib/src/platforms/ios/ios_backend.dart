// Phase 8B iOS backend — adds XCUITest-runner-backed methods on top of
// the Phase 8A simctl subset. The runner is launched once per
// BackendCommandContext (keyed on deviceSerial + session name via
// metadata stored in ctx.metadata['iosRunner'] by the runtime layer);
// subsequent commands reuse the live port. When the session closes the
// runtime issues a `shutdown` command via [shutdownRunner].
library;

import 'dart:convert';
import 'dart:io';

import 'package:agent_device/src/backend/backend.dart';
import 'package:agent_device/src/diagnostics/log_stream_record.dart';
import 'package:agent_device/src/platforms/setting_state.dart';
import 'package:agent_device/src/runtime/paths.dart';
import 'package:agent_device/src/snapshot/ios_presentation.dart';
import 'package:agent_device/src/snapshot/snapshot.dart';
import 'package:agent_device/src/utils/errors.dart';
import 'package:agent_device/src/utils/exec.dart';
import 'package:agent_device/src/utils/file_mutex.dart';
import 'package:agent_device/src/utils/location_coordinates.dart';
import 'package:path/path.dart' as p;

import 'app_lifecycle.dart';
import 'devicectl.dart';
import 'devices.dart';
import 'install_artifact.dart';
import 'perf.dart';
import 'perf_frame.dart';
import 'runner_client.dart';
import 'runner_failure_diagnostics.dart';
import 'screenshot.dart';
import 'simctl.dart';

/// Candidate container bundle ids used by `devicectl device copy from
/// --domain-type appDataContainer` when pulling a recording off a
/// physical iOS device. The UI-test runner process writes to the
/// *.xctrunner* container's tmp dir; we try that first, then fall
/// back to the main app container. Matches the TS port's
/// `IOS_RUNNER_CONTAINER_BUNDLE_IDS` ordering.
///
/// If the Xcode project ever renames these targets, update both lists
/// in lockstep. An environment override lets advanced users inject an
/// extra candidate without touching the source.
List<String> _iosRunnerContainerBundleIds() {
  final override =
      Platform.environment['AGENT_DEVICE_IOS_RUNNER_CONTAINER_BUNDLE_ID'];
  return <String>[
    if (override != null && override.trim().isNotEmpty) override.trim(),
    'dev.roszkowski.agentdevice.runner.uitests.xctrunner',
    'dev.roszkowski.agentdevice.runner',
  ];
}

class IosBackend extends Backend {
  const IosBackend();

  @override
  AgentDeviceBackendPlatform get platform => AgentDeviceBackendPlatform.ios;

  /// Phase 8A/B treats `BackendCommandContext.deviceSerial` as the iOS
  /// simulator UDID — same plumbing as Android's `serial`.
  String _udid(BackendCommandContext ctx) {
    final udid = ctx.deviceSerial;
    if (udid == null || udid.isEmpty) {
      unsupported('operation requires ctx.deviceSerial (simulator UDID)');
    }
    return udid;
  }

  String? _appBundleId(BackendCommandContext ctx) {
    final bundleId = ctx.appBundleId ?? ctx.appId;
    if (bundleId == null || bundleId.isEmpty) {
      return null;
    }
    return bundleId;
  }

  // =========================================================================
  // Runner session lookup / launch.
  // =========================================================================

  /// Get a live runner for the ctx's UDID. Reuses a runner recorded on
  /// disk under `<stateDir>/ios-runners/<udid>.json` (and verified with a
  /// port probe) across CLI invocations; falls back to launching a fresh
  /// detached runner via `xcodebuild test-without-building`. The cache
  /// key is the UDID since one simulator can only host one runner at a
  /// time.
  Future<IosRunnerSession> _runner(BackendCommandContext ctx) async {
    final udid = _udid(ctx);
    final existing = await _liveRunner(udid);
    if (existing != null) return existing;

    // No live runner — (re)launch, serialized per device on the same lock
    // commands use, so concurrent `ad` invocations don't each spawn their own
    // `xcodebuild`. Whoever wins the lock launches and records the runner;
    // everyone else re-checks inside the lock and reuses it.
    return FileMutex(IosRunnerClient.runnerLockFile(udid)).protect(
      () async {
        final winner = await _liveRunner(udid);
        if (winner != null) return winner;
        await _deleteRunnerRecord(udid);
        final kindStr = await _resolveKind(udid);
        final runnerKind = kindStr == 'device'
            ? IosRunnerKind.device
            : IosRunnerKind.simulator;
        final session = await IosRunnerClient.launch(
          udid: udid,
          kind: runnerKind,
        );
        _IosRunnerCache.instance.set(udid, session);
        await _writeRunnerRecord(session);
        return session;
      },
      // Generous: a cold simulator launch budget is 120s, and a waiter may
      // queue behind one.
      maxWait: const Duration(seconds: 200),
    );
  }

  /// Return a live runner for [udid] from the in-process cache or the on-disk
  /// record (each verified with [IosRunnerClient.isAlive]), or null if none is
  /// currently reachable.
  Future<IosRunnerSession?> _liveRunner(String udid) async {
    final inProc = _IosRunnerCache.instance.get(udid);
    if (inProc != null && await IosRunnerClient.isAlive(inProc)) return inProc;
    final diskRecord = await _readRunnerRecord(udid);
    if (diskRecord != null && await IosRunnerClient.isAlive(diskRecord)) {
      _IosRunnerCache.instance.set(udid, diskRecord);
      return diskRecord;
    }
    return null;
  }

  /// Shut down the cached runner for [udid] (if any). Called by the
  /// runtime layer on session close. Safe to call repeatedly.
  static Future<void> shutdownRunnerFor(String udid) async {
    final inProc = _IosRunnerCache.instance.pop(udid);
    if (inProc != null) await IosRunnerClient.stop(inProc);
    final disk = await _readRunnerRecord(udid);
    if (disk != null) {
      await IosRunnerClient.stop(disk);
      await _deleteRunnerRecord(udid);
    }
  }

  /// `<stateDir>/ios-runners/<udid>.json` holds the last-known
  /// `{udid, port, xcodebuildPid, xctestrunPath, logPath}` for the runner
  /// driving [udid].
  static File _runnerRecordFile(String udid) {
    final paths = resolveStatePaths();
    return File(p.join(paths.baseDir, 'ios-runners', '$udid.json'));
  }

  static Future<IosRunnerSession?> _readRunnerRecord(String udid) async {
    final file = _runnerRecordFile(udid);
    if (!await file.exists()) return null;
    try {
      final raw = await file.readAsString();
      if (raw.trim().isEmpty) return null;
      return IosRunnerSession.fromJson(jsonDecode(raw));
    } on FormatException {
      return null;
    }
  }

  static Future<void> _writeRunnerRecord(IosRunnerSession s) async {
    final file = _runnerRecordFile(s.udid);
    await file.parent.create(recursive: true);
    await file.writeAsString(jsonEncode(s.toJson()));
  }

  static Future<void> _deleteRunnerRecord(String udid) async {
    final file = _runnerRecordFile(udid);
    if (await file.exists()) {
      try {
        await file.delete();
      } catch (_) {}
    }
  }

  // =========================================================================
  // Snapshot + Screenshot
  // =========================================================================

  @override
  Future<BackendSnapshotResult> captureSnapshot(
    BackendCommandContext ctx,
    BackendSnapshotOptions? options,
  ) async {
    final session = await _runner(ctx);
    final bundleId = _appBundleId(ctx);
    final body = <String, Object?>{
      'command': 'snapshot',
      'appBundleId': ?bundleId,
      if (options?.interactiveOnly != null)
        'interactiveOnly': options!.interactiveOnly,
      if (options?.compact != null) 'compact': options!.compact,
      if (options?.depth != null) 'depth': options!.depth,
      if (options?.scope != null) 'scope': options!.scope,
      if (options?.raw != null) 'raw': options!.raw,
    };
    final res = await IosRunnerClient.send(session, body);
    if (!res.ok) {
      throw AppError(
        AppErrorCodes.commandFailed,
        'iOS runner snapshot failed: ${res.errorMessage ?? 'unknown error'}',
      );
    }
    final data = res.data;
    if (data is! Map) {
      throw AppError(
        AppErrorCodes.commandFailed,
        'iOS runner returned unexpected shape for snapshot.',
      );
    }
    final rawNodes = (data['nodes'] as List?) ?? const [];
    final parsedNodes = rawNodes.map(_rawNodeFromJson).whereType<RawSnapshotNode>().toList();
    final presentedNodes = _shouldPresentIosInteractiveSnapshot(options)
        ? presentIosInteractiveSnapshot(parsedNodes)
        : parsedNodes;
    final snapshotNodes = attachRefs(presentedNodes);
    return BackendSnapshotResult(
      nodes: snapshotNodes,
      truncated: data['truncated'] == true,
      appBundleId: bundleId,
      analysis: BackendSnapshotAnalysis(
        rawNodeCount: snapshotNodes.length,
        maxDepth: snapshotNodes.fold<int>(
          0,
          (m, n) => (n.depth ?? 0) > m ? (n.depth ?? 0) : m,
        ),
      ),
    );
  }

  /// Phase 8A kept screenshot on simctl. Keep it there — simctl is
  /// reliable for full-screen captures and doesn't need the runner.
  @override
  Future<BackendScreenshotResult?> captureScreenshot(
    BackendCommandContext ctx,
    String outPath,
    BackendScreenshotOptions? options,
  ) async {
    await screenshotIos(_udid(ctx), outPath);
    return BackendScreenshotResult(path: outPath);
  }

  // =========================================================================
  // Interaction
  // =========================================================================

  @override
  Future<BackendActionResult> tap(
    BackendCommandContext ctx,
    Point point,
    BackendTapOptions? options,
  ) async {
    final session = await _runner(ctx);
    final bundleId = _appBundleId(ctx);
    await _sendOrThrow(session, {
      'command': 'tap',
      'x': point.x,
      'y': point.y,
      'appBundleId': ?bundleId,
    });
    return null;
  }

  /// Direct selector tap: the runner finds the element by accessibility
  /// property and taps it in a single round-trip — no snapshot needed.
  /// Returns null on success, throws on runner error.
  Future<Map<String, Object?>?> tapElementSelector({
    required BackendCommandContext ctx,
    required String selectorKey,
    required String selectorValue,
  }) async {
    final session = await _runner(ctx);
    final bundleId = _appBundleId(ctx);
    final res = await IosRunnerClient.send(session, {
      'command': 'tap',
      'selectorKey': selectorKey,
      'selectorValue': selectorValue,
      'appBundleId': ?bundleId,
    });
    if (!res.ok) {
      throw AppError(
        AppErrorCodes.commandFailed,
        'iOS runner tap (selector) failed: ${res.errorMessage ?? 'unknown'}',
      );
    }
    session.lastSuccessAt = DateTime.now();
    return res.data is Map<String, Object?>
        ? res.data as Map<String, Object?>
        : null;
  }

  /// Direct selector fill: the runner finds the element, focuses it,
  /// and types text — no snapshot needed.
  Future<Map<String, Object?>?> fillElementSelector({
    required BackendCommandContext ctx,
    required String selectorKey,
    required String selectorValue,
    required String text,
  }) async {
    final session = await _runner(ctx);
    final bundleId = _appBundleId(ctx);
    final res = await IosRunnerClient.send(session, {
      'command': 'fill',
      'selectorKey': selectorKey,
      'selectorValue': selectorValue,
      'text': text,
      'appBundleId': ?bundleId,
    });
    if (!res.ok) {
      throw AppError(
        AppErrorCodes.commandFailed,
        'iOS runner fill (selector) failed: ${res.errorMessage ?? 'unknown'}',
      );
    }
    session.lastSuccessAt = DateTime.now();
    return res.data is Map<String, Object?>
        ? res.data as Map<String, Object?>
        : null;
  }

  @override
  Future<BackendActionResult> longPress(
    BackendCommandContext ctx,
    Point point,
    BackendLongPressOptions? options,
  ) async {
    final session = await _runner(ctx);
    final bundleId = _appBundleId(ctx);
    await _sendOrThrow(session, {
      'command': 'longPress',
      'x': point.x,
      'y': point.y,
      'appBundleId': ?bundleId,
      if (options?.durationMs != null) 'durationMs': options!.durationMs,
    });
    return null;
  }

  @override
  Future<BackendActionResult> swipe(
    BackendCommandContext ctx,
    Point from,
    Point to,
    BackendSwipeOptions? options,
  ) async {
    final session = await _runner(ctx);
    final bundleId = _appBundleId(ctx);
    await _sendOrThrow(session, {
      'command': 'drag',
      'x': from.x,
      'y': from.y,
      'x2': to.x,
      'y2': to.y,
      'appBundleId': ?bundleId,
      if (options?.durationMs != null) 'durationMs': options!.durationMs,
    });
    return null;
  }

  @override
  Future<BackendActionResult> scroll(
    BackendCommandContext ctx,
    BackendScrollTarget target,
    BackendScrollOptions options,
  ) async {
    final session = await _runner(ctx);
    final bundleId = _appBundleId(ctx);
    final direction = options.direction;
    final amount = options.amount?.toDouble() ?? 1.0;
    // Compute swipe coords from direction + amount, using a default
    // viewport center and a travel distance proportional to amount.
    const centerX = 200.0;
    const centerY = 400.0;
    const travelPerUnit = 200.0;
    final travel = amount * travelPerUnit;
    double x1 = centerX, y1 = centerY, x2 = centerX, y2 = centerY;
    switch (direction) {
      case 'up':
        y1 = centerY + travel / 2;
        y2 = centerY - travel / 2;
      case 'down':
        y1 = centerY - travel / 2;
        y2 = centerY + travel / 2;
      case 'left':
        x1 = centerX + travel / 2;
        x2 = centerX - travel / 2;
      case 'right':
        x1 = centerX - travel / 2;
        x2 = centerX + travel / 2;
    }
    // Honor a caller-provided duration via the synthesized drag path; without
    // one, fall through to the native (non-synthesized) drag. Mirrors upstream
    // fused `.scroll` (durationMs: command.durationMs, synthesized: != nil).
    final durationMs = options.durationMs;
    await _sendOrThrow(session, {
      'command': 'drag',
      'x': x1,
      'y': y1,
      'x2': x2,
      'y2': y2,
      'appBundleId': ?bundleId,
      if (durationMs != null) ...{
        'durationMs': durationMs,
        'synthesized': true,
      },
    });
    return null;
  }

  @override
  Future<BackendActionResult> pan(
    BackendCommandContext ctx,
    BackendPanOptions options,
  ) async {
    final session = await _runner(ctx);
    final bundleId = _appBundleId(ctx);
    await _sendOrThrow(session, {
      'command': 'drag',
      'x': options.startX,
      'y': options.startY,
      'x2': options.endX,
      'y2': options.endY,
      'durationMs': options.durationMs ?? 500,
      'appBundleId': ?bundleId,
    });
    return null;
  }

  @override
  Future<BackendActionResult> fling(
    BackendCommandContext ctx,
    BackendFlingOptions options,
  ) async {
    final session = await _runner(ctx);
    final bundleId = _appBundleId(ctx);
    await _sendOrThrow(session, {
      'command': 'drag',
      'x': options.startX,
      'y': options.startY,
      'x2': options.endX,
      'y2': options.endY,
      'durationMs': options.durationMs ?? 16,
      'appBundleId': ?bundleId,
    });
    return null;
  }

  @override
  Future<BackendActionResult> rotateGesture(
    BackendCommandContext ctx,
    BackendRotateGestureOptions options,
  ) async {
    final session = await _runner(ctx);
    final bundleId = _appBundleId(ctx);
    // Note: the runner command is 'rotateGesture' (not 'rotate') to distinguish
    // from the device-rotation command at the runner protocol level.
    await _sendOrThrow(session, {
      'command': 'rotateGesture',
      'degrees': options.degrees,
      if (options.centerX != null) 'x': options.centerX,
      if (options.centerY != null) 'y': options.centerY,
      if (options.velocity != null) 'velocity': options.velocity,
      'appBundleId': ?bundleId,
    });
    return null;
  }

  @override
  Future<BackendActionResult> transformGesture(
    BackendCommandContext ctx,
    BackendTransformGestureOptions options,
  ) async {
    final session = await _runner(ctx);
    final bundleId = _appBundleId(ctx);
    await _sendOrThrow(session, {
      'command': 'transformGesture',
      'x': options.x,
      'y': options.y,
      'dx': options.dx,
      'dy': options.dy,
      'scale': options.scale,
      'degrees': options.degrees,
      if (options.durationMs != null) 'durationMs': options.durationMs,
      'appBundleId': ?bundleId,
    });
    return null;
  }

  @override
  Future<BackendActionResult> typeText(
    BackendCommandContext ctx,
    String text, [
    Map<String, Object?>? options,
  ]) async {
    final session = await _runner(ctx);
    final bundleId = _appBundleId(ctx);
    await _sendOrThrow(session, {
      'command': 'type',
      'text': text,
      'appBundleId': ?bundleId,
    });
    return null;
  }

  @override
  Future<BackendActionResult> pressHome(BackendCommandContext ctx) async {
    final session = await _runner(ctx);
    await _sendOrThrow(session, {'command': 'home'});
    return null;
  }

  @override
  Future<BackendActionResult> pressBack(
    BackendCommandContext ctx,
    BackendBackOptions? options,
  ) async {
    final session = await _runner(ctx);
    await _sendOrThrow(session, {'command': 'backInApp'});
    return null;
  }

  @override
  Future<BackendActionResult> openAppSwitcher(BackendCommandContext ctx) async {
    final session = await _runner(ctx);
    await _sendOrThrow(session, {'command': 'appSwitcher'});
    return null;
  }

  @override
  Future<BackendActionResult> rotate(
    BackendCommandContext ctx,
    BackendDeviceOrientation orientation,
  ) async {
    final session = await _runner(ctx);
    await _sendOrThrow(session, {
      'command': 'rotate',
      'orientation': _orientationToken(orientation),
    });
    return null;
  }

  // =========================================================================
  // Alerts
  // =========================================================================

  @override
  Future<BackendAlertResult> handleAlert(
    BackendCommandContext ctx,
    BackendAlertAction action, [
    Map<String, Object?>? options,
  ]) async {
    final session = await _runner(ctx);
    final bundleId = _appBundleId(ctx);
    // Map 'wait' to 'get' — iOS runner does not have a wait variant; the
    // wait loop lives above this layer in the daemon handler (snapshot-alert).
    final runnerAction = action == BackendAlertAction.wait
        ? 'get'
        : action.value;
    final res = await IosRunnerClient.send(session, <String, Object?>{
      'command': 'alert',
      'action': runnerAction,
      'appBundleId': ?bundleId,
    });
    if (!res.ok) {
      throw AppError(
        AppErrorCodes.commandFailed,
        'iOS runner alert failed: ${res.errorMessage ?? 'unknown error'}',
      );
    }
    // Parse the runner's JSON response into a BackendAlertResult.
    final data = res.data;
    final alertMap = data is Map ? data['alert'] : null;
    BackendAlertInfo? alertInfo;
    if (alertMap is Map) {
      final rawButtons = alertMap['buttons'];
      alertInfo = BackendAlertInfo(
        title: alertMap['title'] as String?,
        message: alertMap['message'] as String?,
        buttons: rawButtons is List
            ? rawButtons.whereType<String>().toList()
            : null,
      );
    }
    if (action == BackendAlertAction.accept ||
        action == BackendAlertAction.dismiss) {
      return BackendAlertHandledResult(
        handled: true,
        alert: alertInfo,
        button: data is Map ? data['button'] as String? : null,
      );
    }
    return BackendAlertStatusResult(alert: alertInfo);
  }

  // =========================================================================
  // Recording
  // =========================================================================

  @override
  Future<BackendRecordingResult> startRecording(
    BackendCommandContext ctx,
    BackendRecordingOptions? options,
  ) async {
    final outPath = options?.outPath;
    if (outPath == null || outPath.isEmpty) {
      throw AppError(
        AppErrorCodes.invalidArgs,
        'iOS startRecording requires options.outPath.',
      );
    }
    final udid = _udid(ctx);
    final kind = await _resolveKind(udid);

    if (kind == 'simulator') {
      return _startSimulatorRecording(udid, outPath);
    }
    return _startDeviceRecording(ctx, options);
  }

  Future<BackendRecordingResult> _startSimulatorRecording(
    String udid,
    String outPath,
  ) async {
    // Kill any stale simctl recordVideo process from a prior invocation.
    final existing = await _readIosRecorder(udid);
    if (existing != null) {
      _signalProcess(existing.pid, ProcessSignal.sigint);
      await Future<void>.delayed(const Duration(milliseconds: 500));
      await _deleteIosRecorder(udid);
    }
    // Spawn `xcrun simctl io <udid> recordVideo <outPath>` as a
    // detached background process — matches upstream TS which uses
    // `runCmdBackground('xcrun', ['simctl', 'io', udid, 'recordVideo', outPath])`.
    final dst = File(outPath);
    await dst.parent.create(recursive: true);
    final process = await Process.start(
      'xcrun',
      ['simctl', 'io', udid, 'recordVideo', outPath],
      mode: ProcessStartMode.detached,
    );
    await _writeIosRecorder(
      _IosRecorderRecord(udid: udid, pid: process.pid, outPath: outPath),
    );
    // Brief settle window — simctl needs a moment to open the output file.
    await Future<void>.delayed(const Duration(milliseconds: 500));
    return BackendRecordingResult(path: outPath);
  }

  Future<BackendRecordingResult> _startDeviceRecording(
    BackendCommandContext ctx,
    BackendRecordingOptions? options,
  ) async {
    final session = await _runner(ctx);
    final bundleId = ctx.appBundleId ?? ctx.appId;
    if (bundleId == null || bundleId.isEmpty) {
      throw AppError(
        AppErrorCodes.invalidArgs,
        'iOS device recording requires an open app. Run '
        '`agent-device open <bundleId>` first.',
      );
    }
    final outPath = options!.outPath!;
    final fileName = p.basename(outPath);
    const recordTimeout = Duration(seconds: 90);
    RunnerResponse res = await IosRunnerClient.send(session, {
      'command': 'recordStart',
      'outPath': fileName,
      'appBundleId': bundleId,
      if (options.fps != null) 'fps': options.fps,
      if (options.quality != null) 'quality': options.quality,
    }, timeout: recordTimeout);
    if (!res.ok &&
        (res.errorMessage ?? '').contains('recording already in progress')) {
      await IosRunnerClient.send(session, {
        'command': 'recordStop',
        'appBundleId': bundleId,
      }, timeout: recordTimeout);
      res = await IosRunnerClient.send(session, {
        'command': 'recordStart',
        'outPath': fileName,
        'appBundleId': bundleId,
        if (options.fps != null) 'fps': options.fps,
        if (options.quality != null) 'quality': options.quality,
      }, timeout: recordTimeout);
    }
    if (!res.ok) {
      throw AppError(
        AppErrorCodes.commandFailed,
        'iOS runner recordStart failed: ${res.errorMessage ?? 'unknown'}',
      );
    }
    return BackendRecordingResult(path: outPath);
  }

  @override
  Future<BackendRecordingResult> stopRecording(
    BackendCommandContext ctx,
    BackendRecordingOptions? options,
  ) async {
    final outPath = options?.outPath;
    if (outPath == null || outPath.isEmpty) {
      throw AppError(
        AppErrorCodes.invalidArgs,
        'iOS stopRecording requires options.outPath (the same path passed to '
        'startRecording).',
      );
    }
    final udid = _udid(ctx);
    final kind = await _resolveKind(udid);

    if (kind == 'simulator') {
      return _stopSimulatorRecording(udid, outPath);
    }
    return _stopDeviceRecording(ctx, outPath);
  }

  /// Stop a simulator recording started via `simctl io recordVideo`.
  /// Uses multi-stage signal escalation (SIGINT → SIGTERM → SIGKILL)
  /// matching upstream cd55a6a5.
  Future<BackendRecordingResult> _stopSimulatorRecording(
    String udid,
    String outPath,
  ) async {
    final record = await _readIosRecorder(udid);
    if (record == null) {
      throw AppError(
        AppErrorCodes.commandFailed,
        'No iOS simulator recording in progress for $udid.',
      );
    }
    // Multi-stage signal escalation: SIGINT lets simctl finalize the
    // moov atom cleanly. Escalate to SIGTERM then SIGKILL if it doesn't
    // exit in time.
    bool stopped = false;
    for (final signal in [
      ProcessSignal.sigint,
      ProcessSignal.sigterm,
      ProcessSignal.sigkill,
    ]) {
      _signalProcess(record.pid, signal);
      // Also try pgrep fallback for orphaned processes.
      if (signal != ProcessSignal.sigint) {
        await _signalMatchingSimctlRecorders(udid, signal);
      }
      await Future<void>.delayed(
        signal == ProcessSignal.sigint
            ? const Duration(seconds: 5)
            : const Duration(seconds: 2),
      );
      if (!_isProcessAlive(record.pid)) {
        stopped = true;
        break;
      }
    }
    await _deleteIosRecorder(udid);
    if (!stopped) {
      return BackendRecordingResult(
        path: outPath,
        warning: 'simctl recordVideo process ${record.pid} did not exit '
            'after signal escalation.',
      );
    }
    // Wait briefly for the file to stabilize.
    await Future<void>.delayed(const Duration(milliseconds: 500));
    final file = File(outPath);
    if (!await file.exists()) {
      return BackendRecordingResult(
        path: outPath,
        warning: 'Recording file did not appear at $outPath.',
      );
    }
    return BackendRecordingResult(path: outPath);
  }

  /// Stop a device recording via the runner's recordStop command.
  Future<BackendRecordingResult> _stopDeviceRecording(
    BackendCommandContext ctx,
    String outPath,
  ) async {
    final session = await _runner(ctx);
    final bundleId = ctx.appBundleId ?? ctx.appId;
    const stopTimeout = Duration(seconds: 60);
    final res = await IosRunnerClient.send(session, {
      'command': 'recordStop',
      'appBundleId': ?bundleId,
    }, timeout: stopTimeout);
    if (!res.ok) {
      throw AppError(
        AppErrorCodes.commandFailed,
        'iOS runner recordStop failed: ${res.errorMessage ?? 'unknown'}',
      );
    }
    final resolved = await _findLatestResolvedRecordingPath(session.logPath);
    if (resolved == null) {
      return BackendRecordingResult(
        path: outPath,
        warning:
            'Runner log did not report a resolvedOutPath. Recording file '
            'location is unknown; check ${session.logPath}.',
      );
    }
    final dst = File(outPath);
    await dst.parent.create(recursive: true);

    // On device: pull the file from the runner's sandbox via devicectl.
    final remotePath = 'tmp/${p.basename(resolved)}';
    final bundles = _iosRunnerContainerBundleIds();
    int? lastExit;
    String lastStderr = '';
    String lastBundle = '';
    for (final bundleCandidate in bundles) {
      final pull = await runCmd('xcrun', [
        'devicectl',
        'device',
        'copy',
        'from',
        '--device',
        _udid(ctx),
        '--source',
        remotePath,
        '--destination',
        outPath,
        '--domain-type',
        'appDataContainer',
        '--domain-identifier',
        bundleCandidate,
      ], const ExecOptions(allowFailure: true, timeoutMs: 60000));
      if (pull.exitCode == 0) {
        return BackendRecordingResult(path: outPath);
      }
      lastExit = pull.exitCode;
      lastStderr = pull.stderr.trim();
      lastBundle = bundleCandidate;
    }
    return BackendRecordingResult(
      path: outPath,
      warning:
          'devicectl copy from $remotePath failed across ${bundles.length} '
          'container bundle(s). Last tried "$lastBundle" '
          '(exit $lastExit): $lastStderr',
    );
  }

  static Future<String?> _findLatestResolvedRecordingPath(
    String logPath,
  ) async {
    final file = File(logPath);
    if (!await file.exists()) return null;
    try {
      final text = await file.readAsString();
      final re = RegExp(
        r'AGENT_DEVICE_RUNNER_RECORD_START\b[^\n]*\bresolvedOutPath=(\S+)',
      );
      final matches = re.allMatches(text).toList();
      if (matches.isEmpty) return null;
      return matches.last.group(1);
    } catch (_) {
      return null;
    }
  }

  // =========================================================================
  // Diagnostics: Log streaming (background)
  // =========================================================================

  /// Start tailing device logs for the ctx's iOS device into
  /// [options.outPath]. The PID is persisted at
  /// `<stateDir>/log-streams/<udid>.json` so a later invocation can
  /// [stopLogStream]. If an existing record is present we SIGINT its
  /// pid first so we don't leak tails.
  ///
  /// Simulator: `xcrun simctl spawn <udid> log stream --predicate …`
  /// filtered to the session's open app bundle id.
  ///
  /// Physical device: `xcrun devicectl device log stream --device <id>`.
  /// devicectl doesn't accept an os_log predicate, so the full stream
  /// is captured; filtering to a bundle id is a post-hoc grep job.
  @override
  Future<BackendLogStreamResult> startLogStream(
    BackendCommandContext ctx,
    BackendLogStreamOptions options,
  ) async {
    final udid = _udid(ctx);
    final kind = await _resolveKind(udid);
    final outPath = options.outPath;
    if (outPath == null || outPath.isEmpty) {
      throw AppError(
        AppErrorCodes.invalidArgs,
        'iOS startLogStream requires options.outPath.',
      );
    }

    // Stop any existing stream for this device so we don't duplicate.
    final existing = await readLogStreamRecord(udid);
    if (existing != null) {
      killLogStreamPid(existing.hostPid);
      await deleteLogStreamRecord(udid);
    }

    final outFile = File(outPath);
    await outFile.parent.create(recursive: true);

    final String script;
    final String backendLabel;
    final String? bundleId;
    if (kind == 'device') {
      // Xcode's `devicectl` has no `log stream` subcommand (at least
      // through Xcode 16.x), so we fall back to `idevicesyslog` from
      // libimobiledevice. Probe its presence early so the error is
      // helpful rather than a cryptic child-process exit.
      final which = await runCmd('which', const [
        'idevicesyslog',
      ], const ExecOptions(allowFailure: true, timeoutMs: 2000));
      if (which.exitCode != 0 || which.stdout.trim().isEmpty) {
        throw AppError(
          AppErrorCodes.toolMissing,
          'iOS physical-device log streaming needs `idevicesyslog` (not '
          'shipped with Xcode). Install libimobiledevice: '
          '`brew install libimobiledevice`, then retry.',
        );
      }
      final binPath = which.stdout.trim().split('\n').first;
      // idevicesyslog doesn't support predicate filtering; caller greps
      // post-hoc. appBundleId goes on the disk record for reference.
      bundleId = options.appBundleId ?? ctx.appBundleId ?? ctx.appId;
      script =
          'exec ${_shellQuote(binPath)} -u ${_shellQuote(udid)} '
          '> ${_shellQuote(outPath)} 2>&1';
      backendLabel = 'ios-device-log-stream-idevicesyslog';
    } else {
      bundleId = options.appBundleId ?? ctx.appBundleId ?? ctx.appId;
      if (bundleId == null || bundleId.isEmpty) {
        throw AppError(
          AppErrorCodes.invalidArgs,
          'iOS simulator startLogStream requires an open app (run '
          '`agent-device open <bundleId>` first).',
        );
      }
      final executableName = await _resolveIosSimulatorExecutableName(
        udid: udid,
        appBundleId: bundleId,
      );
      final predicate = _buildAppleLogPredicate(bundleId, executableName);
      script =
          'exec xcrun simctl spawn '
          '${_shellQuote(udid)} log stream '
          '--style compact --level info '
          '--predicate ${_shellQuote(predicate)} '
          '> ${_shellQuote(outPath)} 2>&1';
      backendLabel = 'ios-simulator-log-stream';
    }

    final proc = await runCmdDetached('sh', [
      '-c',
      script,
    ], const ExecDetachedOptions());
    final startedAt = DateTime.now().toUtc().toIso8601String();
    await writeLogStreamRecord(
      LogStreamRecord(
        deviceId: udid,
        platform: 'ios',
        hostPid: proc.pid,
        outPath: outPath,
        startedAt: startedAt,
        appBundleId: bundleId,
      ),
    );
    return BackendLogStreamResult(
      outPath: outPath,
      hostPid: proc.pid,
      backend: backendLabel,
      startedAt: startedAt,
    );
  }

  @override
  Future<BackendLogStreamResult> stopLogStream(
    BackendCommandContext ctx,
  ) async {
    final udid = _udid(ctx);
    final record = await readLogStreamRecord(udid);
    if (record == null) {
      throw AppError(
        AppErrorCodes.commandFailed,
        'No active log stream for iOS device $udid.',
      );
    }
    final delivered = killLogStreamPid(record.hostPid);
    // Give the tail a beat to flush any buffered lines.
    await Future<void>.delayed(const Duration(milliseconds: 400));
    await deleteLogStreamRecord(udid);
    int? bytes;
    final f = File(record.outPath);
    if (await f.exists()) bytes = await f.length();
    // Re-derive the backend label from the device kind so stop reports
    // the same variant that start recorded (simulator vs physical).
    final kind = await _resolveKind(udid);
    final backend = kind == 'device'
        ? 'ios-device-log-stream-idevicesyslog'
        : 'ios-simulator-log-stream';
    return BackendLogStreamResult(
      outPath: record.outPath,
      hostPid: record.hostPid,
      backend: backend,
      startedAt: record.startedAt,
      stoppedAt: DateTime.now().toUtc().toIso8601String(),
      bytes: bytes,
      stale: !delivered,
    );
  }

  // =========================================================================
  // Diagnostics: Performance sampling
  // =========================================================================

  /// Sample CPU + resident memory for the session's open app.
  ///
  /// Simulator path: `simctl spawn /bin/ps -axo pid,%cpu,rss,command`
  /// filtered by the app's `CFBundleExecutable`, reports aggregate
  /// `cpu` (percent) and `memory.resident` (kB).
  ///
  /// Physical-device path: two consecutive `xctrace record --template
  /// 'Activity Monitor' --time-limit 1s` traces + XML export. Filters
  /// rows whose process name contains the bundle id's last segment,
  /// diffs `cpu-total` per pid across the two captures, and reports
  /// aggregate `cpu` (percent) + `memory.resident` (kB) from the
  /// second snapshot. Multi-core processes can exceed 100%, matching
  /// `top` semantics. Total wall time is roughly two xctrace
  /// invocations (~15-20s).
  @override
  Future<BackendMeasurePerfResult> measurePerf(
    BackendCommandContext ctx,
    BackendMeasurePerfOptions? options,
  ) async {
    final udid = _udid(ctx);
    final kind = await _resolveKind(udid);
    final bundleId = ctx.appBundleId ?? ctx.appId;
    if (bundleId == null || bundleId.isEmpty) {
      throw AppError(
        AppErrorCodes.invalidArgs,
        'iOS measurePerf requires an open app '
        '(run `agent-device open <bundleId>` first).',
      );
    }
    final requested = options?.metrics?.map((e) => e.toLowerCase()).toSet();
    final wantCpu = requested == null || requested.contains('cpu');
    final wantMemory = requested == null || requested.contains('memory');
    final wantFps = requested == null || requested.contains('fps');

    // Physical device: xctrace 1s activity-monitor + XML parse. Match
    // rows by bundleId's last segment (typical CFBundleExecutable form)
    // and by full bundleId as a fallback.
    // Frame perf uses xctrace Animation Hitches with PIDs from devicectl.
    if (kind == 'device') {
      final lastSegment = bundleId.split('.').last.toLowerCase();
      // Resolve running PIDs for frame perf (also used to refine CPU/memory
      // process matching by process name).
      final processes = await resolveIosDevicePerfTarget(udid, bundleId);
      final targetPids = processes.map((p) => p.pid).toList();
      final targetNames = processes
          .map((p) => p.executable.split('/').last)
          .where((n) => n.isNotEmpty)
          .toSet()
          .toList();

      // Run frame perf and CPU/memory concurrently to reduce total wall time.
      final frameFuture = wantFps
          ? sampleAppleFramePerf(
              udid,
              bundleId,
              targetPids: targetPids,
              targetProcessNames: targetNames,
            ).then<AppleFramePerfSample?>((s) => s).catchError((_) => null)
          : Future<AppleFramePerfSample?>.value(null);

      final sample = await sampleIosDevicePerfMetrics(
        udid,
        matcherLabel: bundleId,
        processMatcher: (name) {
          final lower = name.toLowerCase();
          return lower.contains(lastSegment) ||
              lower.contains(bundleId.toLowerCase());
        },
      );
      final frameSample = await frameFuture;

      final metrics = <BackendPerfMetric>[];
      if (wantCpu) {
        metrics.add(
          BackendPerfMetric(
            name: 'cpu',
            value: sample.cpu.usagePercent,
            unit: 'percent',
            status: 'ok',
            metadata: {
              'method': sample.cpu.method,
              'description':
                  'Per-core CPU% derived by diffing cpu-total across two '
                  'xctrace captures, aggregated across matched processes. '
                  'Multi-core processes can exceed 100%.',
              'matchedProcesses': sample.cpu.matchedProcesses,
              'measuredAt': sample.cpu.measuredAt,
            },
          ),
        );
      }
      if (wantMemory) {
        metrics.add(
          BackendPerfMetric(
            name: 'memory.resident',
            value: sample.memory.residentMemoryKb.toDouble(),
            unit: 'kB',
            status: 'ok',
            metadata: {
              'method': sample.memory.method,
              'description':
                  'memory-real bytes from the second xctrace capture, '
                  'aggregated across matched processes.',
              'matchedProcesses': sample.memory.matchedProcesses,
              'measuredAt': sample.memory.measuredAt,
            },
          ),
        );
      }
      if (wantFps && frameSample != null) {
        metrics.add(
          BackendPerfMetric(
            name: 'fps',
            value: frameSample.droppedFramePercent,
            unit: 'percent',
            status: 'ok',
            metadata: {
              'method': frameSample.method,
              'description': appleFrameSampleDescription,
              'droppedFrameCount': frameSample.droppedFrameCount,
              'totalFrameCount': frameSample.totalFrameCount,
              'sampleWindowMs': frameSample.sampleWindowMs,
              'matchedProcesses': frameSample.matchedProcesses,
              'measuredAt': frameSample.measuredAt,
              if (frameSample.refreshRateHz != null)
                'refreshRateHz': frameSample.refreshRateHz,
              if (frameSample.frameDeadlineMs != null)
                'frameDeadlineMs': frameSample.frameDeadlineMs,
              if (frameSample.worstWindows != null)
                'worstWindows': frameSample.worstWindows!
                    .map((w) => w.toJson())
                    .toList(),
            },
          ),
        );
      }
      return BackendMeasurePerfResult(
        metrics: metrics,
        startedAt: sample.cpu.measuredAt,
        endedAt: sample.cpu.measuredAt,
        backend: 'ios-device-xctrace',
      );
    }

    final sample = await sampleIosSimulatorPerfMetrics(udid, bundleId);
    final metrics = <BackendPerfMetric>[];
    if (wantCpu) {
      metrics.add(
        BackendPerfMetric(
          name: 'cpu',
          value: sample.cpu.usagePercent,
          unit: 'percent',
          status: 'ok',
          metadata: {
            'method': sample.cpu.method,
            'description':
                'Recent CPU usage snapshot aggregated across the bundle\'s '
                'processes inside the iOS simulator.',
            'matchedProcesses': sample.cpu.matchedProcesses,
            'measuredAt': sample.cpu.measuredAt,
          },
        ),
      );
    }
    if (wantMemory) {
      metrics.add(
        BackendPerfMetric(
          name: 'memory.resident',
          value: sample.memory.residentMemoryKb.toDouble(),
          unit: 'kB',
          status: 'ok',
          metadata: {
            'method': sample.memory.method,
            'description':
                'Resident memory snapshot aggregated across the bundle\'s '
                'processes inside the iOS simulator.',
            'matchedProcesses': sample.memory.matchedProcesses,
            'measuredAt': sample.memory.measuredAt,
          },
        ),
      );
    }
    return BackendMeasurePerfResult(
      metrics: metrics,
      startedAt: sample.cpu.measuredAt,
      endedAt: sample.cpu.measuredAt,
      backend: 'ios-simulator-ps',
    );
  }

  // =========================================================================
  // Diagnostics: Logs (one-shot)
  // =========================================================================

  /// Dump recent os_log output filtered to the session's app bundle id.
  /// Simulator only — shells out to `xcrun simctl spawn [udid] log show
  /// --predicate ...`. For physical devices there's no equivalent
  /// one-shot (Apple's `log show` only works on the host itself or on
  /// a simulator), so `readLogs` raises `UNSUPPORTED_OPERATION` there;
  /// use [startLogStream] / [stopLogStream] instead — that path works
  /// on physical iOS via `idevicesyslog`.
  @override
  Future<BackendReadLogsResult> readLogs(
    BackendCommandContext ctx,
    BackendReadLogsOptions? options,
  ) async {
    final udid = _udid(ctx);
    final kind = await _resolveKind(udid);
    if (kind == 'device') {
      throw AppError(
        AppErrorCodes.unsupportedOperation,
        'iOS physical-device one-shot `logs` isn\'t available — Apple\'s '
        '`log show` only targets the host or a simulator. Use '
        '`agent-device logs --stream --out <path>` / `logs --stop` '
        'instead (streams via idevicesyslog).',
      );
    }
    final bundleId = ctx.appBundleId ?? ctx.appId;
    if (bundleId == null || bundleId.isEmpty) {
      throw AppError(
        AppErrorCodes.invalidArgs,
        'iOS readLogs requires an open app. Run `agent-device open <bundleId>` '
        'first so we know which app\'s logs to filter to.',
      );
    }
    final executableName = await _resolveIosSimulatorExecutableName(
      udid: udid,
      appBundleId: bundleId,
    );
    final predicate = _buildAppleLogPredicate(bundleId, executableName);
    final args = <String>[
      'simctl',
      'spawn',
      udid,
      'log',
      'show',
      '--style',
      'compact',
      '--info',
      '--predicate',
      predicate,
    ];
    final since = options?.since?.trim();
    // `--last` values are of the form <digits><s|m|h|d>. Anything else we
    // pass through as `--start` so callers can hand in `@<epoch>` or an
    // ISO timestamp.
    if (since != null && since.isNotEmpty) {
      if (RegExp(r'^\d+[smhd]$').hasMatch(since)) {
        args.addAll(['--last', since]);
      } else {
        args.addAll(['--start', since]);
      }
    } else {
      args.addAll(['--last', '5m']);
    }
    final r = await runCmd(
      'xcrun',
      args,
      const ExecOptions(allowFailure: true, timeoutMs: 15000),
    );
    if (r.exitCode != 0) {
      throw AppError(
        AppErrorCodes.commandFailed,
        'simctl log show failed (exit ${r.exitCode}).',
        details: {
          'stderr': r.stderr,
          'stdout': r.stdout,
          'exitCode': r.exitCode,
        },
      );
    }
    final rawLines = r.stdout.split('\n');
    final entries = <BackendLogEntry>[];
    for (final raw in rawLines) {
      final line = raw.trimRight();
      if (line.trim().isEmpty) continue;
      // `log show --style compact` prints a fixed header line once; skip it.
      if (line.startsWith('Timestamp               Ty Process[PID:TID]')) {
        continue;
      }
      entries.add(BackendLogEntry(message: line));
    }
    final limit = options?.limit;
    final trimmed = (limit != null && limit > 0 && entries.length > limit)
        ? entries.sublist(entries.length - limit)
        : entries;
    return BackendReadLogsResult(entries: trimmed, backend: 'ios-simulator');
  }

  @override
  Future<BackendActionResult> pinch(
    BackendCommandContext ctx,
    BackendPinchOptions options,
  ) async {
    final session = await _runner(ctx);
    await _sendOrThrow(session, {
      'command': 'pinch',
      'scale': options.scale,
      if (options.center != null) 'x': options.center!.x.round(),
      if (options.center != null) 'y': options.center!.y.round(),
    });
    return null;
  }

  @override
  Future<BackendActionResult> adjustSlider(
    BackendCommandContext ctx,
    BackendAdjustSliderOptions options,
  ) async {
    final session = await _runner(ctx);
    final bundleId = _appBundleId(ctx);
    await _sendOrThrow(session, {
      'command': 'adjustSlider',
      'appBundleId': ?bundleId,
      if (options.target != null) 'x': options.target!.x,
      if (options.target != null) 'y': options.target!.y,
      if (options.normalizedPosition != null)
        'normalizedPosition': options.normalizedPosition,
      'action': options.action,
      // Runner field is `sliderSteps` (Int): renamed from `steps` so it doesn't
      // collide with the sequence command's `steps: [SequenceStep]` array.
      'sliderSteps': options.steps,
      if (options.elementRect != null) 'rectX': options.elementRect!.x,
      if (options.elementRect != null) 'rectY': options.elementRect!.y,
      if (options.elementRect != null) 'rectW': options.elementRect!.width,
      if (options.elementRect != null) 'rectH': options.elementRect!.height,
    });
    return null;
  }

  @override
  Future<String> getClipboard(BackendCommandContext ctx) async {
    final udid = _udid(ctx);
    final r = await Process.run(
      'xcrun',
      ['simctl', 'pbpaste', udid],
      stdoutEncoding: utf8,
      stderrEncoding: utf8,
    );
    if (r.exitCode != 0) {
      throw AppError(
        AppErrorCodes.commandFailed,
        'Failed to read iOS simulator clipboard.',
        details: {
          'stdout': r.stdout,
          'stderr': r.stderr,
          'exitCode': r.exitCode,
        },
      );
    }
    final text = (r.stdout as String).replaceAll('\r\n', '\n');
    return text.endsWith('\n') ? text.substring(0, text.length - 1) : text;
  }

  @override
  Future<BackendActionResult> setClipboard(
    BackendCommandContext ctx,
    String text,
  ) async {
    final udid = _udid(ctx);
    final proc = await Process.start('xcrun', ['simctl', 'pbcopy', udid]);
    proc.stdin.add(utf8.encode(text));
    await proc.stdin.close();
    final exitCode = await proc.exitCode;
    if (exitCode != 0) {
      final err = await proc.stderr.transform(utf8.decoder).join();
      throw AppError(
        AppErrorCodes.commandFailed,
        'Failed to write iOS simulator clipboard.',
        details: {'stderr': err, 'exitCode': exitCode},
      );
    }
    return null;
  }

  // =========================================================================
  // Settings
  // =========================================================================

  /// Set an iOS simulator setting.
  ///
  /// Supports:
  /// - `location set` → `xcrun simctl location <udid> set <lat>,<lon>`
  /// - `location on/off` → `xcrun simctl privacy <udid> grant/revoke location <bundleId>`
  ///
  /// Other settings throw [AppErrorCodes.unsupportedOperation].
  @override
  Future<Map<String, Object?>?> setSetting(
    BackendCommandContext ctx,
    String setting,
    String state, [
    Map<String, Object?>? options,
  ]) async {
    final udid = _udid(ctx);
    final normalized = setting.toLowerCase();
    if (normalized == 'location') {
      if (state.toLowerCase() == 'set') {
        final lat = (options?['latitude'] as num?)?.toDouble();
        final lon = (options?['longitude'] as num?)?.toDouble();
        final coords = requireLocationCoordinates(lat, lon);
        final r = await runCmd(
          'xcrun',
          [
            'simctl',
            'location',
            udid,
            'set',
            '${coords.latitude},${coords.longitude}',
          ],
          const ExecOptions(allowFailure: true, timeoutMs: 15000),
        );
        if (r.exitCode != 0) {
          throw AppError(
            AppErrorCodes.commandFailed,
            'simctl location set failed for $udid',
            details: {
              'stdout': r.stdout,
              'stderr': r.stderr,
              'exitCode': r.exitCode,
            },
          );
        }
        return {'latitude': coords.latitude, 'longitude': coords.longitude};
      }
      final enabled = parseSettingState(state);
      final bundleId = _appBundleId(ctx);
      if (bundleId == null) {
        throw AppError(
          AppErrorCodes.invalidArgs,
          'location setting requires an active app in session',
        );
      }
      final action = enabled ? 'grant' : 'revoke';
      final r = await runCmd(
        'xcrun',
        ['simctl', 'privacy', udid, action, 'location', bundleId],
        const ExecOptions(allowFailure: true, timeoutMs: 15000),
      );
      if (r.exitCode != 0) {
        throw AppError(
          AppErrorCodes.commandFailed,
          'simctl privacy $action location failed for $udid',
          details: {
            'stdout': r.stdout,
            'stderr': r.stderr,
            'exitCode': r.exitCode,
          },
        );
      }
      return null;
    }
    unsupported('setSetting($setting) on iOS');
  }

  // =========================================================================
  // App Management (from Phase 8A)
  // =========================================================================

  @override
  Future<BackendActionResult> openApp(
    BackendCommandContext ctx,
    BackendOpenTarget target,
    BackendOpenOptions? options,
  ) async {
    final bundleId = target.bundleId ?? target.appId ?? target.app;
    if (bundleId == null || bundleId.isEmpty) {
      unsupported(
        'openApp on iOS requires target.bundleId / appId / app (a bundle id)',
      );
    }
    final udid = _udid(ctx);
    final kind = await _resolveKind(udid);
    if (kind == 'device') {
      await launchIosDeviceProcess(udid, bundleId, launchArgs: options?.launchArgs);
    } else {
      await openIosApp(
        udid,
        bundleId,
        launchConsole: options?.launchConsole,
        launchArgs: options?.launchArgs,
      );
    }
    return null;
  }

  @override
  Future<BackendActionResult> closeApp(
    BackendCommandContext ctx, [
    String? app,
  ]) async {
    if (app == null || app.isEmpty) {
      unsupported('closeApp on iOS requires a bundle id');
    }
    final udid = _udid(ctx);
    final kind = await _resolveKind(udid);
    if (kind == 'device') {
      await terminateIosDeviceProcess(udid, app);
    } else {
      await closeIosApp(udid, app);
    }
    return null;
  }

  @override
  Future<List<BackendAppInfo>> listApps(
    BackendCommandContext ctx, [
    BackendAppListFilter? filter,
  ]) async {
    final userOnly = filter == BackendAppListFilter.userInstalled;
    final udid = _udid(ctx);
    final kind = await _resolveKind(udid);
    if (kind == 'device') {
      final apps = await listIosDeviceApps(udid, userOnly: userOnly);
      return apps
          .map(
            (a) => BackendAppInfo(
              id: a.bundleId,
              name: a.name,
              bundleId: a.bundleId,
            ),
          )
          .toList();
    }
    final apps = await listIosApps(udid, userOnly: userOnly);
    return apps
        .map(
          (a) => BackendAppInfo(
            id: a.bundleId,
            name: a.name,
            bundleId: a.bundleId,
          ),
        )
        .toList();
  }

  @override
  Future<BackendAppState> getAppState(
    BackendCommandContext ctx,
    String app,
  ) async {
    final fg = await getIosForeground(_udid(ctx));
    return BackendAppState(
      appId: fg.bundleId,
      bundleId: fg.bundleId,
      state: fg.bundleId == null ? 'unknown' : 'foreground',
    );
  }

  // =========================================================================
  // Install / uninstall / reinstall
  // =========================================================================

  /// Install a `.app` bundle or `.ipa` archive. Simulator paths shell
  /// out to `xcrun simctl install <udid> <path>`; physical-device paths
  /// go through `devicectl device install app`. `.ipa` archives are
  /// unzipped into a tmpdir first and the resolved `.app` is installed
  /// from there. Bundle id + display name are extracted from the
  /// bundle's `Info.plist` and surfaced on the result so the caller
  /// can `open` it without a separate lookup.
  @override
  Future<BackendInstallResult> installApp(
    BackendCommandContext ctx,
    BackendInstallTarget target,
  ) async {
    final source = target.source;
    if (source is! BackendInstallSourcePath) {
      unsupported('iOS installApp requires a path source');
    }
    final prepared = await prepareIosInstallArtifact(
      source.path,
      options: PrepareIosInstallArtifactOptions(appIdentifierHint: target.app),
    );
    try {
      final udid = _udid(ctx);
      final kind = await _resolveKind(udid);
      if (kind == 'device') {
        await installIosDeviceApp(udid, prepared.installablePath);
      } else {
        final r = await runCmd(
          'xcrun',
          buildSimctlArgs(['install', udid, prepared.installablePath]),
          const ExecOptions(allowFailure: true, timeoutMs: 180000),
        );
        if (r.exitCode != 0) {
          throw AppError(
            AppErrorCodes.commandFailed,
            'simctl install failed for ${prepared.installablePath}',
            details: {
              'stdout': r.stdout,
              'stderr': r.stderr,
              'exitCode': r.exitCode,
            },
          );
        }
      }
      return BackendInstallResult(
        appId: prepared.bundleId,
        bundleId: prepared.bundleId,
        appName: prepared.appName,
        launchTarget: prepared.bundleId,
        installablePath: prepared.installablePath,
        archivePath: prepared.archivePath,
      );
    } finally {
      await prepared.cleanup();
    }
  }

  /// Uninstall by bundle id. Returns the resolved bundle id even when
  /// the app wasn't installed — both simctl and devicectl are tolerant
  /// of "not installed" so the caller gets a no-op success rather than
  /// a generic failure.
  @override
  Future<BackendInstallResult> uninstallApp(
    BackendCommandContext ctx,
    String app,
  ) async {
    final bundleId = app.trim();
    if (bundleId.isEmpty) {
      throw AppError(
        AppErrorCodes.invalidArgs,
        'iOS uninstallApp requires a bundle id',
      );
    }
    final udid = _udid(ctx);
    final kind = await _resolveKind(udid);
    if (kind == 'device') {
      await uninstallIosDeviceApp(udid, bundleId);
    } else {
      final r = await runCmd(
        'xcrun',
        buildSimctlArgs(['uninstall', udid, bundleId]),
        const ExecOptions(allowFailure: true, timeoutMs: 60000),
      );
      if (r.exitCode != 0) {
        final combined = '${r.stdout}\n${r.stderr}'.toLowerCase();
        final missing =
            combined.contains('no such') ||
            combined.contains('not installed') ||
            combined.contains('found no app');
        if (!missing) {
          throw AppError(
            AppErrorCodes.commandFailed,
            'simctl uninstall failed for $bundleId',
            details: {
              'stdout': r.stdout,
              'stderr': r.stderr,
              'exitCode': r.exitCode,
            },
          );
        }
      }
    }
    return BackendInstallResult(
      appId: bundleId,
      bundleId: bundleId,
      launchTarget: bundleId,
    );
  }

  /// Uninstall + reinstall in one shot. The uninstall is best-effort
  /// — if the app isn't installed we still proceed with the install
  /// so the caller can use this as an "ensure installed" primitive.
  @override
  Future<BackendInstallResult> reinstallApp(
    BackendCommandContext ctx,
    BackendInstallTarget target,
  ) async {
    final hint = target.app?.trim();
    if (hint != null && hint.isNotEmpty) {
      await uninstallApp(ctx, hint);
    }
    return installApp(ctx, target);
  }

  @override
  Future<void> resetKeychain(BackendCommandContext ctx) async {
    final udid = _udid(ctx);
    final r = await runCmd('xcrun', ['simctl', 'keychain', udid, 'reset']);
    if (r.exitCode != 0) {
      throw AppError(
        AppErrorCodes.commandFailed,
        'simctl keychain reset failed for $udid',
        details: {'stderr': r.stderr, 'exitCode': r.exitCode},
      );
    }
  }

  @override
  Future<List<BackendDeviceInfo>> listDevices(
    BackendCommandContext ctx, [
    BackendDeviceFilter? filter,
  ]) => listAppleDevices();

  /// Resolve whether [udid] is a simulator or a physical device. Physical
  /// iOS devices go through `devicectl`; simulators go through `simctl`.
  /// Cached for the process lifetime to avoid repeat enumeration on every
  /// action. Unknown UDIDs default to `simulator` to preserve the
  /// pre-devicectl behaviour.
  Future<String> _resolveKind(String udid) async {
    final cached = _IosKindCache.instance.get(udid);
    if (cached != null) return cached;
    final devices = await listAppleDevices();
    final match = devices.firstWhere(
      (d) => d.id == udid,
      orElse: () => BackendDeviceInfo(
        id: udid,
        name: udid,
        platform: AgentDeviceBackendPlatform.ios,
        kind: 'simulator',
      ),
    );
    final kind = match.kind ?? 'simulator';
    _IosKindCache.instance.set(udid, kind);
    return kind;
  }
}

/// Returns true when the iOS interactive snapshot presentation pipeline should
/// be applied.  Mirrors `shouldPresentIosInteractiveSnapshot` in the upstream
/// `snapshot-capture.ts` handler: interactiveOnly flag set and raw mode off.
bool _shouldPresentIosInteractiveSnapshot(BackendSnapshotOptions? options) {
  return options?.interactiveOnly == true && options?.raw != true;
}

String _shellQuote(String s) => "'${s.replaceAll("'", r"'\''")}'";

/// Build an `os_log` predicate string that matches logs from [appBundleId].
/// When [executableName] is provided (the app's `CFBundleExecutable`), additional
/// clauses are added to match process-name-based log entries that don't use
/// a bundle-id subsystem (common in apps that use non-framework logging).
String _buildAppleLogPredicate(String appBundleId, [String? executableName]) {
  final escapedBundleId = _escapeAppleLogPredicateString(appBundleId);
  final clauses = [
    'subsystem == "$escapedBundleId"',
    // App frameworks/extensions often log through subsystem names prefixed by
    // the app bundle id.
    'subsystem CONTAINS "$escapedBundleId"',
    'processImagePath ENDSWITH[c] "/$escapedBundleId"',
    'senderImagePath ENDSWITH[c] "/$escapedBundleId"',
  ];
  if (executableName != null && executableName.isNotEmpty) {
    final escapedExec = _escapeAppleLogPredicateString(executableName);
    clauses.addAll([
      'process == "$escapedExec"',
      'processImagePath ENDSWITH[c] "/$escapedExec"',
      'senderImagePath ENDSWITH[c] "/$escapedExec"',
      'processImagePath CONTAINS[c] "/$escapedExec.app/"',
      'senderImagePath CONTAINS[c] "/$escapedExec.app/"',
    ]);
  }
  return clauses.join(' OR ');
}

String _escapeAppleLogPredicateString(String value) =>
    value.replaceAll(r'\', r'\\').replaceAll('"', r'\"');

/// Resolve the `CFBundleExecutable` name of an installed simulator app via
/// `simctl get_app_container` + `plutil -extract CFBundleExecutable`.
/// Returns `null` on any failure so callers fall back to bundle-id matching.
Future<String?> _resolveIosSimulatorExecutableName({
  required String udid,
  required String appBundleId,
}) async {
  final containerResult = await runCmd(
    'xcrun',
    buildSimctlArgs(['get_app_container', udid, appBundleId, 'app']),
    const ExecOptions(allowFailure: true, timeoutMs: 4000),
  );
  if (containerResult.exitCode != 0) return null;
  final appPath = containerResult.stdout.trim();
  if (appPath.isEmpty) return null;
  final plistPath = p.join(appPath, 'Info.plist');
  final executableResult = await runCmd(
    'plutil',
    ['-extract', 'CFBundleExecutable', 'raw', '-o', '-', plistPath],
    const ExecOptions(allowFailure: true, timeoutMs: 4000),
  );
  if (executableResult.exitCode != 0) return null;
  final name = executableResult.stdout.trim();
  return name.isNotEmpty ? name : null;
}

Future<void> _sendOrThrow(
  IosRunnerSession session,
  Map<String, Object?> body,
) async {
  final res = await IosRunnerClient.send(session, body);
  if (!res.ok) {
    throw await enrichRunnerFailureFromLog(
      error: AppError(
        AppErrorCodes.commandFailed,
        'iOS runner ${body['command']} failed: '
        '${res.errorMessage ?? 'unknown error'}',
        details: {'command': body['command'], 'logPath': session.logPath},
      ),
      logPath: session.logPath,
    );
  }
}

String _orientationToken(BackendDeviceOrientation o) => switch (o) {
  BackendDeviceOrientation.portrait => 'portrait',
  BackendDeviceOrientation.portraitUpsideDown => 'portrait-upside-down',
  BackendDeviceOrientation.landscapeLeft => 'landscape-left',
  BackendDeviceOrientation.landscapeRight => 'landscape-right',
};

RawSnapshotNode? _rawNodeFromJson(Object? entry) {
  if (entry is! Map) return null;
  final index = entry['index'] as int? ?? -1;
  if (index < 0) return null;
  final rectJson = entry['rect'];
  Rect? rect;
  if (rectJson is Map) {
    final x = (rectJson['x'] as num?)?.toDouble();
    final y = (rectJson['y'] as num?)?.toDouble();
    final w = (rectJson['width'] as num?)?.toDouble();
    final h = (rectJson['height'] as num?)?.toDouble();
    if (x != null && y != null && w != null && h != null) {
      rect = Rect(x: x, y: y, width: w, height: h);
    }
  }
  return RawSnapshotNode(
    index: index,
    type: entry['type'] as String?,
    role: entry['role'] as String?,
    subrole: entry['subrole'] as String?,
    label: entry['label'] as String?,
    value: entry['value'] as String?,
    identifier: entry['identifier'] as String?,
    rect: rect,
    enabled: entry['enabled'] as bool?,
    selected: entry['selected'] as bool?,
    hittable: entry['hittable'] as bool?,
    depth: entry['depth'] as int?,
    parentIndex: entry['parentIndex'] as int?,
    pid: entry['pid'] as int?,
    bundleId: entry['bundleId'] as String?,
    appName: entry['appName'] as String?,
    windowTitle: entry['windowTitle'] as String?,
    surface: entry['surface'] as String?,
    hiddenContentAbove: entry['hiddenContentAbove'] as bool?,
    hiddenContentBelow: entry['hiddenContentBelow'] as bool?,
  );
}

/// Module-level cache so multiple [IosBackend] calls in the same process
/// reuse the same runner. Cross-process caching is a future improvement
/// that requires Phase 6B's disk store to carry the runner `{pid, port}`
/// on the session record.
class _IosRunnerCache {
  _IosRunnerCache._();
  static final _IosRunnerCache instance = _IosRunnerCache._();

  final Map<String, IosRunnerSession> _sessions = {};

  IosRunnerSession? get(String udid) => _sessions[udid];
  void set(String udid, IosRunnerSession session) => _sessions[udid] = session;
  IosRunnerSession? pop(String udid) => _sessions.remove(udid);
}

/// Per-process cache of UDID → kind (`simulator` | `device`). Avoids a
/// full `simctl list` + `devicectl list` round-trip on every app action.
class _IosKindCache {
  _IosKindCache._();
  static final _IosKindCache instance = _IosKindCache._();

  final Map<String, String> _kinds = {};

  String? get(String udid) => _kinds[udid];
  void set(String udid, String kind) => _kinds[udid] = kind;
}

// ---------------------------------------------------------------------------
// iOS simulator recording PID management
// ---------------------------------------------------------------------------
// Mirrors the Android `_AndroidRecorderRecord` pattern: persist the host-side
// PID of `simctl io recordVideo` so a later CLI invocation can stop it.

class _IosRecorderRecord {
  final String udid;
  final int pid;
  final String outPath;

  const _IosRecorderRecord({
    required this.udid,
    required this.pid,
    required this.outPath,
  });

  Map<String, Object?> toJson() => {
    'udid': udid,
    'pid': pid,
    'outPath': outPath,
  };

  static _IosRecorderRecord? fromJson(Object? raw) {
    if (raw is! Map) return null;
    final udid = raw['udid'];
    final pid = raw['pid'];
    final outPath = raw['outPath'];
    if (udid is! String || pid is! int || outPath is! String) return null;
    return _IosRecorderRecord(udid: udid, pid: pid, outPath: outPath);
  }
}

File _iosRecorderFile(String udid) =>
    File(p.join(resolveStatePaths().baseDir, 'ios-recorders', '$udid.json'));

Future<_IosRecorderRecord?> _readIosRecorder(String udid) async {
  final file = _iosRecorderFile(udid);
  if (!await file.exists()) return null;
  try {
    return _IosRecorderRecord.fromJson(
      jsonDecode(await file.readAsString()),
    );
  } catch (_) {
    return null;
  }
}

Future<void> _writeIosRecorder(_IosRecorderRecord record) async {
  final file = _iosRecorderFile(record.udid);
  await file.parent.create(recursive: true);
  await file.writeAsString(jsonEncode(record.toJson()));
}

Future<void> _deleteIosRecorder(String udid) async {
  final file = _iosRecorderFile(udid);
  if (await file.exists()) await file.delete();
}

bool _isProcessAlive(int pid) {
  try {
    return Process.killPid(pid, ProcessSignal.sigcont);
  } catch (_) {
    return false;
  }
}

void _signalProcess(int pid, ProcessSignal signal) {
  try {
    Process.killPid(pid, signal);
  } catch (_) {
    // Process may already be dead.
  }
}

/// Fallback: find orphaned `simctl io <udid> recordVideo` processes via
/// `pgrep -f` and signal them. Catches cases where the PID file was lost.
Future<void> _signalMatchingSimctlRecorders(
  String udid,
  ProcessSignal signal,
) async {
  try {
    final r = await Process.run('pgrep', ['-f', 'simctl io $udid recordVideo']);
    if (r.exitCode != 0) return;
    for (final line in (r.stdout as String).trim().split('\n')) {
      final pid = int.tryParse(line.trim());
      if (pid != null && pid > 0) _signalProcess(pid, signal);
    }
  } catch (_) {
    // pgrep may not be available; best-effort.
  }
}
