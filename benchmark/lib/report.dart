import 'dart:convert';
import 'dart:io';

import 'feature_matrix.dart';
import 'metrics.dart';
import 'results.dart';

/// A Unicode block bar of [width] cells representing [value]/[max].
String bar(num value, num max, {int width = 20}) {
  if (max <= 0) return '░' * width;
  final filled = (value / max * width).round().clamp(0, width);
  return '█' * filled + '░' * (width - filled);
}

/// Render the full Markdown report and the machine-readable results.json.
class Report {
  Report({
    required this.app,
    required this.platform,
    required this.deviceLabel,
    required this.timestamp,
    required this.reps,
    required this.dartVersion,
    required this.npmVersion,
    required this.dart,
    required this.npm,
    required this.features,
  });

  final String app;
  final String platform;
  final String deviceLabel;
  final String timestamp;
  final int reps;
  final String dartVersion;
  final String npmVersion;
  final CliRun dart;
  final CliRun npm;
  final List<FeatureRow> features;

  String _latencySection() {
    final b = StringBuffer('## ⏱ Performance — steady-state latency\n\n');
    b.writeln('Median of $reps reps on the Home screen, same booted device, run back-to-back. '
        'Lower is better; bars scale to the slower CLI per row.\n');

    final labels = <String>{...dart.latency.keys, ...npm.latency.keys}.toList();
    for (final label in labels) {
      final ds = LatencyStats.from(dart.latency[label] ?? const []);
      final ns = LatencyStats.from(npm.latency[label] ?? const []);
      final maxMed = [ds?.median ?? 0, ns?.median ?? 0].reduce((a, c) => a > c ? a : c);
      b.writeln('**`$label`**');
      if (ds != null) {
        b.writeln('- dart `${bar(ds.median, maxMed)}` ${ds.median} ms · p95 ${ds.p95} ms');
      }
      if (ns != null) {
        b.writeln('- npm  `${bar(ns.median, maxMed)}` ${ns.median} ms · p95 ${ns.p95} ms');
      }
      if (ds != null && ns != null && ds.median > 0 && ns.median > 0) {
        b.writeln('- ${_speedup(ds.median, ns.median)}');
      }
      b.writeln();
    }
    return b.toString();
  }

  String _speedup(int dartMs, int npmMs) {
    if (dartMs == npmMs) return 'parity';
    if (dartMs < npmMs) {
      return 'Dart is **${(npmMs / dartMs).toStringAsFixed(2)}× faster**';
    }
    return 'npm is **${(dartMs / npmMs).toStringAsFixed(2)}× faster**';
  }

  String _coldSection() {
    final b = StringBuffer('## 🥶 Performance — cold costs (one-off)\n\n');
    b.writeln('| Measurement | Dart | npm |');
    b.writeln('| --- | --- | --- |');
    final keys = <String>{...dart.coldCosts.keys, ...npm.coldCosts.keys};
    for (final k in keys) {
      final d = dart.coldCosts[k];
      final n = npm.coldCosts[k];
      b.writeln('| $k | ${d == null ? '—' : '$d ms'} | ${n == null ? '—' : '$n ms'} |');
    }
    b.writeln('\n> Note: this measures session bootstrap + runner launch on a fresh state dir. '
        'The first-ever native runner *compile* is cached outside the state dir and is not included.\n');
    return b.toString();
  }

  String _accuracySection() {
    final b = StringBuffer('## 🎯 Accuracy — deterministic walkthrough\n\n');
    b.writeln('Identical command stream against the fixture oracle. '
        'Both CLIs are expected to reach parity; any miss is a flagged divergence.\n');

    for (final entry in [('Dart', dart), ('npm', npm)]) {
      final name = entry.$1;
      final run = entry.$2;
      final pct = run.totalChecks == 0 ? 0 : (run.passCount / run.totalChecks * 100).round();
      b.writeln('- **$name**: ${run.passCount}/${run.totalChecks} '
          '`${bar(run.passCount, run.totalChecks == 0 ? 1 : run.totalChecks)}` $pct%');
    }
    b.writeln();

    final dartFails = dart.checks.where((c) => !c.pass).toList();
    final npmFails = npm.checks.where((c) => !c.pass).toList();
    if (dartFails.isEmpty && npmFails.isEmpty) {
      b.writeln('✅ No divergences — both CLIs passed every check.\n');
    } else {
      b.writeln('### Divergences\n');
      for (final entry in [('Dart', dartFails), ('npm', npmFails)]) {
        if (entry.$2.isEmpty) continue;
        b.writeln('**${entry.$1} failures:**');
        for (final c in entry.$2) {
          b.writeln('- ❌ ${c.name} — ${c.detail}');
        }
        b.writeln();
      }
    }
    return b.toString();
  }

  String _featureSection() {
    final dartCount = features.where((f) => f.dartOk).length;
    final npmCount = features.where((f) => f.npmOk).length;
    final total = features.length;
    final b = StringBuffer('## 🧩 Feature set — command parity\n\n');
    b.writeln('Probed by invoking `<cli> <command> --help` on each built binary '
        '(✅ = command present). Notes mark documented port design choices.\n');
    b.writeln('- **Dart**: $dartCount/$total `${bar(dartCount, total)}`');
    b.writeln('- **npm**:  $npmCount/$total `${bar(npmCount, total)}`\n');
    b.writeln('| Command | Dart | npm | Notes |');
    b.writeln('| --- | :---: | :---: | --- |');
    for (final f in features) {
      b.writeln('| `${f.name}` | ${f.dartOk ? '✅' : '❌'} | ${f.npmOk ? '✅' : '❌'} | ${f.note} |');
    }
    b.writeln();
    return b.toString();
  }

  String markdown() {
    final b = StringBuffer();
    b.writeln('# agent-device: Dart port vs npm — benchmark\n');
    b.writeln('| | |');
    b.writeln('| --- | --- |');
    b.writeln('| Target app | `$app` |');
    b.writeln('| Platform | `$platform` |');
    b.writeln('| Device | $deviceLabel |');
    b.writeln('| Generated | $timestamp |');
    b.writeln('| Reps (perf) | $reps |');
    b.writeln('| Dart binary | `$dartVersion` |');
    b.writeln('| npm CLI | `$npmVersion` |');
    b.writeln();
    b.writeln('Both CLIs drive the **same** Flutter fixture app on the **same** device through '
        'OS-level accessibility, so this is a like-for-like comparison.\n');
    b.writeln(_latencySection());
    b.writeln(_coldSection());
    b.writeln(_accuracySection());
    b.writeln(_featureSection());
    return b.toString();
  }

  Map<String, dynamic> _runJson(CliRun run) => {
        'cli': run.cli.id,
        'latencyMs': {
          for (final e in run.latency.entries) e.key: LatencyStats.from(e.value)?.toJson(),
        },
        'coldCostsMs': run.coldCosts,
        'accuracy': {
          'passed': run.passCount,
          'total': run.totalChecks,
          'checks': run.checks.map((c) => c.toJson()).toList(),
        },
      };

  Map<String, dynamic> json() => {
        'app': app,
        'platform': platform,
        'device': deviceLabel,
        'generated': timestamp,
        'reps': reps,
        'versions': {'dart': dartVersion, 'npm': npmVersion},
        'dart': _runJson(dart),
        'npm': _runJson(npm),
        'features': features.map((f) => f.toJson()).toList(),
      };

  /// Write REPORT and results.json into [dir], tagged by app + platform.
  Future<void> write(Directory dir) async {
    dir.createSync(recursive: true);
    final suffix = '$app-$platform';
    await File('${dir.path}/REPORT-$suffix.md').writeAsString(markdown());
    await File('${dir.path}/results-$suffix.json')
        .writeAsString(const JsonEncoder.withIndent('  ').convert(json()));
  }
}
