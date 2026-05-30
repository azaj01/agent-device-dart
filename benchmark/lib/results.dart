import 'cli_target.dart';

/// One timed command invocation (used for the performance axis).
class Sample {
  Sample(this.label, this.durationMs);
  final String label;
  final int durationMs;
}

/// One deterministic accuracy assertion (used for the accuracy axis).
class Check {
  Check(this.name, this.pass, this.detail);
  final String name;
  final bool pass;
  final String detail;

  Map<String, dynamic> toJson() => {'name': name, 'pass': pass, 'detail': detail};
}

/// Everything one CLI produced on one platform.
class CliRun {
  CliRun(this.cli, this.platform);
  final Cli cli;
  final String platform;

  /// Steady-state latency samples, keyed by command label (multiple reps each).
  /// Only successful invocations are recorded — a fast-failing command must not
  /// pollute the latency medians (a flaw an earlier version of this harness had).
  final Map<String, List<int>> latency = {};

  /// Count of failed (non-success) invocations per label, for transparency.
  final Map<String, int> failures = {};

  /// One-off cold-cost measurements (process startup, first open).
  final Map<String, int> coldCosts = {};

  /// Accuracy assertions from the walkthrough.
  final List<Check> checks = [];

  void addLatency(String label, int ms) => latency.putIfAbsent(label, () => []).add(ms);

  void recordFailure(String label) => failures[label] = (failures[label] ?? 0) + 1;

  int get passCount => checks.where((c) => c.pass).length;
  int get totalChecks => checks.length;
}
