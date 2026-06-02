import 'dart:io';

import 'package:agent_device/src/utils/errors.dart';
import 'package:agent_device/src/utils/file_mutex.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

void main() {
  group('FileMutex', () {
    late Directory tmp;
    late File lockFile;

    setUp(() async {
      tmp = await Directory.systemTemp.createTemp('ad-file-mutex-');
      lockFile = File(p.join(tmp.path, 'res.lock'));
    });

    tearDown(() async {
      if (await tmp.exists()) await tmp.delete(recursive: true);
    });

    test('protect returns the body result', () async {
      final v = await FileMutex(lockFile).protect(() async => 42);
      expect(v, 42);
    });

    test('concurrent protect calls never overlap', () async {
      var active = 0;
      var maxActive = 0;
      Future<void> task() => FileMutex(lockFile).protect(() async {
        active++;
        if (active > maxActive) maxActive = active;
        await Future<void>.delayed(const Duration(milliseconds: 5));
        active--;
      });
      await Future.wait([for (var i = 0; i < 12; i++) task()]);
      expect(maxActive, 1, reason: 'bodies must run mutually exclusively');
      expect(active, 0);
    });

    test('serializes distinct FileMutex instances on the same file', () async {
      final order = <int>[];
      Future<void> task(int id, Duration hold) =>
          FileMutex(lockFile).protect(() async {
            await Future<void>.delayed(hold);
            order.add(id);
          });
      // The slow holder is enqueued first; the fast one must wait its turn.
      final a = task(1, const Duration(milliseconds: 30));
      final b = task(2, const Duration(milliseconds: 1));
      await Future.wait([a, b]);
      expect(order, [1, 2]);
    });

    test('creates the lock file and parent directory on demand', () async {
      final nested = File(p.join(tmp.path, 'a', 'b', 'res.lock'));
      await FileMutex(nested).protect(() async {});
      expect(await nested.exists(), isTrue);
    });

    test('a throwing body still releases the lock for the next caller', () async {
      final m = FileMutex(lockFile);
      await expectLater(
        m.protect(() async => throw StateError('boom')),
        throwsA(isA<StateError>()),
      );
      // Lock must be free now.
      expect(await m.protect(() async => 'ok'), 'ok');
    });

    test('AppError is the canonical timeout type (DEVICE_IN_USE code)', () {
      // Smoke-check the code constant the acquire timeout uses, so a rename
      // doesn't silently change the surfaced error.
      expect(AppErrorCodes.deviceInUse, 'DEVICE_IN_USE');
    });
  });
}
