// Port of agent-device/src/platforms/setting-state.ts

import '../utils/errors.dart';

/// Parse a boolean toggle state from a string value.
///
/// Accepts `on`/`true`/`1` as enabled and `off`/`false`/`0` as disabled.
/// Throws [AppError] for any other value.
bool parseSettingState(String state) {
  final normalized = state.toLowerCase();
  if (normalized == 'on' || normalized == 'true' || normalized == '1') {
    return true;
  }
  if (normalized == 'off' || normalized == 'false' || normalized == '0') {
    return false;
  }
  throw AppError(AppErrorCodes.invalidArgs, 'Invalid setting state: $state');
}
