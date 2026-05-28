// Port of gesture subcommand dispatch in agent-device/src/cli/commands/generic.ts
// and agent-device/src/core/dispatch-interactions.ts.
//
// Provides:
//   gesture pinch  <scale> [x] [y]
//   gesture pan    <x> <y> <dx> <dy> [durationMs]
//   gesture fling  <direction> <x> <y> [distance] [durationMs]
//   gesture rotate <degrees> [x] [y] [velocity]
//   gesture transform <x> <y> <dx> <dy> <scale> <degrees> [durationMs]
library;

import 'package:agent_device/src/snapshot/snapshot.dart' show Point;
import 'package:agent_device/src/utils/errors.dart';

import '../base_command.dart';

/// Top-level `gesture` command. Dispatches to subcommands.
class GestureCommand extends AgentDeviceCommand {
  GestureCommand() {
    addSubcommand(GesturePinchCommand());
    addSubcommand(GesturePanCommand());
    addSubcommand(GestureFlingCommand());
    addSubcommand(GestureRotateCommand());
    addSubcommand(GestureTransformCommand());
  }

  @override
  String get name => 'gesture';

  @override
  String get description =>
      'Multi-finger gesture commands: pinch | pan | fling | rotate | transform.';

  @override
  Future<int> run() async {
    // With args subcommands active the runner won't reach here for valid input.
    throw AppError(
      AppErrorCodes.invalidArgs,
      'gesture requires a subcommand: pinch | pan | fling | rotate | transform.',
    );
  }
}

// ---------------------------------------------------------------------------
// gesture pinch
// ---------------------------------------------------------------------------

class GesturePinchCommand extends AgentDeviceCommand {
  @override
  String get name => 'pinch';

  @override
  String get description => 'Pinch to zoom: gesture pinch <scale> [x] [y]';

  @override
  Future<int> run() async {
    final args = positionals;
    if (args.isEmpty) {
      throw AppError(
        AppErrorCodes.invalidArgs,
        'gesture pinch requires <scale> [x] [y].',
      );
    }
    final scale = double.tryParse(args[0]);
    if (scale == null || scale <= 0) {
      throw AppError(
        AppErrorCodes.invalidArgs,
        'gesture pinch requires scale > 0.',
      );
    }
    final x = args.length > 1 ? double.tryParse(args[1]) : null;
    final y = args.length > 2 ? double.tryParse(args[2]) : null;
    Point? center;
    if (x != null && y != null) {
      center = Point(x: x, y: y);
    }
    final device = await openAgentDevice();
    await device.pinch(scale: scale, center: center);
    emitResult({
      'pinched': scale,
      if (center != null) 'center': [center.x, center.y],
    }, humanFormat: (_) => 'pinched scale=$scale');
    return 0;
  }
}

// ---------------------------------------------------------------------------
// gesture pan
// ---------------------------------------------------------------------------

class GesturePanCommand extends AgentDeviceCommand {
  @override
  String get name => 'pan';

  @override
  String get description =>
      'Pan (drag) from (x, y) by (dx, dy): gesture pan <x> <y> <dx> <dy> [durationMs]';

  @override
  Future<int> run() async {
    final args = positionals;
    if (args.length < 4) {
      throw AppError(
        AppErrorCodes.invalidArgs,
        'gesture pan requires <x> <y> <dx> <dy>.',
      );
    }
    final x = double.tryParse(args[0]);
    final y = double.tryParse(args[1]);
    final dx = double.tryParse(args[2]);
    final dy = double.tryParse(args[3]);
    if (x == null || y == null || dx == null || dy == null) {
      throw AppError(
        AppErrorCodes.invalidArgs,
        'gesture pan requires finite x y dx dy.',
      );
    }
    final durationMs = args.length > 4 ? int.tryParse(args[4]) : null;
    if (durationMs != null && (durationMs < 16 || durationMs > 10000)) {
      throw AppError(
        AppErrorCodes.invalidArgs,
        'gesture pan durationMs must be between 16 and 10000.',
      );
    }
    final device = await openAgentDevice();
    await device.pan(x, y, dx, dy, durationMs: durationMs ?? 500);
    emitResult({
      'x': x,
      'y': y,
      'dx': dx,
      'dy': dy,
      'x2': x + dx,
      'y2': y + dy,
      'durationMs': durationMs ?? 500,
    }, humanFormat: (_) => 'panned ($x, $y) by ($dx, $dy)');
    return 0;
  }
}

// ---------------------------------------------------------------------------
// gesture fling
// ---------------------------------------------------------------------------

class GestureFlingCommand extends AgentDeviceCommand {
  @override
  String get name => 'fling';

  @override
  String get description =>
      'Fling in a direction: gesture fling <up|down|left|right> <x> <y> [distance] [durationMs]';

  @override
  Future<int> run() async {
    final args = positionals;
    if (args.length < 3) {
      throw AppError(
        AppErrorCodes.invalidArgs,
        'gesture fling requires <direction> <x> <y>.',
      );
    }
    final direction = _parseDirection(args[0]);
    final x = double.tryParse(args[1]);
    final y = double.tryParse(args[2]);
    if (x == null || y == null) {
      throw AppError(
        AppErrorCodes.invalidArgs,
        'gesture fling requires finite x and y.',
      );
    }
    final distance = args.length > 3
        ? (double.tryParse(args[3]) ?? 180.0)
        : 180.0;
    if (distance <= 0) {
      throw AppError(
        AppErrorCodes.invalidArgs,
        'gesture fling distance must be positive.',
      );
    }
    final requestedDuration =
        args.length > 4 ? (int.tryParse(args[4]) ?? 50) : 50;
    final durationMs = requestedDuration.clamp(16, 1000);

    final (x2, y2) = _pointOffsetByDirection(x, y, direction, distance);
    final device = await openAgentDevice();
    await device.fling(x, y, x2, y2, durationMs: durationMs);
    emitResult({
      'direction': direction,
      'x': x,
      'y': y,
      'x2': x2,
      'y2': y2,
      'distance': distance,
      'durationMs': durationMs,
    }, humanFormat: (_) => 'flung $direction');
    return 0;
  }

  String _parseDirection(String value) {
    if (value == 'up' || value == 'down' || value == 'left' || value == 'right') {
      return value;
    }
    throw AppError(
      AppErrorCodes.invalidArgs,
      'gesture fling direction must be up, down, left, or right.',
    );
  }

  (double, double) _pointOffsetByDirection(
    double x,
    double y,
    String direction,
    double distance,
  ) => switch (direction) {
    'up' => (x, y - distance),
    'down' => (x, y + distance),
    'left' => (x - distance, y),
    _ => (x + distance, y), // 'right'
  };
}

// ---------------------------------------------------------------------------
// gesture rotate
// ---------------------------------------------------------------------------

class GestureRotateCommand extends AgentDeviceCommand {
  @override
  String get name => 'rotate';

  @override
  String get description =>
      'Two-finger rotate gesture: gesture rotate <degrees> [x] [y] [velocity]';

  @override
  Future<int> run() async {
    final args = positionals;
    if (args.isEmpty) {
      throw AppError(
        AppErrorCodes.invalidArgs,
        'gesture rotate requires <degrees>.',
      );
    }
    final degrees = double.tryParse(args[0]);
    if (degrees == null || !degrees.isFinite) {
      throw AppError(
        AppErrorCodes.invalidArgs,
        'gesture rotate requires finite degrees.',
      );
    }

    double? centerX;
    double? centerY;
    if (args.length >= 3) {
      centerX = double.tryParse(args[1]);
      centerY = double.tryParse(args[2]);
      if (centerX == null || centerY == null) {
        throw AppError(
          AppErrorCodes.invalidArgs,
          'gesture rotate center requires finite x and y.',
        );
      }
    } else if (args.length == 2) {
      throw AppError(
        AppErrorCodes.invalidArgs,
        'gesture rotate center requires both x and y.',
      );
    }

    final velocityRaw =
        args.length > 3 ? double.tryParse(args[3]) : null;
    final velocity =
        velocityRaw ??
        (degrees >= 0 ? 1.0 : -1.0);
    if (!velocity.isFinite || velocity == 0) {
      throw AppError(
        AppErrorCodes.invalidArgs,
        'gesture rotate velocity must be a non-zero number.',
      );
    }

    final device = await openAgentDevice();
    await device.rotateGesture(
      degrees,
      centerX: centerX,
      centerY: centerY,
      velocity: velocity.abs() * (degrees >= 0 ? 1 : -1),
    );
    emitResult({
      'degrees': degrees,
      if (centerX != null) 'x': centerX,
      if (centerY != null) 'y': centerY,
      'velocity': velocity,
    }, humanFormat: (_) => 'rotated gesture $degrees degrees');
    return 0;
  }
}

// ---------------------------------------------------------------------------
// gesture transform
// ---------------------------------------------------------------------------

class GestureTransformCommand extends AgentDeviceCommand {
  @override
  String get name => 'transform';

  @override
  String get description =>
      'Combined pan+scale+rotate gesture: gesture transform <x> <y> <dx> <dy> <scale> <degrees> [durationMs]';

  @override
  Future<int> run() async {
    final args = positionals;
    if (args.length < 6) {
      throw AppError(
        AppErrorCodes.invalidArgs,
        'gesture transform requires <x> <y> <dx> <dy> <scale> <degrees>.',
      );
    }
    final x = double.tryParse(args[0]);
    final y = double.tryParse(args[1]);
    final dx = double.tryParse(args[2]);
    final dy = double.tryParse(args[3]);
    final scale = double.tryParse(args[4]);
    final degrees = double.tryParse(args[5]);

    if (x == null ||
        y == null ||
        dx == null ||
        dy == null ||
        scale == null ||
        degrees == null ||
        ![x, y, dx, dy, scale, degrees].every((v) => v.isFinite)) {
      throw AppError(
        AppErrorCodes.invalidArgs,
        'gesture transform requires finite x y dx dy scale degrees.',
      );
    }
    if (scale <= 0) {
      throw AppError(
        AppErrorCodes.invalidArgs,
        'gesture transform scale must be > 0.',
      );
    }
    final durationMs = args.length > 6 ? int.tryParse(args[6]) : null;
    if (durationMs != null && (durationMs < 16 || durationMs > 10000)) {
      throw AppError(
        AppErrorCodes.invalidArgs,
        'gesture transform durationMs must be between 16 and 10000.',
      );
    }

    final device = await openAgentDevice();
    await device.transformGesture(
      x: x,
      y: y,
      dx: dx,
      dy: dy,
      scale: scale,
      degrees: degrees,
      durationMs: durationMs,
    );
    emitResult({
      'x': x,
      'y': y,
      'dx': dx,
      'dy': dy,
      'scale': scale,
      'degrees': degrees,
      if (durationMs != null) 'durationMs': durationMs,
    }, humanFormat: (_) => 'transform gesture by ($dx, $dy), scale $scale, rotate $degrees°');
    return 0;
  }
}
