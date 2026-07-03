// Unit coverage for the devicectl JSON payload parsers and constants.
// These run on every host because they don't shell out — they just
// exercise the pure-Dart mapping functions against sample payloads.

import 'dart:convert';

import 'package:agent_device/src/platforms/ios/devicectl.dart';
import 'package:test/test.dart';

void main() {
  group('parseIosDeviceAppsPayload', () {
    test('maps bundleIdentifier + name + url', () {
      final payload = jsonDecode('''
{
  "result": {
    "apps": [
      {"bundleIdentifier": "com.example.foo", "name": "Foo App", "url": "file:///a/Foo.app"},
      {"bundleIdentifier": "com.example.bar", "name": "", "url": ""}
    ]
  }
}
''');
      final parsed = parseIosDeviceAppsPayload(payload);
      expect(parsed, hasLength(2));
      expect(parsed[0].bundleId, 'com.example.foo');
      expect(parsed[0].name, 'Foo App');
      expect(parsed[0].url, 'file:///a/Foo.app');
      expect(parsed[1].bundleId, 'com.example.bar');
      expect(
        parsed[1].name,
        'com.example.bar',
        reason: 'Empty name should fall back to bundleId.',
      );
      expect(parsed[1].url, isNull);
    });

    test('tolerates malformed / empty payloads', () {
      expect(parseIosDeviceAppsPayload(null), isEmpty);
      expect(parseIosDeviceAppsPayload({'result': null}), isEmpty);
      expect(
        parseIosDeviceAppsPayload({'result': <String, Object?>{}}),
        isEmpty,
      );
      expect(
        parseIosDeviceAppsPayload({
          'result': {'apps': 'not a list'},
        }),
        isEmpty,
      );
    });

    test('skips entries missing bundleIdentifier', () {
      final payload = jsonDecode('''
{"result": {"apps": [{"name": "no-id"}, {"bundleIdentifier": "   "}]}}
''');
      expect(parseIosDeviceAppsPayload(payload), isEmpty);
    });
  });

  group('timeout constants', () {
    // Mirror of upstream test: installIosInstallablePath on physical device
    // uses extended devicectl install timeout (IOS_DEVICE_INSTALL_TIMEOUT_MS).
    // We can't mock runCmd here, so we assert the constant values instead —
    // installIosDeviceApp calls runIosDevicectl with iosDeviceInstallTimeoutMs.
    test('iosDeviceInstallTimeoutMs keeps the 180s end-to-end budget', () {
      // Upstream: 120s platform install timeout under a 180s daemon-client
      // install budget. Daemon-less, the exec timeout is the whole budget.
      expect(iosDeviceInstallTimeoutMs, equals(180000));
    });

    test('iosDeviceInstallTimeoutMs exceeds iosDevicectlTimeoutMs', () {
      expect(iosDeviceInstallTimeoutMs, greaterThan(iosDevicectlTimeoutMs));
    });
  });
}
