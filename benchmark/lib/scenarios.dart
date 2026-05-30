import 'dart:io';

import 'apps.dart';
import 'driver.dart';
import 'snapshot.dart';

/// Steady-state performance micro-benchmark.
///
/// Two parts:
///  - **isolated**: snapshots fired back-to-back with nothing in between, after
///    a warm-up — the cleanest read of snapshot cost (no interleaved commands
///    invalidating the runner's accessibility cache).
///  - **mixed**: a representative loop (snapshot/screenshot/perf/appstate/press)
///    reflecting real agent usage.
///
/// Latency is recorded only for invocations that actually succeeded; failures
/// are counted separately so a fast error can never masquerade as a fast call.
Future<void> runPerfSuite(Driver d, BenchApp app, int reps, Directory shotDir) async {
  final t = d.t;

  Future<void> sample(String label, List<String> cmd, {bool withSession = true}) async {
    final r = await t.run(cmd, withSession: withSession);
    if (r.ok) {
      d.run.addLatency(label, r.durationMs);
    } else {
      d.run.recordFailure(label);
    }
  }

  await d.relaunch(app.bundleId(t.platform));

  // Process startup, isolated from any device work.
  for (var i = 0; i < reps; i++) {
    await sample('startup (--version)', ['--version'], withSession: false);
  }

  // Isolated snapshot: warm up once, then fire back-to-back (no other commands).
  await t.run(['snapshot']);
  for (var i = 0; i < reps * 2; i++) {
    await sample('snapshot (isolated)', ['snapshot']);
  }

  // Mixed loop reflecting real usage.
  for (var i = 0; i < reps; i++) {
    await sample('snapshot (mixed)', ['snapshot']);
    await sample('screenshot', ['screenshot', '${shotDir.path}/${t.cli.id}_$i.png']);
    await sample('perf', ['perf']);
    await sample('appstate', ['appstate']);

    final c = centerById(await d.snap(), app.pressTargetId);
    if (c != null) {
      await sample('press', ['press', '${c.x.round()}', '${c.y.round()}']);
    }
  }
}
