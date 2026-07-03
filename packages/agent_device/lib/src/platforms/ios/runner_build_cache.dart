// Detects when the cached XCUITest runner build is stale and must be rebuilt.
//
// Port of the relevant parts of
// `agent-device/src/platforms/ios/runner-xctestrun.ts`. The CLI builds the
// runner on demand and caches the products under `<ios-runner>/build`. Without
// staleness detection the cache is reused even after the Swift source changes,
// which silently runs an outdated runner (observed driving `snapshot` ~3.7x
// slower than a fresh build).
//
// The signal is a content fingerprint of the runner source, persisted next to
// the build in `.agent-device-runner-cache.json`. A cheap size+mtime
// fingerprint short-circuits the expensive content hash when nothing changed.
library;

import 'dart:convert';
import 'dart:io';

import 'package:agent_device/src/version.dart';
import 'package:crypto/crypto.dart';
import 'package:path/path.dart' as p;

/// Bump to force every cached runner to rebuild (e.g. when the build command
/// or metadata shape changes in a way the fingerprint can't capture).
const int runnerCacheSchemaVersion = 1;

const String _cacheFileName = '.agent-device-runner-cache.json';

/// Source files whose contents affect the built runner. Mirrors the upstream
/// list; `project.pbxproj` is only counted when it lives inside `.xcodeproj`.
const Set<String> _runnerSourceExtensions = {
  '.jpg',
  '.json',
  '.png',
  '.swift',
  '.plist',
  '.entitlements',
  '.xctestplan',
  '.xcconfig',
  '.storyboard',
  '.xib',
};

/// One recorded build product (a `.app`/`.xctest` bundle or the xctestrun),
/// with the mtime it had when the cache was written.
class RunnerCacheArtifact {
  const RunnerCacheArtifact(this.path, this.mtimeMs);
  final String path;
  final int mtimeMs;

  Map<String, Object?> toJson() => {'path': path, 'mtimeMs': mtimeMs};

  static RunnerCacheArtifact? fromJson(Object? raw) {
    if (raw is! Map) return null;
    final path = raw['path'];
    final mtime = raw['mtimeMs'];
    if (path is! String || mtime is! int) return null;
    return RunnerCacheArtifact(path, mtime);
  }
}

/// Persisted cache metadata describing the build that produced the products in
/// a derived-data directory.
class RunnerCacheMetadata {
  const RunnerCacheMetadata({
    required this.schemaVersion,
    required this.packageVersion,
    required this.sourceFingerprint,
    required this.deviceKind,
    this.xctestrun,
    this.products = const [],
  });

  final int schemaVersion;
  final String packageVersion;
  final String sourceFingerprint;
  final String deviceKind;

  /// Recorded xctestrun + product artifacts (absent until a build records them).
  final RunnerCacheArtifact? xctestrun;
  final List<RunnerCacheArtifact> products;

  /// The identity fields a reuse decision compares (everything but artifacts and
  /// packageVersion — the cache survives version bumps as long as the source
  /// fingerprint and toolchain are unchanged).
  bool comparableEquals(RunnerCacheMetadata other) =>
      schemaVersion == other.schemaVersion &&
      sourceFingerprint == other.sourceFingerprint &&
      deviceKind == other.deviceKind;

  RunnerCacheMetadata withArtifacts(RunnerCacheArtifact xctestrun, List<RunnerCacheArtifact> products) =>
      RunnerCacheMetadata(
        schemaVersion: schemaVersion,
        packageVersion: packageVersion,
        sourceFingerprint: sourceFingerprint,
        deviceKind: deviceKind,
        xctestrun: xctestrun,
        products: products,
      );

  Map<String, Object?> toJson() => {
        'schemaVersion': schemaVersion,
        'packageVersion': packageVersion,
        'runnerSourceFingerprint': sourceFingerprint,
        'deviceKind': deviceKind,
        if (xctestrun != null)
          'artifacts': {
            'xctestrun': xctestrun!.toJson(),
            'products': products.map((a) => a.toJson()).toList(),
          },
      };

  static RunnerCacheMetadata? fromJson(Object? raw) {
    if (raw is! Map) return null;
    final schema = raw['schemaVersion'];
    final pkg = raw['packageVersion'];
    final fp = raw['runnerSourceFingerprint'];
    final kind = raw['deviceKind'];
    if (schema is! int || pkg is! String || fp is! String || kind is! String) {
      return null;
    }
    RunnerCacheArtifact? xctestrun;
    var products = const <RunnerCacheArtifact>[];
    final artifacts = raw['artifacts'];
    if (artifacts is Map) {
      xctestrun = RunnerCacheArtifact.fromJson(artifacts['xctestrun']);
      final rawProducts = artifacts['products'];
      if (rawProducts is List) {
        products = rawProducts.map(RunnerCacheArtifact.fromJson).whereType<RunnerCacheArtifact>().toList();
      }
    }
    return RunnerCacheMetadata(
      schemaVersion: schema,
      packageVersion: pkg,
      sourceFingerprint: fp,
      deviceKind: kind,
      xctestrun: xctestrun,
      products: products,
    );
  }
}

/// Staleness detection + cache persistence for the on-demand runner build.
class RunnerBuildCache {
  // In-memory short-circuit: runnerRoot → (statsFingerprint, contentFingerprint).
  static final Map<String, ({String stats, String content})> _fingerprintCache = {};

  static String metadataPath(String derivedDataPath) => p.join(derivedDataPath, _cacheFileName);

  /// The metadata a fresh build of [runnerSourceRoot] for [deviceKind] should
  /// match. Artifacts are filled in by [writeFresh] after the build.
  static RunnerCacheMetadata expectedMetadata(String runnerSourceRoot, String deviceKind) =>
      RunnerCacheMetadata(
        schemaVersion: runnerCacheSchemaVersion,
        packageVersion: packageVersion,
        sourceFingerprint: _sourceFingerprint(runnerSourceRoot),
        deviceKind: deviceKind,
      );

  /// True when the cache in [derivedDataPath] matches [expected] and its
  /// recorded products are still present with unchanged mtimes. Any error or
  /// mismatch returns false so the caller rebuilds.
  static bool canReuse(String derivedDataPath, RunnerCacheMetadata expected) {
    try {
      final actual = _read(derivedDataPath);
      if (actual == null || !actual.comparableEquals(expected)) return false;
      final xctestrun = actual.xctestrun;
      if (xctestrun == null || actual.products.isEmpty) return false;
      if (_mtimeMs(xctestrun.path) != xctestrun.mtimeMs) return false;
      for (final product in actual.products) {
        if (_mtimeMs(product.path) != product.mtimeMs) return false;
      }
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Record [expected] plus the freshly built artifacts so a later run can
  /// reuse them. Best-effort: failures to write never block a usable build.
  static void writeFresh(
    String derivedDataPath,
    RunnerCacheMetadata expected,
    String xctestrunPath,
    List<String> productPaths,
  ) {
    try {
      final xctestrun = _artifact(xctestrunPath);
      final products = [for (final path in productPaths) _artifact(path)].whereType<RunnerCacheArtifact>().toList();
      if (xctestrun == null || products.isEmpty) return;
      final meta = expected.withArtifacts(xctestrun, products);
      Directory(derivedDataPath).createSync(recursive: true);
      File(metadataPath(derivedDataPath))
          .writeAsStringSync('${const JsonEncoder.withIndent('  ').convert(meta.toJson())}\n');
    } catch (_) {
      // Ignore — a missing cache just means the next run revalidates/rebuilds.
    }
  }

  /// The built product bundles (`.app`/`.xctest`) under [productsDir], used to
  /// detect deleted/tampered products on a later run.
  static List<String> collectProducts(String productsDir) {
    final dir = Directory(productsDir);
    if (!dir.existsSync()) return const [];
    final out = <String>[];
    for (final entry in dir.listSync(recursive: true, followLinks: false)) {
      if (entry is Directory && (entry.path.endsWith('.app') || entry.path.endsWith('.xctest'))) {
        out.add(entry.path);
      }
    }
    out.sort();
    return out;
  }

  static RunnerCacheMetadata? _read(String derivedDataPath) {
    final file = File(metadataPath(derivedDataPath));
    if (!file.existsSync()) return null;
    try {
      return RunnerCacheMetadata.fromJson(jsonDecode(file.readAsStringSync()));
    } catch (_) {
      return null;
    }
  }

  static RunnerCacheArtifact? _artifact(String path) {
    final mtime = _mtimeMs(path);
    return mtime == null ? null : RunnerCacheArtifact(path, mtime);
  }

  static int? _mtimeMs(String path) {
    try {
      return FileStat.statSync(path).modified.millisecondsSinceEpoch;
    } catch (_) {
      return null;
    }
  }

  /// SHA-256 over every runner source file (relative path + bytes), with a
  /// size+mtime fingerprint short-circuiting the content read when unchanged.
  static String _sourceFingerprint(String runnerRoot) {
    final files = _collectSourceFiles(runnerRoot);
    final statsFingerprint = _statsFingerprint(runnerRoot, files);
    final cached = _fingerprintCache[runnerRoot];
    if (cached != null && cached.stats == statsFingerprint) {
      return cached.content;
    }
    final bytes = <int>[];
    for (final file in files) {
      bytes
        ..addAll(utf8.encode(p.relative(file, from: runnerRoot)))
        ..add(0)
        ..addAll(File(file).readAsBytesSync())
        ..add(0);
    }
    final content = sha256.convert(bytes).toString();
    _fingerprintCache[runnerRoot] = (stats: statsFingerprint, content: content);
    return content;
  }

  static String _statsFingerprint(String runnerRoot, List<String> files) {
    final buf = StringBuffer();
    for (final file in files) {
      final stat = FileStat.statSync(file);
      buf
        ..write(p.relative(file, from: runnerRoot))
        ..write(' ')
        ..write(stat.size)
        ..write(' ')
        ..write(stat.modified.millisecondsSinceEpoch)
        ..write(' ');
    }
    return sha256.convert(utf8.encode(buf.toString())).toString();
  }

  static List<String> _collectSourceFiles(String root) {
    final dir = Directory(root);
    if (!dir.existsSync()) return const [];
    final files = <String>[];
    for (final entry in dir.listSync(recursive: true, followLinks: true)) {
      if (entry is! File) continue;
      if (entry.path.contains('${p.separator}xcuserdata${p.separator}')) continue;
      if (_isRunnerSourceFile(entry.path)) files.add(entry.path);
    }
    files.sort();
    return files;
  }

  static bool _isRunnerSourceFile(String path) {
    final name = p.basename(path);
    if (name == 'project.pbxproj') {
      return path.contains('.xcodeproj${p.separator}');
    }
    return _runnerSourceExtensions.contains(p.extension(name).toLowerCase());
  }
}
