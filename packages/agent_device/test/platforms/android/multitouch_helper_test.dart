// Tests for Android multitouch helper output parsing and manifest validation.
// Port of agent-device/src/platforms/android/__tests__/multitouch-helper.test.ts
// (subset — focuses on parse logic, not live adb calls).
import 'package:agent_device/src/platforms/android/multitouch_helper.dart';
import 'package:agent_device/src/utils/errors.dart';
import 'package:test/test.dart';

// Expose testable internals via a small re-export shim at the end of this
// file. Because Dart doesn't allow @visibleForTesting across packages easily
// we keep the tests in the same package.

void main() {
  group('parseAndroidMultitouchHelperManifest', () {
    final validManifest = {
      'name': 'android-multitouch-helper',
      'version': '1.0.0',
      'assetName': 'android-multitouch-helper-1.0.0.apk',
      'sha256': 'a' * 64,
      'packageName': 'com.callstack.agentdevice.multitouchhelper',
      'versionCode': 1,
      'instrumentationRunner':
          'com.callstack.agentdevice.multitouchhelper/.MultiTouchInstrumentation',
      'statusProtocol': 'android-multitouch-helper-v1',
    };

    test('parses a valid manifest', () {
      final m = parseAndroidMultitouchHelperManifestForTest(validManifest);
      expect(m.name, equals('android-multitouch-helper'));
      expect(m.version, equals('1.0.0'));
      expect(m.versionCode, equals(1));
      expect(m.sha256, equals('a' * 64));
      expect(
        m.packageName,
        equals('com.callstack.agentdevice.multitouchhelper'),
      );
    });

    test('rejects wrong name', () {
      expect(
        () => parseAndroidMultitouchHelperManifestForTest({
          ...validManifest,
          'name': 'wrong-name',
        }),
        throwsA(isA<AppError>()),
      );
    });

    test('rejects missing version', () {
      expect(
        () => parseAndroidMultitouchHelperManifestForTest({
          ...validManifest,
          'version': '',
        }),
        throwsA(isA<AppError>()),
      );
    });

    test('rejects malformed sha256 (too short)', () {
      expect(
        () => parseAndroidMultitouchHelperManifestForTest({
          ...validManifest,
          'sha256': 'aabbcc',
        }),
        throwsA(isA<AppError>()),
      );
    });

    test('rejects sha256 with non-hex characters', () {
      expect(
        () => parseAndroidMultitouchHelperManifestForTest({
          ...validManifest,
          'sha256': 'z' * 64,
        }),
        throwsA(isA<AppError>()),
      );
    });

    test('rejects non-integer versionCode', () {
      expect(
        () => parseAndroidMultitouchHelperManifestForTest({
          ...validManifest,
          'versionCode': '1',
        }),
        throwsA(isA<AppError>()),
      );
    });

    test('rejects wrong instrumentationRunner', () {
      expect(
        () => parseAndroidMultitouchHelperManifestForTest({
          ...validManifest,
          'instrumentationRunner': 'wrong/Runner',
        }),
        throwsA(isA<AppError>()),
      );
    });
  });

  group('parseAndroidMultitouchHelperOutput', () {
    test('parses a successful pinch result', () {
      const raw = '''
INSTRUMENTATION_RESULT: agentDeviceProtocol=android-multitouch-helper-v1
INSTRUMENTATION_RESULT: ok=true
INSTRUMENTATION_RESULT: kind=pinch
INSTRUMENTATION_RESULT: helperApiVersion=1
INSTRUMENTATION_RESULT: injectedEvents=12
INSTRUMENTATION_RESULT: elapsedMs=315
INSTRUMENTATION_CODE: -1
''';
      final out = parseAndroidMultitouchHelperOutputForTest(raw);
      expect(out['kind'], equals('pinch'));
      expect(out['helperApiVersion'], equals('1'));
      expect(out['injectedEvents'], equals(12));
      expect(out['elapsedMs'], equals(315));
    });

    test('parses a successful rotate result', () {
      const raw = '''
INSTRUMENTATION_RESULT: agentDeviceProtocol=android-multitouch-helper-v1
INSTRUMENTATION_RESULT: ok=true
INSTRUMENTATION_RESULT: kind=rotate
INSTRUMENTATION_RESULT: helperApiVersion=1
INSTRUMENTATION_CODE: -1
''';
      final out = parseAndroidMultitouchHelperOutputForTest(raw);
      expect(out['kind'], equals('rotate'));
    });

    test('throws ANDROID_MULTITOUCH_HELPER_NO_FINAL_RESULT when protocol marker is missing', () {
      const raw = '''
INSTRUMENTATION_RESULT: something=else
INSTRUMENTATION_CODE: -1
''';
      expect(
        () => parseAndroidMultitouchHelperOutputForTest(raw),
        throwsA(
          isA<AppError>().having(
            (e) => e.code,
            'code',
            equals('ANDROID_MULTITOUCH_HELPER_NO_FINAL_RESULT'),
          ).having(
            (e) => e.message,
            'message',
            equals('Android multi-touch helper did not return a final result'),
          ),
        ),
      );
    });

    test('throws ANDROID_MULTITOUCH_HELPER_REPORTED_FAILURE when ok=false with message', () {
      const raw = '''
INSTRUMENTATION_RESULT: agentDeviceProtocol=android-multitouch-helper-v1
INSTRUMENTATION_RESULT: ok=false
INSTRUMENTATION_RESULT: errorType=java.lang.IllegalStateException
INSTRUMENTATION_RESULT: message=injectInputEvent returned false
INSTRUMENTATION_CODE: -1
''';
      expect(
        () => parseAndroidMultitouchHelperOutputForTest(raw),
        throwsA(
          isA<AppError>()
              .having(
                (e) => e.code,
                'code',
                equals('ANDROID_MULTITOUCH_HELPER_REPORTED_FAILURE'),
              )
              .having(
                (e) => e.message,
                'message',
                contains('injectInputEvent returned false'),
              ),
        ),
      );
    });

    test('handles missing optional fields (injectedEvents, elapsedMs)', () {
      const raw = '''
INSTRUMENTATION_RESULT: agentDeviceProtocol=android-multitouch-helper-v1
INSTRUMENTATION_RESULT: ok=true
INSTRUMENTATION_RESULT: kind=transform
INSTRUMENTATION_RESULT: helperApiVersion=1
INSTRUMENTATION_CODE: -1
''';
      final out = parseAndroidMultitouchHelperOutputForTest(raw);
      expect(out.containsKey('injectedEvents'), isFalse);
      expect(out.containsKey('elapsedMs'), isFalse);
    });
  });
}
