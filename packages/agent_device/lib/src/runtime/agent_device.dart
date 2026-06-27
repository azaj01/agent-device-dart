// Dart-native runtime façade over [Backend]. Not a direct TS port — the
// TS source uses `bindCommands` to dynamically attach ~40 methods onto a
// runtime object, which doesn't translate cleanly to Dart. This class
// exposes the same capabilities via typed Dart methods and is the library
// surface other Dart packages consume.
library;

import 'dart:io';

import 'package:agent_device/src/backend/backend.dart';
import 'package:agent_device/src/commands/interaction_targeting.dart';
import 'package:agent_device/src/core/scroll_gesture.dart' show normalizeScrollDurationMs;
import 'package:agent_device/src/platforms/platform_selector.dart';
import 'package:agent_device/src/selectors/selectors.dart';
import 'package:agent_device/src/snapshot/snapshot.dart';
import 'package:agent_device/src/snapshot/unchanged.dart';
import 'package:agent_device/src/utils/errors.dart';
import 'package:agent_device/src/utils/png.dart' as png;

import 'package:agent_device/src/platforms/ios/ios_backend.dart';
import 'package:agent_device/src/utils/scroll_edge_state.dart';

import 'contract.dart';
import 'interaction_target.dart';
import 'session_store.dart';
import 'wait_current_surface.dart';

/// Selector filter used by [AgentDevice.open] to pick which connected
/// device to bind a session to. At least one of [serial], [name], or
/// [platform] should be provided to narrow down multi-device setups.
class DeviceSelector {
  final PlatformSelector? platform;
  final String? serial;
  final String? name;

  const DeviceSelector({this.platform, this.serial, this.name});

  /// True if [device] satisfies this selector's `serial`/`name` constraints.
  /// Platform filtering is applied earlier by [Backend.listDevices]; this only
  /// matches the identity fields. Public so the CLI can match across the
  /// candidate devices of multiple backends during platform auto-detection.
  bool matches(BackendDeviceInfo device) {
    if (serial != null && device.id != serial) return false;
    if (name != null && device.name != name) return false;
    return true;
  }
}

/// The programmatic façade that SDK consumers drive. Construct one via
/// [AgentDevice.open]; every command call resolves the currently-bound
/// device from session state and dispatches to the underlying [Backend].
///
/// Example:
/// ```dart
/// final device = await AgentDevice.open(backend: const AndroidBackend());
/// await device.openApp('settings');
/// final snap = await device.snapshot();
/// print('captured ${snap.nodes.length} nodes');
/// await device.close();
/// ```
class AgentDevice {
  final Backend backend;
  final CommandSessionStore sessions;
  final CommandClock clock;

  /// Name of the session this façade is bound to (default: 'default').
  final String sessionName;

  /// Info about the device that was resolved when [open] ran. Read-only.
  final BackendDeviceInfo device;

  AgentDevice._({
    required this.backend,
    required this.sessions,
    required this.clock,
    required this.sessionName,
    required this.device,
  });

  /// Open a session, resolving one matching device via
  /// [Backend.listDevices] and caching it in the session store.
  ///
  /// If multiple devices match [selector] and none is explicitly
  /// identified by [DeviceSelector.serial] or [DeviceSelector.name],
  /// the first one returned is picked.
  ///
  /// Throws [AppError] with [AppErrorCodes.deviceNotFound] if no device
  /// matches.
  static Future<AgentDevice> open({
    required Backend backend,
    DeviceSelector selector = const DeviceSelector(),
    String sessionName = 'default',
    CommandSessionStore? sessions,
    CommandClock clock = const SystemClock(),
  }) async {
    final store = sessions ?? createMemorySessionStore();
    final BackendDeviceInfo picked;
    if (selector.serial != null && selector.platform != null) {
      // Fast path: the caller pinned an exact device by serial + platform, so
      // address it directly instead of enumerating. Enumeration is expensive
      // per command — Android runs `adb devices -l` plus per-device `getprop`
      // probes (~300ms, and slower with a physical device attached over USB),
      // and iOS shells out to `simctl list`. Commands only need the serial
      // (they address the device by `ctx.deviceSerial`); a wrong serial still
      // surfaces a clear error at command time.
      picked = BackendDeviceInfo(
        id: selector.serial!,
        name: selector.serial!,
        platform: _toBackendPlatform(selector.platform!),
      );
    } else {
      final devices = await backend.listDevices(
        BackendCommandContext(session: sessionName),
        selector.platform == null
            ? null
            : BackendDeviceFilter(
                platform: _toBackendPlatform(selector.platform!),
              ),
      );
      final filtered = devices.where(selector.matches).toList();
      if (filtered.isEmpty) {
        throw AppError(
          AppErrorCodes.deviceNotFound,
          'No device matches the selector',
          details: {
            if (selector.platform != null)
              'platform': platformSelectorToString(selector.platform!),
            if (selector.serial != null) 'serial': selector.serial,
            if (selector.name != null) 'name': selector.name,
            // Label each id with its platform so an iOS udid passed without
            // `--platform` (which would only enumerate one backend) doesn't
            // look like the device "vanished".
            'available': devices
                .map((d) => '${d.id} (${d.platform.name})')
                .toList(),
            if (selector.platform == null)
              'hint':
                  'Only this backend was enumerated. If the target is on '
                  'another platform, pass --platform (e.g. --platform ios).',
          },
        );
      }
      picked = filtered.first;
    }
    // Preserve any existing session fields (appId, metadata, etc.) — we only
    // want to refresh the resolved device. Matters for cross-invocation
    // session sharing: without this merge, every CLI invocation would reset
    // the record to `{name, deviceSerial}` and lose the previously opened app
    // id. Remembering the platform lets the next flagless command skip
    // backend auto-detection.
    final existing = await store.get(sessionName);
    final merged = (existing ?? CommandSessionRecord(name: sessionName))
        .copyWith(
          deviceSerial: picked.id,
          devicePlatform: picked.platform.name,
        );
    await store.set(merged);
    return AgentDevice._(
      backend: backend,
      sessions: store,
      clock: clock,
      sessionName: sessionName,
      device: picked,
    );
  }

  /// Build a [BackendCommandContext] carrying this session's metadata
  /// plus the resolved device serial.
  Future<BackendCommandContext> _ctx() async {
    final record = await sessions.get(sessionName);
    return BackendCommandContext(
      session: sessionName,
      appId: record?.appId,
      appBundleId: record?.appBundleId,
      deviceSerial: record?.deviceSerial ?? device.id,
    );
  }

  /// Persist a session-state mutation. Merges onto the existing record
  /// with [CommandSessionRecord.copyWith] semantics. Pass field names in
  /// [clear] to reset them to `null` (Dart optional-named-parameters can't
  /// distinguish "null" from "not specified", so a sentinel set is needed).
  Future<void> _updateSession({
    String? appId,
    String? appBundleId,
    String? appName,
    SnapshotState? snapshot,
    Set<String> clear = const {},
  }) async {
    final current =
        await sessions.get(sessionName) ??
        CommandSessionRecord(name: sessionName, deviceSerial: device.id);
    await sessions.set(
      current.copyWith(
        appId: appId,
        appBundleId: appBundleId,
        appName: appName,
        snapshot: snapshot,
        clearFields: clear,
      ),
    );
  }

  // =========================================================================
  // Snapshot & Screenshot
  // =========================================================================

  /// Capture a snapshot of the current screen.
  ///
  /// When [forceFull] is true the full tree is always returned even when
  /// the content is identical to the previous snapshot. Set [raw] to true
  /// to bypass all presentation filtering and unchanged detection.
  Future<BackendSnapshotResult> snapshot({
    bool? interactiveOnly,
    bool? compact,
    int? depth,
    String? scope,
    bool? raw,
    bool? forceFull,
  }) async {
    final options = SnapshotOptions(
      interactiveOnly: interactiveOnly,
      compact: compact,
      depth: depth,
      scope: scope,
      raw: raw,
      forceFull: forceFull,
    );

    // Read previous session state before capturing.
    final previousSession = await sessions.get(sessionName);
    final previousSnapshot = previousSession?.snapshot;

    final result = await backend.captureSnapshot(
      await _ctx(),
      BackendSnapshotOptions(
        interactiveOnly: interactiveOnly,
        compact: compact,
        depth: depth,
        scope: scope,
        raw: raw,
      ),
    );

    // Build a SnapshotState for the current capture and attach a
    // presentation key so consecutive snapshots can be compared.
    final rawNodes = result.nodes;
    final nodes = rawNodes == null
        ? <SnapshotNode>[]
        : rawNodes.whereType<SnapshotNode>().toList();
    final currentSnapshot = ensureSnapshotPresentationKey(
      SnapshotState(
        nodes: nodes,
        createdAt: clock.now(),
        truncated: result.truncated,
        backend: result.backend != null
            ? _tryParseSnapshotBackend(result.backend!)
            : null,
        comparisonSafe: null,
      ),
      options,
    );

    // Detect unchanged presentation.
    final unchanged = buildUnchangedSnapshotMetadata(
      previous: previousSnapshot,
      current: currentSnapshot,
      options: options,
      identity: SnapshotIdentity(
        previousAppBundleId: previousSession?.appBundleId,
        currentAppBundleId: result.appBundleId ?? previousSession?.appBundleId,
      ),
    );

    // Persist the new snapshot state to the session.
    await _updateSession(
      appName: result.appName,
      appBundleId: result.appBundleId,
      snapshot: currentSnapshot,
    );

    if (unchanged == null) return result;
    return BackendSnapshotResult(
      nodes: result.nodes,
      truncated: result.truncated,
      backend: result.backend,
      snapshot: result.snapshot,
      analysis: result.analysis,
      warnings: result.warnings,
      appName: result.appName,
      appBundleId: result.appBundleId,
      unchanged: unchanged,
    );
  }

  /// Capture a screenshot to [outPath]. Returns null if the backend
  /// declines (not all backends produce a file).
  ///
  /// When [maxSize] is set, the captured PNG is box-filter downscaled
  /// in place after the backend writes it so the longest edge fits
  /// within [maxSize] pixels. Skipped when the image already fits.
  Future<BackendScreenshotResult?> screenshot(
    String outPath, {
    bool? overlayRefs,
    bool? fullscreen,
    int? maxSize,
    bool? stabilize,
  }) async {
    if (maxSize != null && maxSize < 1) {
      throw AppError(
        AppErrorCodes.invalidArgs,
        'Screenshot max size must be a positive integer',
      );
    }
    final result = await backend.captureScreenshot(
      BackendCommandContext(session: sessionName, deviceSerial: device.id),
      outPath,
      BackendScreenshotOptions(
        overlayRefs: overlayRefs,
        fullscreen: fullscreen,
        maxSize: maxSize,
        stabilize: stabilize,
      ),
    );
    if (maxSize != null) {
      final path = result?.path ?? outPath;
      if (await File(path).exists()) {
        await png.resizePngFileToMaxSize(path, maxSize);
      }
    }
    return result;
  }

  // =========================================================================
  // Interaction
  // =========================================================================

  /// Resolve an [InteractionTarget] to an absolute screen [Point].
  ///
  /// [PointTarget]s are returned as-is. [RefTarget] and [SelectorTarget]
  /// trigger a snapshot (unless one is supplied via [snapshotOverride]) and
  /// look up the matching node. The matched node is then passed through the
  /// semantic touch target resolution policy, which:
  /// 1. Prefers same-rect descendants (drills down to specific elements)
  /// 2. Checks if the node itself is a semantic touch target
  /// 3. Climbs to hittable ancestors if needed
  /// 4. Rejects overly broad ancestors (e.g. screen-filling containers)
  /// Finally returns `centerOfRect(node.rect)`.
  /// Throws [AppError] with `AMBIGUOUS_MATCH` or `COMMAND_FAILED` when
  /// resolution fails.
  Future<Point> resolveTarget(
    InteractionTarget target, {
    BackendSnapshotResult? snapshotOverride,
  }) async {
    if (target is PointTarget) return target.point;
    final snap = snapshotOverride ?? await snapshot();
    var node = await _resolveNode(target, snap);

    // Apply the semantic touch target resolution policy.
    final nodes = _nodesOf(snap);
    if (nodes.isNotEmpty) {
      node = resolveActionableTouchNode(nodes, node);
    }

    final rect = node.rect;
    if (rect == null) {
      throw AppError(
        AppErrorCodes.commandFailed,
        'Resolved target has no rect; cannot derive a tap point.',
        details: {'target': target.toString()},
      );
    }
    return centerOfRect(rect);
  }

  Future<void> tap(num x, num y, {BackendTapOptions? options}) async {
    await backend.tap(
      await _ctx(),
      Point(x: x.toDouble(), y: y.toDouble()),
      options,
    );
  }

  /// Tap resolved from an [InteractionTarget] (point, `@ref`, or selector).
  ///
  /// For iOS with a simple single-term selector (id/label/text/value), the
  /// runner resolves and taps the element in one round-trip — no snapshot
  /// needed. Falls back to snapshot-based resolution on failure.
  Future<void> tapTarget(
    InteractionTarget target, {
    BackendTapOptions? options,
  }) async {
    if (await _tryDirectIosSelectorTap(target)) return;
    final point = await resolveTarget(target);
    await backend.tap(await _ctx(), point, options);
  }

  Future<void> fill(num x, num y, String text, {int? delayMs}) async {
    await backend.fill(
      await _ctx(),
      Point(x: x.toDouble(), y: y.toDouble()),
      text,
      delayMs == null ? null : BackendFillOptions(delayMs: delayMs),
    );
  }

  /// Fill resolved from an [InteractionTarget].
  ///
  /// For iOS with a simple single-term selector (id/label/text/value), the
  /// runner resolves, focuses, and fills the element in one round-trip.
  /// Falls back to snapshot-based resolution on failure.
  Future<void> fillTarget(
    InteractionTarget target,
    String text, {
    int? delayMs,
  }) async {
    if (await _tryDirectIosSelectorFill(target, text)) return;
    final point = await resolveTarget(target);
    await backend.fill(
      await _ctx(),
      point,
      text,
      delayMs == null ? null : BackendFillOptions(delayMs: delayMs),
    );
  }

  Future<void> typeText(String text, {int? delayMs}) async {
    await backend.typeText(
      await _ctx(),
      text,
      delayMs == null ? null : {'delayMs': delayMs},
    );
  }

  Future<void> focus(num x, num y) async {
    await backend.focus(await _ctx(), Point(x: x.toDouble(), y: y.toDouble()));
  }

  /// Focus resolved from an [InteractionTarget].
  Future<void> focusTarget(InteractionTarget target) async {
    final point = await resolveTarget(target);
    await backend.focus(await _ctx(), point);
  }

  Future<void> longPress(num x, num y, {int? durationMs}) async {
    await backend.longPress(
      await _ctx(),
      Point(x: x.toDouble(), y: y.toDouble()),
      durationMs == null
          ? null
          : BackendLongPressOptions(durationMs: durationMs),
    );
  }

  /// Long-press resolved from an [InteractionTarget].
  Future<void> longPressTarget(
    InteractionTarget target, {
    int? durationMs,
  }) async {
    final point = await resolveTarget(target);
    await backend.longPress(
      await _ctx(),
      point,
      durationMs == null
          ? null
          : BackendLongPressOptions(durationMs: durationMs),
    );
  }

  Future<void> swipe(num x1, num y1, num x2, num y2, {int? durationMs}) async {
    await backend.swipe(
      await _ctx(),
      Point(x: x1.toDouble(), y: y1.toDouble()),
      Point(x: x2.toDouble(), y: y2.toDouble()),
      durationMs == null ? null : BackendSwipeOptions(durationMs: durationMs),
    );
  }

  /// Pinch to zoom. `scale < 1` zooms out, `scale > 1` zooms in.
  Future<void> pinch({required double scale, Point? center}) async {
    await backend.pinch(
      await _ctx(),
      BackendPinchOptions(scale: scale, center: center),
    );
  }

  /// Pan (finger drag) from (x1, y1) by (dx, dy). The endpoint is
  /// computed as (x1 + dx, y1 + dy). [durationMs] controls gesture speed.
  Future<void> pan(
    num x,
    num y,
    num dx,
    num dy, {
    int? durationMs,
  }) async {
    await backend.pan(
      await _ctx(),
      BackendPanOptions(
        startX: x.toDouble(),
        startY: y.toDouble(),
        endX: (x + dx).toDouble(),
        endY: (y + dy).toDouble(),
        durationMs: durationMs,
      ),
    );
  }

  /// Fling from (startX, startY) to (endX, endY) quickly. Lower [durationMs]
  /// produces a faster, more inertial-feeling gesture.
  Future<void> fling(
    num startX,
    num startY,
    num endX,
    num endY, {
    int? durationMs,
  }) async {
    await backend.fling(
      await _ctx(),
      BackendFlingOptions(
        startX: startX.toDouble(),
        startY: startY.toDouble(),
        endX: endX.toDouble(),
        endY: endY.toDouble(),
        durationMs: durationMs,
      ),
    );
  }

  /// Two-finger rotate gesture by [degrees] (positive = clockwise).
  /// [centerX]/[centerY] pin the center point; defaults to screen center.
  Future<void> rotateGesture(
    double degrees, {
    double? centerX,
    double? centerY,
    double? velocity,
    int? durationMs,
  }) async {
    await backend.rotateGesture(
      await _ctx(),
      BackendRotateGestureOptions(
        degrees: degrees,
        centerX: centerX,
        centerY: centerY,
        velocity: velocity,
        durationMs: durationMs,
      ),
    );
  }

  /// Combined pan + scale + rotate transform gesture.
  Future<void> transformGesture({
    required num x,
    required num y,
    required num dx,
    required num dy,
    required double scale,
    required double degrees,
    int? durationMs,
  }) async {
    await backend.transformGesture(
      await _ctx(),
      BackendTransformGestureOptions(
        x: x.toDouble(),
        y: y.toDouble(),
        dx: dx.toDouble(),
        dy: dy.toDouble(),
        scale: scale,
        degrees: degrees,
        durationMs: durationMs,
      ),
    );
  }

  /// Adjust a slider. Either set to a [normalizedPosition] (0.0–1.0),
  /// or [action] `'increment'`/`'decrement'` by [steps].
  ///
  /// [interactionTarget] resolves `@ref`, selectors, or `x y` to a
  /// screen point — same resolution as [tapTarget].
  Future<void> adjustSlider({
    double? normalizedPosition,
    String action = 'increment',
    int steps = 1,
    InteractionTarget? interactionTarget,
  }) async {
    Point? resolved;
    Rect? elementRect;
    if (interactionTarget != null) {
      if (interactionTarget is PointTarget) {
        resolved = interactionTarget.point;
      } else {
        final snap = await snapshot();
        final node = await _resolveNode(interactionTarget, snap);
        final r = node.rect;
        if (r != null) {
          resolved = Point(x: r.x + r.width / 2, y: r.y + r.height / 2);
          elementRect = r;
        }
      }
    }
    await backend.adjustSlider(
      await _ctx(),
      BackendAdjustSliderOptions(
        normalizedPosition: normalizedPosition,
        action: action,
        steps: steps,
        target: resolved,
        elementRect: elementRect,
      ),
    );
  }

  /// Scroll in a [direction] on the viewport.
  ///
  /// Standard directions: `'up'`, `'down'`, `'left'`, `'right'`.
  /// Edge shortcuts: `'top'` scrolls up until hidden content above is gone;
  /// `'bottom'` scrolls down until hidden content below is gone.
  Future<Object?> scroll(
    String direction, {
    int? amount,
    int? pixels,
    int? durationMs,
    Point? at,
  }) async {
    final scrollTarget = _resolveScrollTarget(direction);
    final normalizedDurationMs = normalizeScrollDurationMs(durationMs);
    final backendTarget = at == null
        ? const BackendScrollTargetViewport()
        : BackendScrollTargetPoint(at);

    if (scrollTarget.edge != null) {
      final edge = scrollTarget.edge!;
      final ctx = await _ctx();
      final edgeResult = await runScrollEdgePasses<BackendActionResult>(
        edge: edge,
        captureState: (scope) => _captureScrollEdgeState(ctx, edge, scope),
        scroll: () => backend.scroll(
          ctx,
          backendTarget,
          BackendScrollOptions(
            direction: scrollTarget.direction,
            amount: amount,
            pixels: pixels,
            durationMs: normalizedDurationMs,
          ),
        ),
      );
      return edgeResult.result;
    }

    return backend.scroll(
      await _ctx(),
      backendTarget,
      BackendScrollOptions(
        direction: scrollTarget.direction,
        amount: amount,
        pixels: pixels,
        durationMs: normalizedDurationMs,
      ),
    );
  }

  Future<ScrollEdgeState> _captureScrollEdgeState(
    BackendCommandContext ctx,
    String edge,
    String? scope,
  ) {
    return captureScrollEdgeState(
      edge: edge,
      scope: scope,
      captureNodes: (snapshotScope) async {
        final result = await backend.captureSnapshot(
          ctx,
          BackendSnapshotOptions(compact: true, scope: snapshotScope),
        );
        final raw = result.nodes;
        if (raw == null) return [];
        return raw.whereType<SnapshotNode>().toList();
      },
    );
  }

  // =========================================================================
  // Navigation
  // =========================================================================

  Future<void> pressBack() async {
    await backend.pressBack(await _ctx(), null);
  }

  /// Press a named key (e.g. `'Return'`, `'Escape'`, `'Volume_Up'`).
  Future<void> pressKey(String key, {Map<String, Object?>? options}) async {
    await backend.pressKey(await _ctx(), key, options);
  }

  Future<void> pressHome() async {
    await backend.pressHome(await _ctx());
  }

  Future<void> openAppSwitcher() async {
    await backend.openAppSwitcher(await _ctx());
  }

  Future<void> rotate(BackendDeviceOrientation orientation) async {
    await backend.rotate(await _ctx(), orientation);
  }

  // =========================================================================
  // Diagnostics
  // =========================================================================

  /// Sample CPU and memory usage for the session's open app.
  /// `metrics` narrows the set (e.g. `['cpu']` or `['memory']`); null
  /// samples both. iOS simulator uses `simctl spawn ps`; Android uses
  /// `adb shell dumpsys cpuinfo|meminfo`.
  Future<BackendMeasurePerfResult> measurePerf({
    List<String>? metrics,
    int? sampleMs,
  }) async {
    return backend.measurePerf(
      await _ctx(),
      BackendMeasurePerfOptions(metrics: metrics, sampleMs: sampleMs),
    );
  }

  /// Begin streaming device logs to [outPath] as a detached background
  /// process. The PID is persisted under `<stateDir>/log-streams/` so a
  /// subsequent [stopLogStream] call (from any shell) can find it.
  /// iOS filters to the session's open app via os_log predicate;
  /// Android narrows with `logcat --pid <pidof(pkg)>` when an app is
  /// open, otherwise returns the full stream.
  Future<BackendLogStreamResult> startLogStream(
    String outPath, {
    String? appBundleId,
  }) async {
    return backend.startLogStream(
      await _ctx(),
      BackendLogStreamOptions(outPath: outPath, appBundleId: appBundleId),
    );
  }

  /// Stop the currently-active log stream for this session's device.
  Future<BackendLogStreamResult> stopLogStream() async {
    return backend.stopLogStream(await _ctx());
  }

  /// Dump recent device logs filtered to the session's current app.
  /// [since] can be `30s` / `5m` / `1h` for a relative window, or an
  /// absolute timestamp (`@<epoch>` or `YYYY-MM-DD HH:MM:SS`). iOS
  /// requires an open app; Android matches the backend's default.
  Future<BackendReadLogsResult> readLogs({String? since, int? limit}) async {
    return backend.readLogs(
      await _ctx(),
      BackendReadLogsOptions(since: since, limit: limit),
    );
  }

  // =========================================================================
  // Recording
  // =========================================================================

  /// Start recording video of the current app. The video file is written
  /// to [outPath] when [stopRecording] is called. On iOS the recording
  /// captures frames from the currently-open app (set via [openApp]); on
  /// Android the full screen is captured.
  Future<BackendRecordingResult> startRecording(
    String outPath, {
    int? fps,
    int? quality,
    bool? showTouches,
  }) async {
    return backend.startRecording(
      await _ctx(),
      BackendRecordingOptions(
        outPath: outPath,
        fps: fps,
        quality: quality,
        showTouches: showTouches,
      ),
    );
  }

  /// Stop the in-progress recording and finalize the file at [outPath].
  /// [outPath] must match the path passed to [startRecording].
  Future<BackendRecordingResult> stopRecording(String outPath) async {
    return backend.stopRecording(
      await _ctx(),
      BackendRecordingOptions(outPath: outPath),
    );
  }

  // =========================================================================
  // Clipboard & Keyboard
  // =========================================================================

  Future<String> getClipboard() async => backend.getClipboard(await _ctx());

  Future<void> setClipboard(String text) async {
    await backend.setClipboard(await _ctx(), text);
  }

  /// Control the keyboard. [action] is one of `'status'`, `'get'`,
  /// `'dismiss'`, `'hide'`.
  Future<Object?> setKeyboard(String action) async {
    return backend.setKeyboard(
      await _ctx(),
      BackendKeyboardOptions(action: action),
    );
  }

  // =========================================================================
  // Text Extraction & Alerts
  // =========================================================================

  /// Read accessible text from a snapshot node.
  Future<BackendReadTextResult> readText(Object node) async {
    return backend.readText(await _ctx(), node);
  }

  /// Search visible UI for [text] (exact match).
  Future<BackendFindTextResult> findText(String text) async {
    return backend.findText(await _ctx(), text);
  }

  /// Handle a system alert: `'get'`, `'accept'`, `'dismiss'`, `'wait'`.
  Future<BackendAlertResult> handleAlert(
    BackendAlertAction action, {
    Map<String, Object?>? options,
  }) async {
    return backend.handleAlert(await _ctx(), action, options);
  }

  /// Push a file (or JSON payload) to [target] on the device.
  Future<void> pushFile(BackendPushInput input, String target) async {
    await backend.pushFile(await _ctx(), input, target);
  }

  /// Open platform settings (optionally scoped to [target]).
  Future<void> openSettings([String? target]) async {
    await backend.openSettings(await _ctx(), target);
  }

  /// Set a platform setting programmatically.
  ///
  /// [setting] is the setting name (e.g. `location`, `wifi`).
  /// [state] is the desired state (e.g. `on`, `off`, `set`).
  /// [options] passes extra parameters (e.g. `latitude`, `longitude`).
  ///
  /// Returns a result map for settings that produce output (e.g. the resolved
  /// coordinates for `location set`), or null for void settings.
  Future<Map<String, Object?>?> setSetting(
    String setting,
    String state, {
    double? latitude,
    double? longitude,
    String? permissionTarget,
    String? permissionMode,
  }) async {
    return backend.setSetting(
      await _ctx(),
      setting,
      state,
      <String, Object?>{
        'latitude': ?latitude,
        'longitude': ?longitude,
        'permissionTarget': ?permissionTarget,
        'permissionMode': ?permissionMode,
      },
    );
  }

  // =========================================================================
  // App Management
  // =========================================================================

  /// Open an app by id, package, bundle, URL, or intent alias. Updates
  /// the session with the resolved app id.
  Future<void> openApp(String target, {BackendOpenOptions? options}) async {
    await backend.openApp(
      await _ctx(),
      BackendOpenTarget(app: target),
      options,
    );
    await _updateSession(appId: target);
  }

  Future<void> closeApp([String? app]) async {
    final resolved = app ?? (await sessions.get(sessionName))?.appId;
    await backend.closeApp(await _ctx(), resolved);
    if (resolved != null &&
        resolved == (await sessions.get(sessionName))?.appId) {
      await _updateSession(clear: const {'appId'});
    }
  }

  Future<BackendAppState> getAppState([String? app]) async {
    final resolved = app ?? (await sessions.get(sessionName))?.appId ?? '';
    return backend.getAppState(await _ctx(), resolved);
  }

  Future<List<BackendAppInfo>> listApps({BackendAppListFilter? filter}) async {
    return backend.listApps(await _ctx(), filter);
  }

  Future<Object?> triggerAppEvent(
    String name, {
    Map<String, Object?>? payload,
  }) async {
    return backend.triggerAppEvent(
      await _ctx(),
      BackendAppEvent(name: name, payload: payload),
    );
  }

  // =========================================================================
  // Device Management
  // =========================================================================

  /// List all visible devices. Bypasses session state — callable before
  /// [open].
  static Future<List<BackendDeviceInfo>> listDevices(
    Backend backend, {
    PlatformSelector? platform,
  }) => backend.listDevices(
    const BackendCommandContext(),
    platform == null
        ? null
        : BackendDeviceFilter(platform: _toBackendPlatform(platform)),
  );

  Future<Object?> bootDevice({String? name}) async {
    return backend.bootDevice(
      await _ctx(),
      name == null ? null : BackendDeviceTarget(name: name),
    );
  }

  Future<BackendInstallResult> installApp({
    required String path,
    String? app,
  }) async {
    return backend.installApp(
      await _ctx(),
      BackendInstallTarget(app: app, source: BackendInstallSourcePath(path)),
    );
  }

  Future<BackendInstallResult> uninstallApp({required String app}) async {
    return backend.uninstallApp(await _ctx(), app);
  }

  Future<BackendInstallResult> reinstallApp({
    required String path,
    required String app,
    bool resetKeychain = false,
  }) async {
    if (resetKeychain) {
      await backend.resetKeychain(await _ctx());
    }
    return backend.reinstallApp(
      await _ctx(),
      BackendInstallTarget(app: app, source: BackendInstallSourcePath(path)),
    );
  }

  /// Reset the simulator keychain (iOS simulator only).
  Future<void> resetKeychain() async {
    await backend.resetKeychain(await _ctx());
  }

  // =========================================================================
  // Query: find / get / is / wait
  // =========================================================================

  /// Search the current snapshot for nodes matching [text].
  ///
  /// Three modes are supported, tried in this order:
  ///
  /// * **Selector DSL** ([selectorChain] is provided): exact match via
  ///   [matchesSelector]. E.g. `text="Yes, Tap to select"` or `visible`.
  /// * **Locator** ([locator] ≠ `'any'`): case-insensitive substring match
  ///   restricted to the named field (`text`/`label`/`value`/`id`/`role`).
  /// * **Any** (default): case-insensitive substring match across `label`,
  ///   `value`, and `identifier`.
  ///
  /// Returns a list of `{ref, label, value, identifier, type, rect}` maps.
  /// Takes a fresh snapshot unless [snapshotOverride] is supplied.
  Future<List<Map<String, Object?>>> find(
    String text, {
    String locator = 'any',
    SelectorChain? selectorChain,
    BackendSnapshotResult? snapshotOverride,
  }) async {
    if (selectorChain == null && text.trim().isEmpty) {
      throw AppError(
        AppErrorCodes.invalidArgs,
        'find: query must be non-empty.',
      );
    }
    final snap = snapshotOverride ?? await snapshot();
    final nodes = _nodesOf(snap);
    final hits = <Map<String, Object?>>[];
    final platform = backend.platform.name;

    for (final n in nodes) {
      final bool hit;
      if (selectorChain != null) {
        hit = selectorChain.selectors.any(
          (sel) => matchesSelector(n, sel, platform),
        );
      } else {
        final needle = _normalizeFindText(text);
        final List<String?> haystacks;
        switch (locator) {
          case 'label':
            haystacks = [n.label];
          case 'value':
            haystacks = [n.value];
          case 'id':
            haystacks = [n.identifier];
          case 'role':
            haystacks = [_normalizeFindRole(n.type)];
          default:
            haystacks = [n.label, n.value, n.identifier];
        }
        hit = haystacks
            .whereType<String>()
            .map(_normalizeFindText)
            .any((s) => s.contains(needle));
      }
      if (!hit) continue;
      hits.add(<String, Object?>{
        'ref': n.ref,
        'label': n.label,
        'value': n.value,
        'identifier': n.identifier,
        'type': n.type,
        if (n.rect != null)
          'rect': {
            'x': n.rect!.x,
            'y': n.rect!.y,
            'width': n.rect!.width,
            'height': n.rect!.height,
          },
      });
    }
    return hits;
  }

  static String _normalizeFindText(String s) =>
      s.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');

  static String _normalizeFindRole(String? type) {
    if (type == null || type.isEmpty) return '';
    final lower = type.toLowerCase();
    final lastDot = lower.lastIndexOf('.');
    return lastDot >= 0 ? lower.substring(lastDot + 1) : lower;
  }

  /// Read a named attribute off the node addressed by [target]. [attr] is
  /// one of `text`, `label`, `value`, `identifier`, `type`, `role`, `rect`,
  /// `ref`. Unknown [attr] values throw `INVALID_ARGS`.
  Future<Object?> getAttr(String attr, InteractionTarget target) async {
    final snap = await snapshot();
    final node = await _resolveNode(target, snap);
    switch (attr) {
      case 'ref':
        return node.ref;
      case 'label':
        return node.label;
      case 'value':
        return node.value;
      case 'identifier':
        return node.identifier;
      case 'type':
        return node.type;
      case 'role':
        return node.role;
      case 'text':
        // Prefer label over value; many Android widgets carry the human
        // text on `label`.
        return node.label?.trim().isNotEmpty == true
            ? node.label
            : (node.value?.trim().isNotEmpty == true
                  ? node.value
                  : node.identifier);
      case 'rect':
        final r = node.rect;
        if (r == null) return null;
        return {'x': r.x, 'y': r.y, 'width': r.width, 'height': r.height};
    }
    throw AppError(
      AppErrorCodes.invalidArgs,
      'Unknown attribute "$attr". Expected one of: '
      'ref, label, value, identifier, type, role, text, rect.',
      details: {'attr': attr},
    );
  }

  /// Evaluate a predicate (e.g. `visible`, `hidden`, `editable`,
  /// `selected`, `exists`, `text=Submit`) against [target]. [predicate] is
  /// the bare name (e.g. `'visible'`) OR a `text=...` expression; pass the
  /// expected-text portion separately via [expectedText] for a stable
  /// programmatic API.
  ///
  /// Returns an [IsPredicateResult] whose `pass` field tells you whether
  /// the predicate held.
  Future<IsPredicateResult> isPredicate(
    String predicate,
    InteractionTarget target, {
    String? expectedText,
  }) async {
    if (!isSupportedPredicate(predicate)) {
      throw AppError(
        AppErrorCodes.invalidArgs,
        'Unsupported is-predicate: $predicate',
        details: {
          'predicate': predicate,
          'supported': const [
            'visible',
            'hidden',
            'exists',
            'editable',
            'selected',
            'text',
          ],
        },
      );
    }
    final snap = await snapshot();
    final nodes = _nodesOf(snap);
    SnapshotNode? node;
    try {
      node = await _resolveNode(target, snap);
    } on AppError catch (e) {
      // `exists` legitimately wants to observe "no match" → pass=false.
      // `hidden` for a ref/selector that doesn't exist on screen is also
      // a passing assertion.
      if (e.code == AppErrorCodes.commandFailed &&
          (predicate == 'exists' || predicate == 'hidden')) {
        return IsPredicateResult(
          pass: predicate == 'hidden',
          actualText: '',
          details: 'No node matched the target.',
        );
      }
      rethrow;
    }
    return evaluateIsPredicate(
      predicate: predicate,
      node: node,
      nodes: nodes,
      expectedText: expectedText,
      platform: backend.platform.name,
    );
  }

  /// Poll until [predicate] on [target] passes, with [timeout] and
  /// [pollInterval] knobs. Returns the final [IsPredicateResult]. Times
  /// out with `COMMAND_FAILED` when the condition doesn't hold before the
  /// deadline.
  Future<IsPredicateResult> wait(
    String predicate,
    InteractionTarget target, {
    Duration timeout = const Duration(seconds: 10),
    Duration pollInterval = const Duration(milliseconds: 400),
    String? expectedText,
  }) async {
    final deadline = clock.now() + timeout.inMilliseconds;
    IsPredicateResult last = const IsPredicateResult(
      pass: false,
      actualText: '',
      details: '',
    );
    while (true) {
      try {
        last = await isPredicate(predicate, target, expectedText: expectedText);
      } on AppError catch (e) {
        // Treat transient resolution failures as "not yet true" — polling.
        if (e.code != AppErrorCodes.commandFailed) rethrow;
        last = IsPredicateResult(
          pass: false,
          actualText: '',
          details: e.message,
        );
      }
      if (last.pass) return last;
      if (clock.now() >= deadline) {
        final baseMessage =
            'wait "$predicate" timed out after ${timeout.inMilliseconds}ms.';
        final baseDetails = <String, Object?>{
          'predicate': predicate,
          'timeoutMs': timeout.inMilliseconds,
          'lastActualText': last.actualText,
          'lastDetails': last.details,
        };
        // Attempt a best-effort snapshot of the current surface to surface
        // diagnostic info about what's visible (e.g. permission dialogs,
        // wrong-app foreground) that may explain why the element was not found.
        final surface = await inspectCurrentSurface(backend, await _ctx()).catchError((_) => null);
        if (surface != null) {
          throw AppError(
            AppErrorCodes.commandFailed,
            '$baseMessage Current surface: ${surface.summary}.',
            details: {
              ...baseDetails,
              'currentSurface': surface.details.toJson(),
            },
          );
        }
        throw AppError(
          AppErrorCodes.commandFailed,
          baseMessage,
          details: baseDetails,
        );
      }
      await clock.sleep(pollInterval);
    }
  }

  /// Backend snapshot nodes are typed `List<Object?>?` at the contract
  /// boundary (the Backend type is intentionally loose). The real payload
  /// is always `List<SnapshotNode>` once `attachRefs` has run on the
  /// concrete backend. Narrow the cast here so every caller downstream
  /// sees a strong type.
  List<SnapshotNode> _nodesOf(BackendSnapshotResult snap) {
    final raw = snap.nodes;
    if (raw == null) return const [];
    if (raw is List<SnapshotNode>) return raw;
    return raw.whereType<SnapshotNode>().toList();
  }

  // -------------------------------------------------------------------------
  // Direct iOS selector optimization (ports upstream 094c2907)
  // -------------------------------------------------------------------------

  static const _directSelectorKeys = {'id', 'label', 'text', 'value'};

  /// Extract a simple single-term selector suitable for direct runner
  /// dispatch. Returns null if the target isn't a simple selector or
  /// the backend isn't iOS.
  ({String key, String value})? _readDirectIosSelector(
    InteractionTarget target,
  ) {
    if (backend is! IosBackend) return null;
    if (target is! SelectorTarget) return null;
    final chain = target.chain;
    if (chain.selectors.isEmpty) return null;
    // Only optimize single-alternative, single-term selectors.
    // Multi-term or multi-alternative selectors need snapshot resolution.
    final selector = chain.selectors.first;
    if (selector.terms.length != 1) return null;
    final term = selector.terms.first;
    if (term.value is! String) return null;
    final key = term.key;
    if (!_directSelectorKeys.contains(key)) return null;
    return (key: key, value: term.value as String);
  }

  /// Try a direct runner selector tap. Returns true if it succeeded,
  /// false if the target isn't suitable or the runner rejected it
  /// (in which case the caller should fall back to snapshot resolution).
  Future<bool> _tryDirectIosSelectorTap(InteractionTarget target) async {
    final direct = _readDirectIosSelector(target);
    if (direct == null) return false;
    try {
      await (backend as IosBackend).tapElementSelector(
        ctx: await _ctx(),
        selectorKey: direct.key,
        selectorValue: direct.value,
      );
      return true;
    } on AppError catch (e) {
      final msg = e.message.toLowerCase();
      if (msg.contains('timed out') ||
          msg.contains('timeout') ||
          msg.contains('fetch failed') ||
          msg.contains('not accept connection') ||
          msg.contains('invalid runner response')) {
        return false;
      }
      rethrow;
    }
  }

  /// Try a direct runner selector fill. Same semantics as
  /// [_tryDirectIosSelectorTap].
  Future<bool> _tryDirectIosSelectorFill(
    InteractionTarget target,
    String text,
  ) async {
    final direct = _readDirectIosSelector(target);
    if (direct == null) return false;
    try {
      await (backend as IosBackend).fillElementSelector(
        ctx: await _ctx(),
        selectorKey: direct.key,
        selectorValue: direct.value,
        text: text,
      );
      return true;
    } on AppError catch (e) {
      final msg = e.message.toLowerCase();
      if (msg.contains('timed out') ||
          msg.contains('timeout') ||
          msg.contains('fetch failed') ||
          msg.contains('not accept connection') ||
          msg.contains('invalid runner response')) {
        return false;
      }
      rethrow;
    }
  }

  /// Internal: resolve [target] all the way to a [SnapshotNode] (rather
  /// than a [Point]). Shared by [getAttr], [isPredicate], and [wait].
  Future<SnapshotNode> _resolveNode(
    InteractionTarget target,
    BackendSnapshotResult snap,
  ) async {
    final nodes = _nodesOf(snap);
    if (nodes.isEmpty) {
      throw AppError(
        AppErrorCodes.commandFailed,
        'Cannot resolve $target: the snapshot is empty.',
      );
    }
    if (target is PointTarget) {
      throw AppError(
        AppErrorCodes.invalidArgs,
        'Point targets are not supported for find/get/is/wait — '
        'pass a @ref or selector.',
      );
    }
    if (target is RefTarget) {
      final node = findNodeByRef(nodes, target.ref);
      if (node == null) {
        throw AppError(
          AppErrorCodes.commandFailed,
          'Ref @${target.ref} not found in the current snapshot.',
          details: {'ref': target.ref},
        );
      }
      return node;
    }
    if (target is SelectorTarget) {
      final resolution = resolveSelectorChain(
        nodes,
        target.chain,
        platform: backend.platform.name,
        disambiguateAmbiguous: true,
      );
      if (resolution == null) {
        throw AppError(
          AppErrorCodes.commandFailed,
          'Selector did not match any node: ${target.source}',
          details: {'selector': target.source},
        );
      }
      return resolution.node;
    }
    throw StateError('unreachable');
  }

  // =========================================================================
  // Lifecycle
  // =========================================================================

  /// Close the session. Clears the stored record; does not kill the
  /// currently-running app unless [closeCurrentApp] is true.
  Future<void> close({bool closeCurrentApp = false}) async {
    if (closeCurrentApp) {
      final appId = (await sessions.get(sessionName))?.appId;
      if (appId != null && appId.isNotEmpty) {
        try {
          await backend.closeApp(await _ctx(), appId);
        } on AppError {
          // Best-effort; the session teardown continues regardless.
        }
      }
    }
    await sessions.delete(sessionName);
  }
}

/// Map a scroll input direction string to a concrete direction and optional edge.
///
/// `'top'` → direction `'up'` + edge `'top'`;
/// `'bottom'` → direction `'down'` + edge `'bottom'`;
/// all others pass through unchanged with no edge.
({String direction, String? edge}) _resolveScrollTarget(String input) {
  if (input == 'bottom') return (direction: 'down', edge: 'bottom');
  if (input == 'top') return (direction: 'up', edge: 'top');
  return (direction: input, edge: null);
}

/// Parse a [SnapshotBackend] from a string value, returning null if the
/// value is not recognised (forward-compat: new backends won't crash).
SnapshotBackend? _tryParseSnapshotBackend(String value) {
  try {
    return SnapshotBackend.fromString(value);
  } catch (_) {
    return null;
  }
}

/// Bridge PlatformSelector (Dart port enum used by CLI / replay) to
/// [AgentDeviceBackendPlatform] (backend-layer enum, no `apple` variant).
/// The selector's `apple` value is mapped to iOS since Android's
/// [BackendDeviceFilter] only accepts concrete platforms.
AgentDeviceBackendPlatform _toBackendPlatform(PlatformSelector p) =>
    switch (p) {
      PlatformSelector.ios => AgentDeviceBackendPlatform.ios,
      PlatformSelector.android => AgentDeviceBackendPlatform.android,
      PlatformSelector.macos => AgentDeviceBackendPlatform.macos,
      PlatformSelector.linux => AgentDeviceBackendPlatform.linux,
      PlatformSelector.apple => AgentDeviceBackendPlatform.ios,
    };
