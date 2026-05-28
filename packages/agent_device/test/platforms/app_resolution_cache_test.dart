// Port of agent-device/src/platforms/__tests__/app-resolution-cache.test.ts

import 'package:agent_device/src/platforms/app_resolution_cache.dart';
import 'package:test/test.dart';

void main() {
  group('AppResolutionCache', () {
    test('returns values until the expiry boundary', () {
      var nowMs = 1000;
      final cache = AppResolutionCache<String>(
        ttlMs: 50,
        nowMs: () => nowMs,
      );
      const scope = AppResolutionCacheScope(
        platform: 'android',
        deviceId: 'device-a',
      );

      expect(cache.set(scope, 'Maps', 'com.example.maps'), 'com.example.maps');
      expect(cache.get(scope, 'maps'), 'com.example.maps');

      nowMs = 1049;
      expect(cache.get(scope, 'Maps'), 'com.example.maps');

      nowMs = 1050;
      expect(cache.get(scope, 'Maps'), isNull);
      expect(cache.get(scope, 'Maps'), isNull);
    });

    test('clear removes all variants for one device', () {
      final cache = AppResolutionCache<String>(nowMs: () => 0);
      // The Dart port uses a single scope per (platform, deviceId) — no
      // 'variant' field is used as part of the scope prefix, so entries for
      // the same platform+deviceId are all cleared together.
      const mobile = AppResolutionCacheScope(
        platform: 'android',
        deviceId: 'device-a',
        variant: 'mobile',
      );
      const tv = AppResolutionCacheScope(
        platform: 'android',
        deviceId: 'device-a',
        variant: 'tv',
      );
      const otherDevice = AppResolutionCacheScope(
        platform: 'android',
        deviceId: 'device-b',
        variant: 'mobile',
      );
      const otherPlatform = AppResolutionCacheScope(
        platform: 'ios',
        deviceId: 'device-a',
        variant: 'simulator',
      );

      cache.set(mobile, 'Maps', 'com.example.mobile.maps');
      cache.set(tv, 'Maps', 'com.example.tv.maps');
      cache.set(otherDevice, 'Maps', 'com.example.other.maps');
      cache.set(otherPlatform, 'Maps', 'com.example.ios.maps');

      cache.clear(mobile);

      expect(cache.get(mobile, 'Maps'), isNull);
      expect(cache.get(tv, 'Maps'), isNull);
      expect(cache.get(otherDevice, 'Maps'), 'com.example.other.maps');
      expect(cache.get(otherPlatform, 'Maps'), 'com.example.ios.maps');
    });

    test('invalidateWhile clears before and after an operation', () async {
      final cache = AppResolutionCache<String>(nowMs: () => 0);
      const scope = AppResolutionCacheScope(
        platform: 'ios',
        deviceId: 'device-a',
        variant: 'simulator',
      );

      cache.set(scope, 'Maps', 'com.example.before');

      final result = await cache.invalidateWhile(scope, () async {
        expect(cache.get(scope, 'Maps'), isNull);
        cache.set(scope, 'Maps', 'com.example.during');
        return 'installed';
      });

      expect(result, 'installed');
      expect(cache.get(scope, 'Maps'), isNull);
    });
  });
}
