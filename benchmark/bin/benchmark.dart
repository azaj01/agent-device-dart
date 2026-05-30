import 'dart:io';

import 'package:agent_device_benchmark/cli_target.dart';
import 'package:agent_device_benchmark/devices.dart';
import 'package:agent_device_benchmark/feature_matrix.dart';
import 'package:agent_device_benchmark/report.dart';
import 'package:agent_device_benchmark/results.dart';
import 'package:agent_device_benchmark/scenarios.dart';

/// Head-to-head benchmark of the Dart port vs the npm agent-device CLI.
///
/// Usage:
///   dart run benchmark/bin/benchmark.dart --platform android [--serial emulator-5554] [--reps 5]
///   dart run benchmark/bin/benchmark.dart --platform ios --udid <UDID> [--reps 5]
Future<void> main(List<String> argv) async {
  final args = _Args.parse(argv);
  final repoRoot = Directory.current.path;

  final dartBin = '$repoRoot/dist/agent-device';
  final npmBin = '$repoRoot/agent-device/bin/agent-device.mjs';
  if (!File(dartBin).existsSync()) {
    stderr.writeln('Missing $dartBin — run `make compile` first.');
    exit(2);
  }
  if (!File(npmBin).existsSync()) {
    stderr.writeln('Missing $npmBin — run `pnpm build` in ./agent-device first.');
    exit(2);
  }

  final serial = await _resolveSerial(args);
  final deviceLabel = await verifyDevice(args.platform, serial);
  stderr.writeln('Target: $deviceLabel');

  // Clean slate: a stale npm daemon would hold Android's UiAutomation and
  // starve the Dart phase.
  await killNpmDaemon();

  stderr.writeln('Ensuring fixture app is installed…');
  await ensureFixtureInstalled(platform: args.platform, serial: serial, repoRoot: repoRoot);

  CliTarget makeDart(String session, String stateDir) => CliTarget.dart(
        binaryPath: dartBin, platform: args.platform, serial: serial, session: session, stateDir: stateDir);
  CliTarget makeNpm(String session, String stateDir) => CliTarget.npm(
        binPath: npmBin, platform: args.platform, serial: serial, session: session, stateDir: stateDir);

  final dartState = '$repoRoot/.tmp/bench-dart-${args.platform}';
  final npmState = '$repoRoot/.tmp/bench-npm-${args.platform}';
  final shotDir = Directory('$repoRoot/benchmark/report/screenshots-${args.platform}')..createSync(recursive: true);

  final dartTarget = makeDart('bench-dart-${args.platform}', dartState);
  final npmTarget = makeNpm('bench-npm-${args.platform}', npmState);

  final dartRun = CliRun(Cli.dart, args.platform);
  final npmRun = CliRun(Cli.npm, args.platform);

  // Run each CLI's full suite back-to-back on the same device.
  for (final pair in [(dartTarget, dartRun), (npmTarget, npmRun)]) {
    final t = pair.$1;
    final run = pair.$2;
    stderr.writeln('\n=== ${t.cli.id.toUpperCase()} ===');

    final v = await t.run(['--version'], withSession: false);
    if (t.cli == Cli.dart) {
      _dartVersion = v.stdout.trim();
    } else {
      _npmVersion = v.stdout.trim();
    }

    stderr.writeln('Measuring cold open (fresh state dir)…');
    run.coldCosts['cold open (fresh state dir)'] = await measureColdOpen(t);

    stderr.writeln('Pre-warming session…');
    await t.run(['snapshot']); // warm caches before timed reps

    stderr.writeln('Running performance suite (${args.reps} reps)…');
    await runPerfSuite(t, run, args.reps, shotDir);

    stderr.writeln('Running accuracy walkthrough…');
    await runWalkthrough(t, run);
    stderr.writeln('Accuracy: ${run.passCount}/${run.totalChecks} checks passed.');
  }

  stderr.writeln('\nProbing feature matrix…');
  final features = await probeFeatureMatrix(dartTarget, npmTarget);

  final report = Report(
    platform: args.platform,
    deviceLabel: deviceLabel,
    timestamp: DateTime.now().toUtc().toIso8601String(),
    reps: args.reps,
    dartVersion: _dartVersion,
    npmVersion: _npmVersion,
    dart: dartRun,
    npm: npmRun,
    features: features,
  );

  final reportDir = Directory('$repoRoot/benchmark/report');
  await report.write(reportDir);
  stdout.writeln('\nWrote ${reportDir.path}/REPORT-${args.platform}.md');
  stdout.writeln('Wrote ${reportDir.path}/results-${args.platform}.json');
}

String _dartVersion = 'unknown';
String _npmVersion = 'unknown';

/// If no serial/udid given, auto-resolve a single booted device.
Future<String> _resolveSerial(_Args args) async {
  if (args.serial != null) return args.serial!;
  if (args.platform == 'android') {
    final r = await Process.run('adb', ['devices']);
    final lines = (r.stdout as String).split('\n').skip(1);
    final serials = [
      for (final l in lines)
        if (l.trim().endsWith('\tdevice')) l.split('\t').first.trim(),
    ];
    if (serials.length == 1) return serials.first;
    throw StateError('Specify --serial; found Android devices: $serials');
  } else {
    final r = await Process.run('xcrun', ['simctl', 'list', 'devices', 'booted']);
    final m = RegExp(r'\(([0-9A-F-]{36})\)').firstMatch(r.stdout as String);
    if (m != null) return m.group(1)!;
    throw StateError('Specify --udid; no booted iOS simulator found.');
  }
}

class _Args {
  _Args(this.platform, this.serial, this.reps);
  final String platform;
  final String? serial;
  final int reps;

  static _Args parse(List<String> argv) {
    String? platform;
    String? serial;
    var reps = 5;
    for (var i = 0; i < argv.length; i++) {
      switch (argv[i]) {
        case '--platform':
          platform = argv[++i];
        case '--serial':
        case '--udid':
        case '--device-id':
          serial = argv[++i];
        case '--reps':
          reps = int.parse(argv[++i]);
        default:
          stderr.writeln('Unknown argument: ${argv[i]}');
      }
    }
    if (platform != 'ios' && platform != 'android') {
      stderr.writeln('Usage: --platform <ios|android> [--serial/--udid <id>] [--reps N]');
      exit(2);
    }
    return _Args(platform!, serial, reps);
  }
}
