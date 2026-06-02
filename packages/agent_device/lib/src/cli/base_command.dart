// Base Command type shared by all agent-device CLI subcommands.
library;

import 'package:agent_device/src/backend/backend.dart';
import 'package:agent_device/src/platforms/android/android_backend.dart';
import 'package:agent_device/src/platforms/ios/ios_backend.dart';
import 'package:agent_device/src/platforms/platform_selector.dart';
import 'package:agent_device/src/runtime/agent_device.dart';
import 'package:agent_device/src/runtime/contract.dart';
import 'package:agent_device/src/runtime/file_session_store.dart';
import 'package:agent_device/src/runtime/paths.dart';
import 'package:agent_device/src/runtime/session_store.dart';
import 'package:agent_device/src/utils/errors.dart';
import 'package:agent_device/src/utils/logger.dart';
import 'package:args/command_runner.dart';

import 'output.dart';

/// Base class that adds the common flags every CLI command accepts:
/// `--session`, `--platform`, `--serial`, `--json`, `--verbose` /
/// `--debug`. Subclasses call [openAgentDevice] to construct a fresh
/// [AgentDevice] bound to the selected device.
abstract class AgentDeviceCommand extends Command<int> {
  AgentDeviceCommand() {
    argParser
      ..addOption(
        'session',
        help: 'Session name (default: "default").',
        defaultsTo: 'default',
      )
      ..addOption(
        'platform',
        help:
            'Device platform selector (ios | android | macos | linux | apple).',
        allowed: ['ios', 'android', 'macos', 'linux', 'apple'],
      )
      ..addOption('serial', help: 'Explicit device serial / udid to target.')
      ..addOption('device', help: 'Device name to target.')
      ..addOption(
        'state-dir',
        help:
            'Override the agent-device state directory '
            '(default: \$AGENT_DEVICE_STATE_DIR or ~/.agent-device/).',
      )
      ..addFlag(
        'ephemeral-session',
        help:
            'Use an in-memory session store for this invocation (do not '
            'touch ~/.agent-device/sessions/).',
        negatable: false,
      )
      ..addFlag(
        'json',
        help: 'Emit machine-readable JSON output.',
        negatable: false,
      )
      ..addFlag(
        'verbose',
        abbr: 'v',
        help: 'Verbose output / include full error details.',
        negatable: false,
      )
      ..addFlag('debug', help: 'Alias for --verbose.', negatable: false);
  }

  /// True if `--json` was passed on this command (or any parent).
  bool get asJson => _boolFlag('json');

  /// True if `--verbose` or `--debug` was passed.
  bool get verbose => _boolFlag('verbose') || _boolFlag('debug');

  String get sessionName => argResults?['session'] as String? ?? 'default';

  /// Resolve the device selector from CLI flags.
  DeviceSelector get selectorFromFlags {
    final platform = argResults?['platform'] as String?;
    final serial = argResults?['serial'] as String?;
    final name = argResults?['device'] as String?;
    return DeviceSelector(
      platform: platform == null ? null : parsePlatformSelector(platform),
      serial: serial,
      name: name,
    );
  }

  /// Resolve the concrete [Backend] for the selected platform. Android
  /// and iOS are both fully wired (iOS goes through the Phase 8B
  /// XCUITest-runner bridge for snapshot + interaction; simulator device
  /// operations go through `simctl`, physical devices through
  /// `devicectl`). macOS / Linux are Phase 9.
  Backend resolveBackend() {
    final platform = parsePlatformSelector(
      _stringOption('platform') ?? argResults?['platform'] as String?,
    );
    // No --platform flag: Android first because it's the fuller backend.
    if (platform == null) return const AndroidBackend();
    return backendForPlatform(platform);
  }

  /// Map a [PlatformSelector] to its concrete [Backend]. Use this rather than
  /// [resolveBackend] when the platform is known from a selector (e.g.
  /// remembered in the session) instead of the `--platform` CLI flag —
  /// [resolveBackend] only inspects the flag and would otherwise fall back to
  /// Android.
  Backend backendForPlatform(PlatformSelector platform) {
    switch (platform) {
      case PlatformSelector.android:
        return const AndroidBackend();
      case PlatformSelector.ios:
      case PlatformSelector.apple: // Phase 8A: treat `apple` as iOS.
        return const IosBackend();
      case PlatformSelector.macos:
      case PlatformSelector.linux:
        throw AppError(
          AppErrorCodes.unsupportedPlatform,
          'Platform "${platformSelectorToString(platform)}" is not yet '
          'implemented in the Dart port.',
          details: const {
            'hint':
                '--platform android and --platform ios are supported. '
                'macOS / Linux are tracked in Phase 9.',
          },
        );
    }
  }

  /// The [CommandSessionStore] this CLI invocation should use. Defaults to
  /// a [FileSessionStore] rooted at `<state-dir>/sessions/` so subsequent
  /// CLI invocations share session state. `--ephemeral-session` falls back
  /// to an in-memory store for one-shot commands. Both flags are honored
  /// whether passed at the root (`agent-device --state-dir X cmd`) or on
  /// the subcommand (`agent-device cmd --state-dir X`).
  CommandSessionStore resolveSessionStore() {
    if (_boolFlag('ephemeral-session')) return createMemorySessionStore();
    final paths = resolveStatePaths(_stringOption('state-dir'));
    return FileSessionStore(paths.sessionsDir);
  }

  /// Same lookup logic as [_boolFlag] but for string-valued options.
  String? _stringOption(String name) {
    final results = argResults;
    if (results != null && results.options.contains(name)) {
      final v = results[name];
      if (v is String && v.isNotEmpty) return v;
    }
    final global = globalResults;
    if (global != null && global.options.contains(name)) {
      final v = global[name];
      if (v is String && v.isNotEmpty) return v;
    }
    return null;
  }

  /// Open an [AgentDevice] bound to the session and selector from the
  /// command-line flags. Callers are responsible for `await device.close()`
  /// only when they want the session deleted — for persistent sessions
  /// (the default), leave `close()` unpinned so subsequent CLI runs can
  /// reuse the record.
  Future<AgentDevice> openAgentDevice({CommandSessionStore? sessions}) async {
    if (verbose) initLogger(verbose: true);
    final store = sessions ?? resolveSessionStore();
    // Prefer the device remembered for this session if the user hasn't
    // narrowed down via --serial / --device. This is what lets
    // `agent-device open` in shell A and `agent-device snapshot` in shell B
    // land on the same device. Restoring the remembered platform too lets the
    // resolve take AgentDevice.open's serial+platform fast path (no
    // enumeration) on repeat commands.
    DeviceSelector selector = selectorFromFlags;
    if (selector.serial == null && selector.name == null) {
      final existing = await store.get(sessionName);
      final remembered = existing?.deviceSerial;
      if (remembered != null && remembered.isNotEmpty) {
        selector = DeviceSelector(
          platform:
              selector.platform ??
              parsePlatformSelector(existing?.devicePlatform),
          serial: remembered,
          name: null,
        );
      }
    }

    // With a platform — whether from --platform or restored from the session —
    // address that backend directly. Drive the choice off selector.platform,
    // NOT resolveBackend(), which only sees the CLI flag and would default to
    // Android for a session-remembered platform.
    if (selector.platform != null) {
      return AgentDevice.open(
        backend: backendForPlatform(selector.platform!),
        selector: selector,
        sessionName: sessionName,
        sessions: store,
      );
    }

    // No platform: auto-detect across backends so an iOS udid/name resolves
    // without --platform, and so a "not found" error lists devices from every
    // platform instead of just Android.
    final resolved = await _resolveBackendAndSelector(selector);
    return AgentDevice.open(
      backend: resolved.backend,
      selector: resolved.selector,
      sessionName: sessionName,
      sessions: store,
    );
  }

  /// Enumerate every backend, find the device matching [selector] (or, when
  /// nothing is pinned, the first booted device), and return that device's
  /// backend paired with a serial+platform selector that takes
  /// `AgentDevice.open`'s fast path.
  Future<({Backend backend, DeviceSelector selector})>
  _resolveBackendAndSelector(DeviceSelector selector) async {
    const backends = <Backend>[AndroidBackend(), IosBackend()];
    final pairs = <({Backend backend, BackendDeviceInfo device})>[];
    await Future.wait([
      for (final backend in backends)
        Future(() async {
          try {
            for (final device in await AgentDevice.listDevices(backend)) {
              pairs.add((backend: backend, device: device));
            }
          } catch (_) {
            // A missing toolchain on one platform shouldn't fail the resolve.
          }
        }),
    ]);

    final candidates = (selector.serial != null || selector.name != null)
        ? pairs.where((p) => selector.matches(p.device)).toList()
        : pairs;
    final chosen = _preferBooted(candidates.toList());

    if (chosen == null) {
      throw AppError(
        AppErrorCodes.deviceNotFound,
        'No device matches the selector',
        details: {
          if (selector.serial != null) 'serial': selector.serial,
          if (selector.name != null) 'name': selector.name,
          'available': pairs
              .map((p) => '${p.device.id} (${p.device.platform.name})')
              .toList(),
          'hint': pairs.isEmpty
              ? 'No booted devices found on any platform.'
              : 'Pass --serial / --device matching one of the available '
                    'devices, or --platform to disambiguate.',
        },
      );
    }

    return (
      backend: chosen.backend,
      selector: DeviceSelector(
        platform: _platformSelectorFor(chosen.device.platform),
        serial: chosen.device.id,
      ),
    );
  }

  static ({Backend backend, BackendDeviceInfo device})? _preferBooted(
    List<({Backend backend, BackendDeviceInfo device})> candidates,
  ) {
    if (candidates.isEmpty) return null;
    return candidates.firstWhere(
      (c) => c.device.booted == true,
      orElse: () => candidates.first,
    );
  }

  static PlatformSelector _platformSelectorFor(AgentDeviceBackendPlatform p) {
    switch (p) {
      case AgentDeviceBackendPlatform.ios:
        return PlatformSelector.ios;
      case AgentDeviceBackendPlatform.android:
        return PlatformSelector.android;
      case AgentDeviceBackendPlatform.macos:
        return PlatformSelector.macos;
      case AgentDeviceBackendPlatform.linux:
        return PlatformSelector.linux;
    }
  }

  /// Positional arguments remaining after flag parsing.
  List<String> get positionals => [
    // Strip the negative-number guard added by protectNegativePositionals so
    // commands see the real token (e.g. "-120" rather than "-120").
    for (final arg in argResults?.rest ?? const <String>[])
      arg.startsWith('\u{E000}') ? arg.substring(1) : arg,
  ];

  /// Helper for subclasses to uniformly print a command result.
  void emitResult(Object? data, {String Function(Object? data)? humanFormat}) =>
      printResult(data, asJson: asJson, humanFormat: humanFormat);

  /// Helper for subclasses to uniformly print a short "ok" message in
  /// human mode after a successful mutating command (open, close, tap,
  /// fill, etc.). JSON mode is silent because the envelope already
  /// signals success.
  void emitAck(String message) => printAck(message, asJson: asJson);

  /// Check either the top-level runner's results or this command's own
  /// results for a bool flag — so both `agent-device --json snapshot` and
  /// `agent-device snapshot --json` work.
  bool _boolFlag(String name) {
    final results = argResults;
    if (results != null && results.options.contains(name)) {
      final v = results[name];
      if (v is bool && v) return true;
    }
    final global = globalResults;
    if (global != null && global.options.contains(name)) {
      final v = global[name];
      if (v is bool && v) return true;
    }
    return false;
  }
}
