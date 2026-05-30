import 'dart:io';

import 'apps.dart';
import 'driver.dart';
import 'snapshot.dart';

/// Steady-state performance micro-benchmark: run a fixed set of representative
/// read/interaction commands [reps] times on the app's first screen and record
/// each invocation's wall-clock latency. App-agnostic apart from the relaunch
/// bundle id and the on-screen tap target, both provided by [app].
Future<void> runPerfSuite(Driver d, BenchApp app, int reps, Directory shotDir) async {
  final t = d.t;
  await d.relaunch(app.bundleId(t.platform));

  // Process startup, isolated from any device work.
  for (var i = 0; i < reps; i++) {
    d.run.addLatency('startup (--version)', (await t.run(['--version'], withSession: false)).durationMs);
  }

  for (var i = 0; i < reps; i++) {
    d.run.addLatency('snapshot', (await t.run(['snapshot'])).durationMs);
    d.run.addLatency(
      'screenshot',
      (await t.run(['screenshot', '${shotDir.path}/${t.cli.id}_$i.png'])).durationMs,
    );
    d.run.addLatency('perf', (await t.run(['perf'])).durationMs);
    d.run.addLatency('appstate', (await t.run(['appstate'])).durationMs);

    final c = centerById(await d.snap(), app.pressTargetId);
    if (c != null) {
      d.run.addLatency('press', (await t.run(['press', '${c.x.round()}', '${c.y.round()}'])).durationMs);
    }
  }
}
