// Port of agent-device/src/platforms/app-resolution-cache.ts

const int _appResolutionCacheTtlMs = 30000;

/// Identifies the scope (platform + device + variant) for a cache entry.
class AppResolutionCacheScope {
  final String platform; // 'android' | 'ios' | 'macos'
  final String deviceId;
  final String? variant;

  const AppResolutionCacheScope({
    required this.platform,
    required this.deviceId,
    this.variant,
  });
}

class _Entry<T> {
  final T value;
  final int expiresAtMs;

  _Entry(this.value, this.expiresAtMs);
}

/// A process-lifetime in-memory TTL cache for app resolution results.
///
/// Avoids repeated `adb shell pm list packages` / `simctl listapps` calls for
/// the same display-name lookup within a session.  Exact package/bundle IDs
/// bypass the cache in the callers — only display-name matches are stored.
class AppResolutionCache<T> {
  final int _ttlMs;
  final int Function() _nowMs;
  final _entries = <String, _Entry<T>>{};

  AppResolutionCache({int? ttlMs, int Function()? nowMs})
    : _ttlMs = ttlMs ?? _appResolutionCacheTtlMs,
      _nowMs = nowMs ?? _defaultNowMs;

  static int _defaultNowMs() =>
      DateTime.now().millisecondsSinceEpoch;

  T? get(AppResolutionCacheScope scope, String target) {
    final key = _buildKey(scope, target);
    final entry = _entries[key];
    if (entry == null) return null;
    if (entry.expiresAtMs <= _nowMs()) {
      _entries.remove(key);
      return null;
    }
    return entry.value;
  }

  T set(AppResolutionCacheScope scope, String target, T value) {
    _entries[_buildKey(scope, target)] = _Entry(value, _nowMs() + _ttlMs);
    return value;
  }

  void clear(AppResolutionCacheScope scope) {
    _clearScope(scope);
  }

  /// Clears the scope before and after [operation], ensuring stale entries
  /// introduced by concurrent lookups do not persist after an install.
  Future<R> invalidateWhile<R>(
    AppResolutionCacheScope scope,
    Future<R> Function() operation,
  ) async {
    _clearScope(scope);
    try {
      return await operation();
    } finally {
      // A concurrent name lookup can finish after the initial clear and
      // repopulate stale data — clear again on exit.
      _clearScope(scope);
    }
  }

  void _clearScope(AppResolutionCacheScope scope) {
    final prefix = _buildScopePrefix(scope);
    _entries.removeWhere((key, _) => key.startsWith(prefix));
  }

  static String _buildKey(AppResolutionCacheScope scope, String target) {
    return [
      scope.platform,
      scope.deviceId,
      scope.variant ?? '',
      target.trim().toLowerCase(),
    ].join('\x00');
  }

  static String _buildScopePrefix(AppResolutionCacheScope scope) {
    return [scope.platform, scope.deviceId, ''].join('\x00');
  }
}
