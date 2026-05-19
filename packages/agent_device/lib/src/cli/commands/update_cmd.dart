library;

import 'dart:io';

import 'package:agent_device/src/version.dart';
import 'package:pub_updater/pub_updater.dart';

import '../base_command.dart';

const _packageName = 'agent_device';

class UpdateCommand extends AgentDeviceCommand {
  UpdateCommand({PubUpdater? pubUpdater})
    : _pubUpdater = pubUpdater ?? PubUpdater();

  final PubUpdater _pubUpdater;

  @override
  String get name => 'update';

  @override
  String get description => 'Update agent_device to the latest version.';

  @override
  Future<int> run() async {
    final currentVersion = packageVersion;
    final latestVersion = await _pubUpdater.getLatestVersion(_packageName);

    final isUpToDate = currentVersion == latestVersion;
    if (isUpToDate) {
      emitResult(
        {
          'currentVersion': currentVersion,
          'latestVersion': latestVersion,
          'upToDate': true,
        },
        humanFormat: (_) =>
            'agent_device is already at the latest version ($currentVersion).',
      );
      return 0;
    }

    final installMethod = _detectInstallMethod();

    if (installMethod == _InstallMethod.compiled) {
      emitResult(
        {
          'currentVersion': currentVersion,
          'latestVersion': latestVersion,
          'upToDate': false,
          'installMethod': 'compiled',
        },
        humanFormat: (_) =>
            'Update available: $currentVersion → $latestVersion\n'
            'This binary was compiled — automatic update is not supported.\n'
            'To update:\n'
            '  brew upgrade agent-device   (if installed via Homebrew)\n'
            '  make compile                (if built from source)',
      );
      return 0;
    }

    if (installMethod == _InstallMethod.localPath) {
      emitResult(
        {
          'currentVersion': currentVersion,
          'latestVersion': latestVersion,
          'upToDate': false,
          'installMethod': 'local-path',
        },
        humanFormat: (_) =>
            'Update available: $currentVersion → $latestVersion\n'
            'Installed from local path — run `git pull && dart pub get` to update.',
      );
      return 0;
    }

    emitResult(
      {
        'currentVersion': currentVersion,
        'latestVersion': latestVersion,
        'upToDate': false,
        'updating': true,
      },
      humanFormat: (_) =>
          'Updating agent_device from $currentVersion to $latestVersion...',
    );

    await _pubUpdater.update(packageName: _packageName);

    emitResult({
      'currentVersion': latestVersion,
      'latestVersion': latestVersion,
      'upToDate': true,
      'updated': true,
    }, humanFormat: (_) => 'Updated agent_device to $latestVersion.');
    return 0;
  }
}

enum _InstallMethod { pubGlobal, compiled, localPath }

_InstallMethod _detectInstallMethod() {
  final exe = Platform.resolvedExecutable;
  final exeBasename = exe.split(Platform.pathSeparator).last;
  // Compiled binary: the resolved executable is the ad/agent-device binary
  // itself, not the dart runtime.
  if (exeBasename != 'dart' && exeBasename != 'dart.exe') {
    return _InstallMethod.compiled;
  }
  // Local path activation: Platform.script points into the source tree
  // rather than the pub cache.
  try {
    final script = Platform.script.toFilePath();
    if (!script.contains('.pub-cache') && !script.contains('pub_cache')) {
      return _InstallMethod.localPath;
    }
  } catch (_) {}
  return _InstallMethod.pubGlobal;
}
