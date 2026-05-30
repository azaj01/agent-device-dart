/// Summary statistics over a set of latency samples (milliseconds).
class LatencyStats {
  LatencyStats({
    required this.count,
    required this.min,
    required this.median,
    required this.p95,
    required this.max,
  });

  final int count;
  final int min;
  final int median;
  final int p95;
  final int max;

  /// Compute stats from raw samples. Returns null for an empty list.
  static LatencyStats? from(List<int> samplesIn) {
    if (samplesIn.isEmpty) return null;
    final s = [...samplesIn]..sort();
    return LatencyStats(
      count: s.length,
      min: s.first,
      median: _percentile(s, 50),
      p95: _percentile(s, 95),
      max: s.last,
    );
  }

  /// Nearest-rank percentile over an already-sorted list.
  static int _percentile(List<int> sorted, int p) {
    if (sorted.length == 1) return sorted.first;
    final rank = (p / 100 * (sorted.length - 1)).round();
    return sorted[rank.clamp(0, sorted.length - 1)];
  }

  Map<String, dynamic> toJson() => {
        'count': count,
        'min': min,
        'median': median,
        'p95': p95,
        'max': max,
      };
}
