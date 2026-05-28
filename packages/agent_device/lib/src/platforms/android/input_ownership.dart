// Port of agent-device/src/platforms/android/input-ownership.ts

/// Classification of input ownership (app or IME).
enum AndroidInputOwner {
  app('app'),
  ime('ime'),
  unknown('unknown');

  final String value;
  const AndroidInputOwner(this.value);

  @override
  String toString() => value;
}

const _fallbackInputMethodPackages = {
  'com.google.android.inputmethod.latin',
  'com.samsung.android.honeyboard',
  'com.touchtype.swiftkey',
  'com.microsoft.swiftkey',
};

/// Check if a node (by package/resource) is owned by the input method.
///
/// Named-parameter variant matching `isAndroidInputMethodOwnedNode` in TS.
bool isAndroidInputMethodOwnedNode({
  String? packageName,
  String? resourceId,
  String? activeInputMethodPackage,
}) {
  return isAndroidInputMethodOwned(
    packageName,
    resourceId: resourceId,
    activeInputMethodPackage: activeInputMethodPackage,
  );
}

/// Check if a package/resource is owned by the input method.
bool isAndroidInputMethodOwned(
  String? packageName, {
  String? resourceId,
  String? activeInputMethodPackage,
}) {
  final normalizedPackageName = (packageName ?? '').toLowerCase();
  final normalizedResourceId = (resourceId ?? '').toLowerCase();
  final normalizedInputMethodPackage = (activeInputMethodPackage ?? '')
      .toLowerCase();

  if (normalizedInputMethodPackage.isNotEmpty) {
    if (normalizedPackageName == normalizedInputMethodPackage) return true;
    return normalizedResourceId.startsWith('$normalizedInputMethodPackage:id/');
  }

  if (isFallbackAndroidInputMethodPackage(packageName)) return true;
  if (isFallbackAndroidInputMethodResource(resourceId)) return true;
  return false;
}

/// Check if a package name is a fallback input method.
bool isFallbackAndroidInputMethodPackage(String? packageName) {
  return _fallbackInputMethodPackages.contains(
    (packageName ?? '').toLowerCase(),
  );
}

/// Check if a resource ID is from a fallback input method.
bool isFallbackAndroidInputMethodResource(String? resourceId) {
  final normalizedResourceId = (resourceId ?? '').toLowerCase();
  for (final packageName in _fallbackInputMethodPackages) {
    if (normalizedResourceId.startsWith('$packageName:id/')) return true;
  }
  return false;
}

/// Classify the owner of input (app or IME).
AndroidInputOwner classifyAndroidInputOwner(
  String? packageName, {
  String? resourceId,
  String? activeInputMethodPackage,
}) {
  if (packageName == null && resourceId == null)
    return AndroidInputOwner.unknown;
  return isAndroidInputMethodOwned(
        packageName,
        resourceId: resourceId,
        activeInputMethodPackage: activeInputMethodPackage,
      )
      ? AndroidInputOwner.ime
      : AndroidInputOwner.app;
}
