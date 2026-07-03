import 'dart:io';

import 'package:agent_device/src/platforms/ios/runner_build_cache.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

void main() {
  late Directory tmp;
  late String runnerRoot; // simulates .../AgentDeviceRunner
  late String derived; // simulates .../build
  late String productsDir; // simulates .../build/Build/Products

  setUp(() {
    tmp = Directory.systemTemp.createTempSync('runner_cache_test');
    runnerRoot = p.join(tmp.path, 'AgentDeviceRunner');
    derived = p.join(tmp.path, 'build');
    productsDir = p.join(derived, 'Build', 'Products');
    Directory(p.join(runnerRoot, 'AgentDeviceRunnerUITests')).createSync(recursive: true);
    Directory(p.join(productsDir, 'Debug-iphonesimulator')).createSync(recursive: true);
    // A source file and a built product + xctestrun.
    File(p.join(runnerRoot, 'AgentDeviceRunnerUITests', 'RunnerTests+Snapshot.swift'))
        .writeAsStringSync('// snapshot v1\n');
    File(p.join(productsDir, 'AgentDeviceRunner.xctestrun')).writeAsStringSync('<plist/>');
    Directory(p.join(productsDir, 'Debug-iphonesimulator', 'AgentDeviceRunner.app')).createSync();
  });

  tearDown(() => tmp.deleteSync(recursive: true));

  void recordFreshBuild() {
    final expected = RunnerBuildCache.expectedMetadata(runnerRoot, 'simulator');
    RunnerBuildCache.writeFresh(
      derived,
      expected,
      p.join(productsDir, 'AgentDeviceRunner.xctestrun'),
      RunnerBuildCache.collectProducts(productsDir),
    );
  }

  test('reuses a build whose source fingerprint is unchanged', () {
    recordFreshBuild();
    final expected = RunnerBuildCache.expectedMetadata(runnerRoot, 'simulator');
    expect(RunnerBuildCache.canReuse(derived, expected), isTrue);
  });

  test('rejects reuse when source content changes (fingerprint mismatch)', () {
    recordFreshBuild();
    // Edit the Swift source content — fingerprint must change.
    File(p.join(runnerRoot, 'AgentDeviceRunnerUITests', 'RunnerTests+Snapshot.swift'))
        .writeAsStringSync('// snapshot v2 — optimized\n');
    final expected = RunnerBuildCache.expectedMetadata(runnerRoot, 'simulator');
    expect(RunnerBuildCache.canReuse(derived, expected), isFalse);
  });

  test('rejects reuse when a build product is removed/tampered', () {
    recordFreshBuild();
    final expected = RunnerBuildCache.expectedMetadata(runnerRoot, 'simulator');
    expect(RunnerBuildCache.canReuse(derived, expected), isTrue);
    // Delete the product bundle — recorded artifact mtime no longer matches.
    Directory(p.join(productsDir, 'Debug-iphonesimulator', 'AgentDeviceRunner.app'))
        .deleteSync(recursive: true);
    expect(RunnerBuildCache.canReuse(derived, expected), isFalse);
  });

  test('rejects reuse when no cache metadata exists', () {
    final expected = RunnerBuildCache.expectedMetadata(runnerRoot, 'simulator');
    expect(RunnerBuildCache.canReuse(derived, expected), isFalse);
  });

  test('fingerprint is stable across calls for identical content', () {
    final a = RunnerBuildCache.expectedMetadata(runnerRoot, 'simulator').sourceFingerprint;
    final b = RunnerBuildCache.expectedMetadata(runnerRoot, 'simulator').sourceFingerprint;
    expect(a, equals(b));
  });

  test('cache reuse is not invalidated by packageVersion changes', () {
    recordFreshBuild();
    final base = RunnerBuildCache.expectedMetadata(runnerRoot, 'simulator');
    // Simulate a version bump: canReuse still holds because packageVersion is
    // excluded from the comparableEquals key (only schemaVersion, sourceFingerprint,
    // and deviceKind matter).
    final bumpedVersion = RunnerCacheMetadata(
      schemaVersion: base.schemaVersion,
      packageVersion: '${base.packageVersion}-next',
      sourceFingerprint: base.sourceFingerprint,
      deviceKind: base.deviceKind,
    );
    expect(RunnerBuildCache.canReuse(derived, bumpedVersion), isTrue);
  });

  test('cache reuse is invalidated by schemaVersion change', () {
    recordFreshBuild();
    final base = RunnerBuildCache.expectedMetadata(runnerRoot, 'simulator');
    final differentSchema = RunnerCacheMetadata(
      schemaVersion: base.schemaVersion + 1,
      packageVersion: base.packageVersion,
      sourceFingerprint: base.sourceFingerprint,
      deviceKind: base.deviceKind,
    );
    expect(RunnerBuildCache.canReuse(derived, differentSchema), isFalse);
  });
}
