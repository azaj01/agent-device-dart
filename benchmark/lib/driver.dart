import 'dart:io';

import 'cli_target.dart';
import 'results.dart';
import 'snapshot.dart';

/// Shared interaction helpers used by every app walkthrough. Wraps a
/// [CliTarget] and accumulates accuracy [Check]s onto a [CliRun]. Interactions
/// are expressed only through commands both CLIs support identically
/// (`snapshot`, `press`, `type`, `scroll`), so the command stream is the same
/// regardless of which implementation is under test.
class Driver {
  Driver(this.t, this.run);

  final CliTarget t;
  final CliRun run;

  static const settle = Duration(milliseconds: 600);

  /// Snapshot, retrying until the tree is populated (the runner can briefly
  /// return an empty tree right after launch/navigation).
  Future<Map<String, dynamic>?> snap() async {
    Map<String, dynamic>? last;
    for (var i = 0; i < 6; i++) {
      last = (await t.run(['snapshot'])).json;
      if (nodesOf(last).isNotEmpty) return last;
      await Future<void>.delayed(const Duration(milliseconds: 400));
    }
    return last;
  }

  /// Tap the on-screen centre of [id]. Returns false if absent/off-screen.
  Future<bool> tapId(String id) async {
    final c = centerById(await snap(), id);
    if (c == null) return false;
    await t.run(['press', '${c.x.round()}', '${c.y.round()}']);
    await Future<void>.delayed(settle);
    return true;
  }

  /// Focus [id] (a text field) by pressing it, then `type` [text]. This is the
  /// portable text-entry path: the Dart iOS backend does not support coordinate
  /// `fill`, but `press` + `type` works on both CLIs and platforms.
  Future<bool> typeInto(String id, String text) async {
    final c = centerById(await snap(), id);
    if (c == null) return false;
    await t.run(['press', '${c.x.round()}', '${c.y.round()}']);
    await Future<void>.delayed(const Duration(milliseconds: 400));
    await t.run(['type', text]);
    await Future<void>.delayed(settle);
    return true;
  }

  /// Tap a node by its accessibility label (used for the test-app's native tab
  /// bar, whose tabs carry labels rather than testIDs). Prefers a button-like,
  /// bottom-most match so a tab is chosen over a same-named text heading.
  Future<bool> tapLabel(String label) async {
    final nodes = nodesOf(await snap());
    Map<String, dynamic>? best;
    for (final n in nodes) {
      if (n['label'] != label) continue;
      final r = n['rect'];
      if (r is! Map || (r['width'] as num? ?? 0) <= 0) continue;
      final isButton = (n['type']?.toString().toLowerCase().contains('button') ?? false);
      final y = (r['y'] as num).toDouble();
      if (best == null) {
        best = n;
      } else {
        final bIsButton = (best['type']?.toString().toLowerCase().contains('button') ?? false);
        final bY = (best['rect']['y'] as num).toDouble();
        if ((isButton && !bIsButton) || (isButton == bIsButton && y > bY)) best = n;
      }
    }
    if (best == null) return false;
    final r = best['rect'] as Map;
    final x = ((r['x'] as num) + (r['width'] as num) / 2).round();
    final y = ((r['y'] as num) + (r['height'] as num) / 2).round();
    await t.run(['press', '$x', '$y']);
    await Future<void>.delayed(settle);
    return true;
  }

  /// Scroll until [id] is on-screen (centre within bounds). Returns whether it
  /// became reachable. `scroll up` reveals content below the fold.
  Future<bool> revealId(String id, {int maxScrolls = 4}) async {
    if (centerById(await snap(), id) != null) return true;
    for (var i = 0; i < maxScrolls; i++) {
      await t.run(['scroll', 'up', '400']);
      await Future<void>.delayed(const Duration(milliseconds: 500));
      if (centerById(await snap(), id) != null) return true;
    }
    return false;
  }

  /// Reveal (scrolling if needed) then tap [id].
  Future<bool> tapIdScrolling(String id) async => (await revealId(id)) && (await tapId(id));

  /// Dismiss the software keyboard (both CLIs support `keyboard dismiss`). The
  /// keyboard otherwise covers below-fold controls and swallows taps.
  Future<void> dismissKeyboard() async {
    await t.run(['keyboard', 'dismiss']);
    await Future<void>.delayed(const Duration(milliseconds: 500));
  }

  /// Navigate back. On Android the hardware `back` works; on iOS the runner has
  /// no in-app back control for Flutter routes, so tap the nav-bar "Back"
  /// button instead. Returns whether a back action was issued.
  Future<bool> goBack() async {
    if (t.platform == 'android') {
      final ok = (await t.run(['back'])).ok;
      await Future<void>.delayed(settle);
      return ok;
    }
    final ok = await tapLabel('Back');
    if (ok) await Future<void>.delayed(settle);
    return ok;
  }

  /// Run a `gesture <sub> …` command (pinch | pan | fling | rotate | transform),
  /// then settle. Returns whether it succeeded.
  Future<bool> gesture(List<String> args) async {
    final r = await t.run(['gesture', ...args]);
    await Future<void>.delayed(settle);
    return r.ok;
  }

  /// Tap a tab by [label] and confirm [expectId] is present afterward,
  /// retrying to ride out a missed tap or a snapshot taken mid-transition.
  Future<bool> openTab(String label, String expectId) async {
    for (var i = 0; i < 3; i++) {
      await tapLabel(label);
      if (hasId(await snap(), expectId)) return true;
    }
    return false;
  }

  /// Centre of [id] as integer "x y" args, or null if absent/off-screen.
  Future<List<String>?> centerArgs(String id) async {
    final c = centerById(await snap(), id);
    return c == null ? null : ['${c.x.round()}', '${c.y.round()}'];
  }

  /// Hard-relaunch [bundleId] to a known first screen (terminate + open). The
  /// in-app back control is unreliable for these apps' pushed routes, so a
  /// platform-level relaunch is the deterministic reset; it is identical for
  /// both CLIs (device prep, not a measured feature).
  Future<void> relaunch(String bundleId) async {
    if (t.platform == 'ios') {
      await Process.run('xcrun', ['simctl', 'terminate', t.serial, bundleId]);
    } else {
      await Process.run('adb', ['-s', t.serial, 'shell', 'am', 'force-stop', bundleId]);
    }
    await Future<void>.delayed(const Duration(milliseconds: 300));
    await t.run(['open', bundleId]);
    // Heavier (React Native) apps need longer to render their first frame after
    // a cold relaunch before the accessibility tree is populated.
    await Future<void>.delayed(const Duration(milliseconds: 1600));
  }

  void check(String name, bool pass, String detail) => run.checks.add(Check(name, pass, detail));
}

/// First integer found in [text] (e.g. "Visible tasks: 3" -> 3).
int? firstInt(String? text) {
  if (text == null) return null;
  final m = RegExp(r'-?\d+').firstMatch(text);
  return m == null ? null : int.tryParse(m.group(0)!);
}
