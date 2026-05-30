import 'dart:io';

import 'cli_target.dart';
import 'oracle.dart';
import 'results.dart';
import 'snapshot.dart';

/// Settle time after an interaction before the next snapshot.
const _settle = Duration(milliseconds: 600);

/// Snapshot, retrying until the accessibility tree is populated. The runner can
/// briefly return an empty tree right after launch/navigation, so a bare
/// snapshot would race; this makes reads deterministic for both CLIs.
Future<Map<String, dynamic>?> _snap(CliTarget t) async {
  Map<String, dynamic>? last;
  for (var i = 0; i < 6; i++) {
    last = (await t.run(['snapshot'])).json;
    if (nodesOf(last).isNotEmpty) return last;
    await Future<void>.delayed(const Duration(milliseconds: 400));
  }
  return last;
}

/// Snapshot, locate [id]'s centre, and `press` it. Returns false if absent.
Future<bool> _tapId(CliTarget t, String id) async {
  final c = centerById(await _snap(t), id);
  if (c == null) return false;
  await t.run(['press', '${c.x.round()}', '${c.y.round()}']);
  await Future<void>.delayed(_settle);
  return true;
}

/// Hard-relaunch the fixture app to return to a known Home state.
///
/// The fixture pushes `MaterialPageRoute`s and the iOS runner has no reliable
/// in-app "back" control for Flutter, so a platform-level terminate + `open`
/// is the deterministic reset. It is identical for both CLIs (device prep, not
/// a measured CLI feature).
Future<void> _resetToHome(CliTarget t) async {
  final app = fixtureAppId(t.platform);
  if (t.platform == 'ios') {
    await Process.run('xcrun', ['simctl', 'terminate', t.serial, app]);
  } else {
    await Process.run('adb', ['-s', t.serial, 'shell', 'am', 'force-stop', app]);
  }
  await Future<void>.delayed(const Duration(milliseconds: 300));
  await t.run(['open', app]);
  await Future<void>.delayed(const Duration(milliseconds: 900));
}

/// Extract the first integer found in [text] (e.g. "Batch count: 3" -> 3).
int? _firstInt(String? text) {
  if (text == null) return null;
  final m = RegExp(r'-?\d+').firstMatch(text);
  return m == null ? null : int.tryParse(m.group(0)!);
}

/// Deterministic accuracy walkthrough across five fixture screens. Each screen
/// starts from a fresh relaunch so navigation never depends on flaky back
/// gestures. The command stream is identical for both CLIs; only [Check]s are
/// recorded (latency is measured separately by [runPerfSuite]).
Future<void> runWalkthrough(CliTarget t, CliRun run) async {
  // --- Home: resolution baseline ---
  await _resetToHome(t);
  var snap = await _snap(t);
  for (final id in homeIds) {
    run.checks.add(Check('home: $id resolves', hasId(snap, id), 'Home snapshot should expose $id'));
  }

  // --- Form Lab: navigation + value extraction ---
  await _resetToHome(t);
  await _tapId(t, Ids.homeOpenFormLab);
  snap = await _snap(t);
  run.checks.add(Check(
    'form: fields resolve',
    hasId(snap, Ids.formName) && hasId(snap, Ids.formEmail) && hasId(snap, Ids.formSubmit),
    'Form Lab snapshot should expose name, email and submit',
  ));
  run.checks.add(Check(
    'form: field value extracted',
    (textOfId(snap, Ids.formName) ?? '').contains('Taylor Tester'),
    'The profile name field\'s default value should be readable from the snapshot',
  ));

  // --- Catalog: navigation into a detail screen (first, on-screen task) ---
  await _resetToHome(t);
  await _tapId(t, Ids.homeOpenCatalog);
  snap = await _snap(t);
  run.checks.add(Check(
    'catalog: list resolves',
    hasId(snap, Ids.catalogFilter) && hasId(snap, Ids.catalogVisibleCount),
    'Catalog snapshot should expose filter field and visible-count text',
  ));
  // The task is a non-hittable Card; a single coordinate tap can miss, so
  // verify-and-retry once (an agent would do the same) to avoid a false flake.
  var detailOpened = false;
  for (var attempt = 0; attempt < 2 && !detailOpened; attempt++) {
    await _tapId(t, Ids.catalogTaskReleaseChecklist);
    snap = await _snap(t);
    detailOpened = hasId(snap, Ids.taskDetailComplete);
  }
  run.checks.add(Check(
    'catalog: detail navigation works',
    detailOpened,
    'Tapping a task should open detail with the complete toggle',
  ));

  // --- State Lab: button-driven state transition ---
  await _resetToHome(t);
  await _tapId(t, Ids.homeOpenStateLab);
  snap = await _snap(t);
  run.checks.add(Check(
    'state: controls resolve',
    hasId(snap, Ids.stateBatchCount) && hasId(snap, Ids.stateIncrease),
    'State Lab snapshot should expose batch count and increase button',
  ));
  final before = _firstInt(textOfId(snap, Ids.stateBatchCount));
  await _tapId(t, Ids.stateIncrease);
  await _tapId(t, Ids.stateIncrease);
  snap = await _snap(t);
  final after = _firstInt(textOfId(snap, Ids.stateBatchCount));
  run.checks.add(Check(
    'state: increment updates counter',
    before != null && after != null && after > before,
    'Batch count should increase after two taps (before=$before, after=$after)',
  ));
}

/// Steady-state performance micro-benchmark: run a fixed set of representative
/// read/interaction commands [reps] times on the Home screen and record each
/// invocation's wall-clock latency.
Future<void> runPerfSuite(CliTarget t, CliRun run, int reps, Directory shotDir) async {
  await _resetToHome(t);

  // Process startup, isolated from any device work.
  for (var i = 0; i < reps; i++) {
    run.addLatency('startup (--version)', (await t.run(['--version'], withSession: false)).durationMs);
  }

  for (var i = 0; i < reps; i++) {
    run.addLatency('snapshot', (await t.run(['snapshot'])).durationMs);
    run.addLatency(
      'screenshot',
      (await t.run(['screenshot', '${shotDir.path}/${t.cli.id}_$i.png'])).durationMs,
    );
    run.addLatency('perf', (await t.run(['perf'])).durationMs);
    run.addLatency('appstate', (await t.run(['appstate'])).durationMs);

    // Interaction round-trip: a harmless press on the title text.
    final c = centerById(await _snap(t), Ids.homeScenarioTitle);
    if (c != null) {
      run.addLatency('press', (await t.run(['press', '${c.x.round()}', '${c.y.round()}'])).durationMs);
    }
  }
}
