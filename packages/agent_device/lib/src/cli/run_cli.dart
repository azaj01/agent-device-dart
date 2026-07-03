// Entry point for the `agent-device` CLI.
library;

import 'dart:io';

import 'package:agent_device/src/utils/diagnostics.dart';
import 'package:agent_device/src/utils/logger.dart';
import 'package:args/command_runner.dart';

import 'commands/batch_cmd.dart';
import 'commands/completion_cmd.dart';
import 'commands/gesture_cmds.dart';
import 'commands/devices_cmd.dart';
import 'commands/install_cmd.dart';
import 'commands/logs_cmd.dart';
import 'commands/network_cmd.dart';
import 'commands/perf_cmd.dart';
import 'commands/record_cmd.dart';
import 'commands/replay_cmd.dart';
import 'commands/runner_cmd.dart';
import 'commands/screenshot_cmd.dart';
import 'commands/selector_cmds.dart';
import 'commands/session_cmd.dart';
import 'commands/simple_action_cmds.dart';
import 'commands/snapshot_cmd.dart';
import 'commands/update_cmd.dart';
import 'output.dart';

/// Build the [CommandRunner] used by both the live CLI and the
/// `completion` subcommand (which introspects `runner.commands` to
/// emit a static script). Adding new top-level subcommands here
/// auto-extends shell completion.
CommandRunner<int> buildCliRunner({String executableName = 'agent-device'}) {
  final runner = CommandRunner<int>(
    executableName,
    'Agent-driven CLI for mobile UI automation, network inspection, '
    'and performance diagnostics.',
    usageLineLength: stdout.hasTerminal ? stdout.terminalColumns : 80,
  );

  // Global flags that are also available on every command (subcommands
  // replicate these via AgentDeviceCommand).
  runner.argParser
    ..addFlag(
      'json',
      help: 'Emit machine-readable JSON output.',
      negatable: false,
    )
    ..addFlag(
      'verbose',
      abbr: 'v',
      help: 'Verbose output / include full error details.',
      negatable: false,
    )
    ..addFlag('debug', help: 'Alias for --verbose.', negatable: false)
    ..addOption(
      'state-dir',
      help:
          'Override the agent-device state directory '
          '(default: \$AGENT_DEVICE_STATE_DIR or ~/.agent-device/).',
    )
    ..addFlag(
      'ephemeral-session',
      help: 'Use an in-memory session store for this invocation.',
      negatable: false,
    );

  runner
    ..addCommand(BatchCommand())
    ..addCommand(DevicesCommand())
    ..addCommand(SnapshotCommand())
    ..addCommand(ScreenshotCommand())
    ..addCommand(OpenCommand())
    ..addCommand(CloseCommand())
    ..addCommand(TapCommand())
    ..addCommand(FillCommand())
    ..addCommand(TypeCommand())
    ..addCommand(FocusCommand())
    ..addCommand(BackCommand())
    ..addCommand(HomeCommand())
    ..addCommand(AppSwitcherCommand())
    ..addCommand(RotateCommand())
    ..addCommand(SwipeCommand())
    ..addCommand(ScrollCommand())
    ..addCommand(LongPressCommand())
    ..addCommand(PinchCommand())
    ..addCommand(GestureCommand())
    ..addCommand(SliderCommand())
    ..addCommand(AppStateCommand())
    ..addCommand(AppsCommand())
    ..addCommand(ClipboardCommand())
    ..addCommand(PressCommand())
    ..addCommand(ClickCommand())
    ..addCommand(SettingsCommand())
    ..addCommand(BootCommand())
    ..addCommand(KeyboardCommand())
    ..addCommand(TriggerAppEventCommand())
    ..addCommand(FindCommand())
    ..addCommand(GetCommand())
    ..addCommand(IsCommand())
    ..addCommand(WaitCommand())
    ..addCommand(InstallCommand())
    ..addCommand(UninstallCommand())
    ..addCommand(ReinstallCommand())
    ..addCommand(LogsCommand())
    ..addCommand(NetworkCommand())
    ..addCommand(PerfCommand())
    ..addCommand(RecordCommand())
    ..addCommand(RunnerCommand())
    ..addCommand(ReplayCommand())
    ..addCommand(TestCommand())
    ..addCommand(SessionCommand())
    ..addCommand(UpdateCommand())
    ..addCommand(CompletionCommand());
  return runner;
}

/// Run the CLI with [argv]. Returns the exit code (0 = ok, 1 = error,
/// 64 = usage error — matching sysexits.h semantics).
///
/// [executableName] customises the program name in `--help` output —
/// pass `'ad'` when invoked through the short alias, `'agent-device'`
/// otherwise. The default falls back to detecting the invoked binary
/// from `Platform.executable`.
/// Sentinel prefix used to shield negative-number positionals from the args
/// parser (see [protectNegativePositionals]). A private-use code point that
/// will never appear in real input.
const String _negativeArgGuard = '';

final RegExp _negativeNumberToken = RegExp(r'^-\d+(\.\d+)?$');

/// `package:args` treats a token like `-120` as a cluster of short flags, so a
/// negative-number positional (`gesture pan 0 -120`, `swipe`, etc.) fails with
/// "Could not find an option with short name -1". Prefix such tokens with a
/// private-use guard so the parser sees a plain positional; [AgentDeviceCommand]
/// strips the guard back off when reading `positionals`.
List<String> protectNegativePositionals(List<String> argv) => [
      for (final arg in argv)
        _negativeNumberToken.hasMatch(arg) ? '$_negativeArgGuard$arg' : arg,
    ];

/// Remove the [protectNegativePositionals] guard from a single token.
String stripNegativeArgGuard(String value) =>
    value.startsWith(_negativeArgGuard) ? value.substring(1) : value;

Future<int> runCli(List<String> argv, {String? executableName}) async {
  final name = executableName ?? _detectExecutableName();
  final runner = buildCliRunner(executableName: name);

  // Decide JSON mode for top-level error reporting by peeking at argv —
  // the CommandRunner hasn't parsed yet when an exception escapes.
  final asJson = argv.contains('--json');
  final verbose =
      argv.contains('--verbose') ||
      argv.contains('-v') ||
      argv.contains('--debug');

  initLogger(verbose: verbose);

  // Root diagnostics scope: emitDiagnostic calls anywhere in the command
  // (exec tracing, screenshot fallbacks, fill verification, …) collect here
  // and flush to ~/.agent-device/logs/<session>/<day>/ on completion when
  // --debug/--verbose is set or an opt-in gate (e.g. AGENT_DEVICE_EXEC_TRACE)
  // marked the scope flush-on-success.
  final sessionIdx = argv.indexOf('--session');
  final session = (sessionIdx >= 0 && sessionIdx + 1 < argv.length)
      ? argv[sessionIdx + 1]
      : null;
  final command = argv
      .where((a) => !a.startsWith('-'))
      .cast<String?>()
      .firstWhere((_) => true, orElse: () => null);

  return withDiagnosticsScope(
    DiagnosticsScopeOptions(session: session, command: command, debug: verbose),
    () async {
      try {
        final result = await runner.run(protectNegativePositionals(argv));
        return result ?? 0;
      } on UsageException catch (e) {
        if (asJson) {
          printError(e.message, asJson: true);
        } else {
          stderr.writeln(e.message);
          stderr.writeln();
          stderr.writeln(e.usage);
        }
        return 64;
      } catch (err) {
        printError(err, asJson: asJson, showDetails: verbose);
        return 1;
      } finally {
        flushDiagnosticsToSessionFile();
      }
    },
  );
}

/// Best-effort guess at the program name the user typed. When invoked
/// through a `dart compile exe` binary `Platform.executable` ends in
/// `agent-device` or `ad`; when `dart run` driving the `bin/` script
/// it ends in `dart`, in which case we fall back to the canonical
/// long name.
String _detectExecutableName() {
  final exe = _basename(Platform.executable);
  if (exe == 'agent-device' || exe == 'ad') return exe;
  return 'agent-device';
}

String _basename(String path) {
  final i = path.lastIndexOf(Platform.pathSeparator);
  return i < 0 ? path : path.substring(i + 1);
}
