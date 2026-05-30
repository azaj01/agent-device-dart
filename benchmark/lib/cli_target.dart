import 'dart:convert';
import 'dart:io';

/// Which implementation a [CliTarget] drives.
enum Cli {
  dart('dart'),
  npm('npm');

  const Cli(this.id);
  final String id;
}

/// The outcome of a single CLI invocation: wall-clock time, exit code, and the
/// parsed `--json` envelope (if the command produced one).
class RunResult {
  RunResult({
    required this.args,
    required this.durationMs,
    required this.exitCode,
    required this.stdout,
    required this.stderr,
    required this.json,
  });

  final List<String> args;
  final int durationMs;
  final int exitCode;
  final String stdout;
  final String stderr;

  /// Parsed `{success, data, error}` envelope, or null if stdout was not JSON.
  final Map<String, dynamic>? json;

  /// True when the process exited 0 and the envelope reports success.
  bool get ok => exitCode == 0 && (json?['success'] == true);

  /// Convenience accessor for the `data` payload of a successful envelope.
  Object? get data => json?['data'];

  String? get errorMessage {
    final err = json?['error'];
    if (err is Map) return err['message'] as String?;
    return null;
  }
}

/// Wraps one of the two CLIs behind an identical [run] surface so every
/// scenario can be written once and replayed against both implementations.
///
/// The only per-CLI knowledge that lives here is (a) the executable + prefix
/// args and (b) the device-targeting flag, which genuinely differs: the Dart
/// port uses `--serial` for every platform, while the npm CLI expects `--udid`
/// for iOS and `--serial` for Android.
class CliTarget {
  CliTarget({
    required this.cli,
    required this.executable,
    required this.prefixArgs,
    required this.platform,
    required this.serial,
    required this.session,
    required this.stateDir,
  });

  /// Build the Dart target from the compiled binary at [binaryPath].
  factory CliTarget.dart({
    required String binaryPath,
    required String platform,
    required String serial,
    required String session,
    required String stateDir,
  }) =>
      CliTarget(
        cli: Cli.dart,
        executable: binaryPath,
        prefixArgs: const [],
        platform: platform,
        serial: serial,
        session: session,
        stateDir: stateDir,
      );

  /// Build the npm target invoked as `node <bin>/agent-device.mjs`.
  factory CliTarget.npm({
    required String binPath,
    required String platform,
    required String serial,
    required String session,
    required String stateDir,
  }) =>
      CliTarget(
        cli: Cli.npm,
        executable: 'node',
        prefixArgs: [binPath],
        platform: platform,
        serial: serial,
        session: session,
        stateDir: stateDir,
      );

  final Cli cli;
  final String executable;
  final List<String> prefixArgs;
  final String platform;
  final String serial;
  final String session;
  final String stateDir;

  /// The device-targeting flags for this CLI/platform combination.
  List<String> get _deviceFlags =>
      (cli == Cli.npm && platform == 'ios') ? ['--udid', serial] : ['--serial', serial];

  /// Run a single command. By default the common session/platform/device flags
  /// and `--json` are appended; set [withSession] false for commands that take
  /// no session (e.g. `--version`, `devices`, `<cmd> --help`).
  Future<RunResult> run(
    List<String> command, {
    bool withSession = true,
    bool json = true,
  }) async {
    final args = <String>[
      ...prefixArgs,
      ...command,
      if (withSession) ...['--platform', platform, ..._deviceFlags, '--session', session],
      if (json) '--json',
    ];

    final env = <String, String>{
      ...Platform.environment,
      'AGENT_DEVICE_STATE_DIR': stateDir,
    };

    final sw = Stopwatch()..start();
    final proc = await Process.run(
      executable,
      args,
      environment: env,
      // Never source the interactive shell: keep startup timing honest and
      // avoid the user's zsh completion noise leaking into stdout.
      runInShell: false,
    );
    sw.stop();

    final out = (proc.stdout as String?) ?? '';
    // Extract the JSON envelope from stdout. The CLIs may print progress lines
    // before it (e.g. Dart's "[snapshot] auto-building … helper APK…") and npm
    // pretty-prints across multiple lines, so slice from the first '{' to the
    // last '}' rather than requiring stdout to be pure JSON.
    Map<String, dynamic>? parsed;
    final start = out.indexOf('{');
    final end = out.lastIndexOf('}');
    if (start >= 0 && end > start) {
      try {
        final decoded = jsonDecode(out.substring(start, end + 1));
        if (decoded is Map<String, dynamic>) parsed = decoded;
      } on FormatException {
        parsed = null;
      }
    }

    return RunResult(
      args: command,
      durationMs: sw.elapsedMilliseconds,
      exitCode: proc.exitCode,
      stdout: out,
      stderr: (proc.stderr as String?) ?? '',
      json: parsed,
    );
  }
}
