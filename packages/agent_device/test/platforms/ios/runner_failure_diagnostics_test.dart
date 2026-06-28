import 'dart:io';

import 'package:agent_device/src/platforms/ios/runner_failure_diagnostics.dart';
import 'package:agent_device/src/utils/errors.dart';
import 'package:test/test.dart';

void main() {
  group('enrichRunnerFailureFromLog', () {
    late Directory dir;

    setUp(() {
      dir = Directory.systemTemp.createTempSync('agent-device-runner-log-');
    });

    tearDown(() {
      if (dir.existsSync()) dir.deleteSync(recursive: true);
    });

    String writeRunnerLogTail(String contents) {
      final logPath = '${dir.path}/runner.log';
      File(logPath).writeAsStringSync(contents);
      return logPath;
    }

    test(
      'classifies target app AXRuntime CoreText font crashes from log tail',
      () async {
        final logPath = writeRunnerLogTail('''
Thread 0 Crashed::  Dispatch queue: com.apple.main-thread
0   libobjc.A.dylib                        objc_retain + 16
1   CoreText                               CreateFontWithFontURL(__CFURL const*, __CFString const*, __CFString const*) + 512
11  AXRuntime                              reconstitutedSmuggledCTFontFromDictionary + 192
12  AXRuntime                              -[NSDictionary(AXPropertyListCoersion) _axRecursivelyReconstitutedRepresentationFromPropertyListWithError:] + 156
''');
        final error = AppError(
          AppErrorCodes.commandFailed,
          'XCTest recorded a failure while executing type; the action may not '
          'have been performed.',
          details: {'command': 'fill'},
        );

        final enriched = await enrichRunnerFailureFromLog(
          error: error,
          logPath: logPath,
        );

        expect(enriched.code, AppErrorCodes.iosTargetAppCrash);
        expect(
          enriched.details?['runnerFailureReason'],
          'target_app_axruntime_coretext_crash',
        );
        expect(
          enriched.details?['hint'] as String?,
          contains('AXRuntime read accessibility attributes'),
        );
        expect(
          enriched.details?['hint'] as String?,
          contains('latest stable simulator runtime'),
        );
        expect(
          enriched.details?['hint'] as String?,
          contains('exact command, selector/ref'),
        );
      },
    );

    test(
      'keeps ordinary runner failures generic without crash log evidence',
      () async {
        final logPath = writeRunnerLogTail(
          'AGENT_DEVICE_RUNNER_COMMAND_FAILED command=type '
          'error=main thread execution timed out',
        );
        final error = AppError(
          AppErrorCodes.commandFailed,
          'main thread execution timed out',
          details: {'command': 'type'},
        );

        final enriched = await enrichRunnerFailureFromLog(
          error: error,
          logPath: logPath,
        );

        expect(enriched.code, AppErrorCodes.commandFailed);
        expect(enriched.details?['runnerFailureReason'], isNull);
        expect(enriched.details?['hint'], isNull);
      },
    );

    test('returns the original error unchanged when no log path', () async {
      final error = AppError(AppErrorCodes.commandFailed, 'boom');
      final enriched = await enrichRunnerFailureFromLog(error: error);
      expect(identical(enriched, error), isTrue);
    });

    test('appends to an existing hint rather than replacing it', () async {
      final logPath = writeRunnerLogTail('Process crashed while running tests');
      final error = AppError(
        AppErrorCodes.commandFailed,
        'iOS runner tap failed',
        details: {'hint': 'Original hint.'},
      );

      final enriched = await enrichRunnerFailureFromLog(
        error: error,
        logPath: logPath,
      );

      expect(enriched.code, AppErrorCodes.iosTargetAppCrash);
      expect(enriched.details?['runnerFailureReason'], 'target_app_crash');
      expect(
        enriched.details?['hint'] as String?,
        startsWith('Original hint.'),
      );
    });
  });
}
