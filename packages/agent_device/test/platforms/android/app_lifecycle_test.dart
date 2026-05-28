import 'package:agent_device/src/platforms/android/app_lifecycle.dart';
import 'package:test/test.dart';

void main() {
  group('app_lifecycle', () {
    group('androidLocalhostReverseEndpoint', () {
      test('returns tcp endpoint for 127.0.0.1 with port', () {
        expect(
          androidLocalhostReverseEndpoint('exp://127.0.0.1:8083'),
          equals('tcp:8083'),
        );
      });

      test('returns tcp endpoint for localhost with port', () {
        expect(
          androidLocalhostReverseEndpoint('http://localhost:8081'),
          equals('tcp:8081'),
        );
      });

      test('returns tcp endpoint for IPv6 ::1 with port', () {
        expect(
          androidLocalhostReverseEndpoint('http://[::1]:8081/status'),
          equals('tcp:8081'),
        );
      });

      test('returns null for localhost URL without explicit port', () {
        expect(
          androidLocalhostReverseEndpoint('http://localhost/path'),
          isNull,
        );
      });

      test('returns null for non-localhost URL with port', () {
        expect(
          androidLocalhostReverseEndpoint('https://example.com:8083/path'),
          isNull,
        );
      });

      test('returns null for unparseable string', () {
        expect(androidLocalhostReverseEndpoint('not-a-url'), isNull);
      });

      test('returns tcp endpoint for non-http scheme with localhost and port', () {
        expect(
          androidLocalhostReverseEndpoint('exp://127.0.0.1:3000'),
          equals('tcp:3000'),
        );
      });
    });

    group('inferAndroidAppName', () {
      test('extracts non-generic tokens from package name', () {
        expect(inferAndroidAppName('com.example.myapp'), equals('Myapp'));
      });

      test('ignores common prefixes and returns significant token', () {
        expect(
          inferAndroidAppName('com.android.app.gallery'),
          equals('Gallery'),
        );
      });

      test('handles underscores and hyphens as word separators', () {
        expect(
          inferAndroidAppName('com.example.mycoolapp'),
          equals('Mycoolapp'),
        );
      });

      test('capitalizes each word in the result', () {
        expect(inferAndroidAppName('com.google.maps'), equals('Maps'));
      });
    });

    group('isAmStartError', () {
      test('detects "Activity not started" error', () {
        const stdout = 'Error: Activity not started';
        expect(isAmStartError(stdout, ''), isTrue);
      });

      test('detects "unable to resolve Intent" error', () {
        const stderr = 'Error: unable to resolve Intent';
        expect(isAmStartError('', stderr), isTrue);
      });

      test('is case-insensitive', () {
        const stdout = 'error: activity not started';
        expect(isAmStartError(stdout, ''), isTrue);
      });

      test('returns false for success output', () {
        const stdout = 'java.lang.RuntimeException: app.NotStartedException';
        expect(isAmStartError(stdout, ''), isFalse);
      });
    });

    group('parseAndroidLaunchComponent', () {
      test('extracts component from resolved-activity output', () {
        const stdout = '''
          mPriorityState=PriorityState {mPriority=null}
          com.example.app/.MainActivity
        ''';
        expect(
          parseAndroidLaunchComponent(stdout),
          equals('com.example.app/.MainActivity'),
        );
      });

      test('returns null if no component found', () {
        const stdout = 'some random output\nwith no component';
        expect(parseAndroidLaunchComponent(stdout), isNull);
      });

      test('prefers last line with slash', () {
        const stdout = '''
          First line with no slash
          com.example.app/.MainActivity
          second.component/.Activity
        ''';
        final result = parseAndroidLaunchComponent(stdout);
        expect(result, isNotNull);
        expect(result!.contains('/'), isTrue);
      });
    });

    group('parseAndroidLaunchComponent with whitespace', () {
      test('handles extra whitespace in output', () {
        const stdout = '  com.example.app/.MainActivity   other stuff   ';
        final result = parseAndroidLaunchComponent(stdout);
        expect(result, equals('com.example.app/.MainActivity'));
      });
    });
  });
}
