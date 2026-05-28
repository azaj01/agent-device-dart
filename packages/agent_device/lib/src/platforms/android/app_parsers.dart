/// Port of agent-device/src/platforms/android/app-parsers.ts.
///
/// Parsing helpers for Android shell output: package listings, foreground app
/// detection, and component name extraction from dumpsys window manager output.
library;

/// Information about the currently foreground app on an Android device.
class AndroidForegroundApp {
  final String? package;
  final String? activity;

  AndroidForegroundApp({this.package, this.activity});
}

/// Focus info for a window that looks like a blocking dialog (ANR / "not responding").
///
/// Port of `AndroidBlockingDialogFocus` in `app-parsers.ts`.
class AndroidBlockingDialogFocus {
  /// The package name owning the dialog, if detectable.
  final String? package;

  /// Human-readable window title extracted from the focus line.
  final String focusedWindow;

  /// The raw focus line from dumpsys output.
  final String raw;

  const AndroidBlockingDialogFocus({
    this.package,
    required this.focusedWindow,
    required this.raw,
  });
}

// ---------------------------------------------------------------------------
// Constants shared between foreground-app and blocking-dialog parsers.
// ---------------------------------------------------------------------------

const _androidFocusMarkers = [
  'mCurrentFocus=Window{',
  'mFocusedApp=AppWindowToken{',
  'mResumedActivity:',
  'ResumedActivity:',
];

final _androidAnrTitlePattern = RegExp(
  r'\bApplication Not Responding:\s*([A-Za-z0-9_.]+)',
  caseSensitive: false,
);

final _androidRespondingTitlePattern = RegExp(
  r"([^{}]*\bis(?:n't| not)\s+responding[^{}]*)",
  caseSensitive: false,
);

final _androidPackagePattern = RegExp(
  r'\b([A-Za-z][A-Za-z0-9_]*(?:\.[A-Za-z0-9_]+)+)\b',
);

// ---------------------------------------------------------------------------
// Parsers
// ---------------------------------------------------------------------------

/// Parse launchable package names from Android `pm list packages` output.
///
/// Accepts package names prefixed with "package:" (standard pm list format)
/// or bare package names. Handles component references (package/activity) by
/// extracting just the package part. Returns unique package names in order.
List<String> parseAndroidLaunchablePackages(String stdout) {
  final packages = <String>{};
  for (final line in stdout.split('\n')) {
    final trimmed = line.trim();
    if (trimmed.isEmpty) continue;

    final firstToken = trimmed.split(RegExp(r'\s+'))[0];
    final pkg = firstToken.contains('/')
        ? firstToken.split('/')[0]
        : firstToken;

    if (pkg.isNotEmpty) {
      packages.add(pkg);
    }
  }
  return packages.toList();
}

/// Parse user-installed package names from `pm list packages -3` output.
///
/// Strips "package:" prefix if present, filters out empty lines.
/// Returns package names in order of appearance.
List<String> parseAndroidUserInstalledPackages(String stdout) {
  return stdout
      .split('\n')
      .map((line) {
        final trimmed = line.trim();
        return trimmed.startsWith('package:')
            ? trimmed.substring('package:'.length)
            : trimmed;
      })
      .where((line) => line.isNotEmpty)
      .toList();
}

/// Parse the currently foreground app from `dumpsys window manager` output.
///
/// Searches for known markers (mCurrentFocus, mFocusedApp, mResumedActivity)
/// and extracts package/activity component from the found line. Returns null
/// if no marker found or parsing fails.
AndroidForegroundApp? parseAndroidForegroundApp(String text) {
  return _parseAndroidFocusSegment(
    text,
    (segment, _) => _parseAndroidComponentFromSegment(segment),
  );
}

/// Parse a blocking-dialog focus entry from `dumpsys window` output.
///
/// Looks for focus lines containing ANR title patterns or "isn't responding"
/// text. Returns [AndroidBlockingDialogFocus] with the package name (if
/// detectable) and the focused window description, or null if the focused
/// window is not a blocking dialog.
///
/// Port of `parseAndroidBlockingDialogFocus` in `app-parsers.ts`.
AndroidBlockingDialogFocus? parseAndroidBlockingDialogFocus(String text) {
  return _parseAndroidFocusSegment(
    text,
    _parseAndroidBlockingDialogFromSegment,
  );
}

/// Generic helper: scan [text] for focus marker lines, extract the segment
/// after the marker, and call [parse] on each. Returns the first non-null
/// result, or null.
T? _parseAndroidFocusSegment<T>(
  String text,
  T? Function(String segment, String raw) parse,
) {
  final lines = text.split('\n');
  for (final marker in _androidFocusMarkers) {
    for (final line in lines) {
      final markerIndex = line.indexOf(marker);
      if (markerIndex == -1) continue;
      final raw = line.trim();
      final segment = line.substring(markerIndex + marker.length);
      final parsed = parse(segment, raw);
      if (parsed != null) return parsed;
    }
  }
  return null;
}

/// Parse an [AndroidBlockingDialogFocus] from a window-focus segment.
AndroidBlockingDialogFocus? _parseAndroidBlockingDialogFromSegment(
  String segment,
  String raw,
) {
  final windowText =
      (segment.split('}').firstOrNull ?? segment).trim();

  final anrMatch = _androidAnrTitlePattern.firstMatch(windowText);
  if (anrMatch != null) {
    final packageName = anrMatch.group(1)!;
    return AndroidBlockingDialogFocus(
      package: packageName,
      focusedWindow: 'Application Not Responding: $packageName',
      raw: raw,
    );
  }

  final respondingMatch = _androidRespondingTitlePattern.firstMatch(windowText);
  if (respondingMatch == null) return null;

  final focusedWindow = respondingMatch
      .group(1)!
      .trim()
      .replaceAll(RegExp(r'\s+'), ' ');
  final packageName = _androidPackagePattern.firstMatch(focusedWindow)?.group(1);
  return AndroidBlockingDialogFocus(
    package: packageName,
    focusedWindow: focusedWindow,
    raw: raw,
  );
}

/// Parse a package/activity component from a text segment.
///
/// Looks for space-delimited tokens matching pattern: name/name where
/// name contains alphanumeric, underscore, dot, or $ characters.
AndroidForegroundApp? _parseAndroidComponentFromSegment(String segment) {
  for (final token in segment.trim().split(RegExp(r'\s+'))) {
    final slashIndex = token.indexOf('/');
    if (slashIndex <= 0) continue;

    final packageName = _readAndroidName(token.substring(0, slashIndex), false);
    final activity = _readAndroidName(token.substring(slashIndex + 1), true);

    if (packageName.isNotEmpty &&
        activity.isNotEmpty &&
        packageName.length == slashIndex) {
      return AndroidForegroundApp(package: packageName, activity: activity);
    }
  }

  return null;
}

/// Extract a valid Android name from the beginning of a string.
///
/// Reads characters while they match the Android name character set
/// (alphanumeric, underscore, dot, and optionally $ if [allowDollar] is true).
String _readAndroidName(String value, bool allowDollar) {
  int index = 0;
  while (index < value.length &&
      _isAndroidNameChar(value[index], allowDollar)) {
    index += 1;
  }
  return value.substring(0, index);
}

/// Check if a character is valid in an Android package or activity name.
///
/// Valid characters: a-z, A-Z, 0-9, underscore, dot, and optionally $.
bool _isAndroidNameChar(String char, bool allowDollar) {
  if (char.isEmpty) return false;

  final code = char.codeUnitAt(0);
  return (code >= 48 && code <= 57) || // 0-9
      (code >= 65 && code <= 90) || // A-Z
      (code >= 97 && code <= 122) || // a-z
      char == '_' ||
      char == '.' ||
      (allowDollar && code == 36); // $ (36 is ASCII code for $)
}
