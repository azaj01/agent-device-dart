/// A mutual-exclusion primitive backed by an advisory lock on a sidecar file.
///
/// Dart's [RandomAccessFile.lock] uses POSIX `fcntl` locks, which are owned
/// per *process*, not per file descriptor — two lock requests from the same
/// process on the same inode never conflict. So a file lock alone does NOT
/// serialize concurrent callers within one process. [FileMutex] layers an
/// in-process async queue (keyed by lock-file path) underneath the file lock,
/// so it serializes correctly both within a process and across processes.
///
/// The cross-process acquire retries the *non-blocking* [FileLock.exclusive]
/// with short jittered backoff (rather than blocking indefinitely) so a wedged
/// holder surfaces as a bounded, diagnosable error instead of a hang.
library;

import 'dart:async';
import 'dart:io';
import 'dart:math';

import 'errors.dart';

class FileMutex {
  FileMutex(this.lockFile);

  /// The advisory `.lock` sidecar guarding the protected resource.
  final File lockFile;

  /// In-process serialization: one tail future per lock-file path. Callers
  /// chain onto the tail so same-process `protect` calls run one at a time
  /// before contending for the cross-process file lock.
  static final Map<String, Future<void>> _chains = {};

  static final Random _rng = Random();

  /// Run [body] while holding the lock. Serializes against every other
  /// [protect] call — in this process and others — targeting the same lock
  /// file.
  ///
  /// Waits up to [maxWait] to acquire the cross-process lock, polling every
  /// [pollInterval] (plus small jitter). Throws [AppError] with
  /// [AppErrorCodes.deviceInUse] if the lock can't be acquired within
  /// [maxWait]. [body] itself is not time-bounded.
  Future<T> protect<T>(
    Future<T> Function() body, {
    Duration maxWait = const Duration(seconds: 30),
    Duration pollInterval = const Duration(milliseconds: 20),
  }) async {
    final path = lockFile.path;
    final prev = _chains[path] ?? Future<void>.value();
    final done = Completer<void>();
    _chains[path] = done.future;
    // Wait for the previous in-process holder to release (ignore its outcome).
    await prev.catchError((_) {});
    try {
      return await _withFileLock(body, maxWait, pollInterval);
    } finally {
      done.complete();
      // Drop the entry if we're still the tail, so the map doesn't grow.
      if (identical(_chains[path], done.future)) _chains.remove(path);
    }
  }

  Future<T> _withFileLock<T>(
    Future<T> Function() body,
    Duration maxWait,
    Duration pollInterval,
  ) async {
    final parent = lockFile.parent;
    if (!await parent.exists()) await parent.create(recursive: true);
    if (!await lockFile.exists()) {
      try {
        await lockFile.create();
      } catch (_) {
        // A racing creator won the create — that's fine, it exists now.
      }
    }
    final handle = await lockFile.open(mode: FileMode.write);
    try {
      await _acquire(handle, maxWait, pollInterval);
      try {
        return await body();
      } finally {
        try {
          await handle.unlock();
        } catch (_) {}
      }
    } finally {
      await handle.close();
    }
  }

  Future<void> _acquire(
    RandomAccessFile handle,
    Duration maxWait,
    Duration pollInterval,
  ) async {
    final deadline = DateTime.now().add(maxWait);
    while (true) {
      try {
        await handle.lock(FileLock.exclusive);
        return;
      } on FileSystemException catch (e) {
        if (!DateTime.now().isBefore(deadline)) {
          throw AppError(
            AppErrorCodes.deviceInUse,
            'Could not acquire lock on ${lockFile.path} within '
            '${maxWait.inSeconds}s — another agent-device command is holding '
            'it.',
            details: const {
              'hint': 'Retry; if it persists, check for a wedged ad process.',
            },
            cause: e,
          );
        }
        final jitterMs = _rng.nextInt(10);
        await Future<void>.delayed(
          pollInterval + Duration(milliseconds: jitterMs),
        );
      }
    }
  }
}
