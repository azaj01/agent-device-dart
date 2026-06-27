// Port of the content-recovery cases from
// agent-device/src/platforms/android/__tests__/snapshot.test.ts

import 'package:agent_device/src/platforms/android/snapshot_content_recovery.dart';
import 'package:agent_device/src/platforms/android/snapshot_types.dart';
import 'package:test/test.dart';

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

AndroidSnapshotBackendMetadata _meta({
  int? nodeCount,
  int? windowCount,
  bool? rootPresent,
  String? captureMode,
}) {
  return AndroidSnapshotBackendMetadata(
    backend: 'android-helper',
    captureMode: captureMode ?? 'interactive-windows',
    nodeCount: nodeCount ?? 1,
    windowCount: windowCount ?? 1,
    rootPresent: rootPresent,
  );
}

String _systemWindowOnlyXml() {
  return [
    '<?xml version="1.0" encoding="UTF-8"?>',
    '<hierarchy rotation="0">',
    '  <node window-index="0" window-type="3" window-layer="30" window-active="true" window-focused="true" class="android.widget.FrameLayout" package="com.android.systemui" bounds="[0,0][390,844]" enabled="true" visible-to-user="true">',
    '    <node content-desc="Back" class="android.widget.ImageButton" package="com.android.systemui" bounds="[0,792][96,844]" clickable="true" enabled="true" focusable="true" visible-to-user="true" />',
    '    <node content-desc="Home" class="android.widget.ImageButton" package="com.android.systemui" bounds="[147,792][243,844]" clickable="true" enabled="true" focusable="true" visible-to-user="true" />',
    '  </node>',
    '</hierarchy>',
  ].join('\n');
}

String _contentPoorFabricAppWindowXml() {
  return [
    '<?xml version="1.0" encoding="UTF-8"?>',
    '<hierarchy rotation="0">',
    '  <node window-index="0" window-type="1" window-layer="10" window-active="true" window-focused="true" class="android.widget.FrameLayout" package="io.example.fabric" bounds="[0,0][390,844]" enabled="true" visible-to-user="true">',
    '    <node index="0" class="androidx.compose.ui.platform.ComposeView" package="io.example.fabric" bounds="[0,0][390,844]" enabled="true" visible-to-user="true" />',
    '  </node>',
    '  <node window-index="1" window-type="3" window-layer="30" window-active="false" window-focused="false" class="android.widget.FrameLayout" package="com.android.systemui" bounds="[0,0][390,24]" enabled="true" visible-to-user="true">',
    '    <node content-desc="Battery" class="android.widget.ImageView" package="com.android.systemui" bounds="[340,4][370,20]" enabled="true" visible-to-user="true" />',
    '  </node>',
    '</hierarchy>',
  ].join('\n');
}

String _contentPoorExpoToolsOverlayXml() {
  return [
    '<?xml version="1.0" encoding="UTF-8"?>',
    '<hierarchy rotation="0">',
    '  <node index="0" class="android.widget.FrameLayout" package="com.android.systemui" bounds="[0,0][390,24]" enabled="true" visible-to-user="true">',
    '    <node text="7:52" resource-id="com.android.systemui:id/clock" class="android.widget.TextView" package="com.android.systemui" bounds="[12,4][54,20]" enabled="true" visible-to-user="true" />',
    '    <node content-desc="Battery 100 percent." resource-id="com.android.systemui:id/battery" class="android.widget.LinearLayout" package="com.android.systemui" bounds="[340,4][380,20]" enabled="true" visible-to-user="true" />',
    '  </node>',
    '  <node index="1" class="android.widget.FrameLayout" package="host.exp.exponent" bounds="[0,0][390,844]" enabled="true" visible-to-user="true">',
    '    <node index="0" class="androidx.compose.ui.platform.ComposeView" package="host.exp.exponent" bounds="[0,0][390,844]" enabled="true" visible-to-user="true" />',
    '    <node index="1" text="Agent Device Tester" class="android.widget.TextView" package="host.exp.exponent" bounds="[0,0][0,0]" enabled="true" visible-to-user="false" />',
    '    <node index="1" text="Tools" class="android.widget.ImageView" package="host.exp.exponent" bounds="[20,760][64,804]" enabled="true" visible-to-user="true" />',
    '  </node>',
    '</hierarchy>',
  ].join('\n');
}

String _richAppWithSystemBarXml() {
  return [
    '<?xml version="1.0" encoding="UTF-8"?>',
    '<hierarchy rotation="0">',
    '  <node window-index="0" window-type="1" window-layer="10" window-active="true" window-focused="true" class="android.widget.FrameLayout" package="io.example.fabric" bounds="[0,0][390,844]" enabled="true" visible-to-user="true">',
    '    <node text="Fabric dashboard" class="android.widget.TextView" package="io.example.fabric" bounds="[24,96][260,140]" enabled="true" visible-to-user="true" />',
    '    <node text="Open details" class="android.widget.Button" package="io.example.fabric" bounds="[24,180][220,236]" clickable="true" enabled="true" focusable="true" visible-to-user="true" />',
    '  </node>',
    '  <node window-index="1" window-type="3" window-layer="20" window-active="false" window-focused="false" class="android.widget.FrameLayout" package="com.android.systemui" bounds="[0,0][390,24]" enabled="true" visible-to-user="true">',
    '    <node content-desc="Battery" class="android.widget.ImageView" package="com.android.systemui" bounds="[340,4][370,20]" enabled="true" visible-to-user="true" />',
    '  </node>',
    '</hierarchy>',
  ].join('\n');
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  group('classifyAndroidHelperContentRecovery', () {
    test('returns null for non-helper backend', () {
      const stockMeta = AndroidSnapshotBackendMetadata(
        backend: 'uiautomator-dump',
      );
      final result = classifyAndroidHelperContentRecovery('', stockMeta);
      expect(result, isNull);
    });

    test('detects empty helper output (no nodes)', () {
      const emptyXml =
          '<?xml version="1.0" encoding="UTF-8"?><hierarchy rotation="0"></hierarchy>';
      final result = classifyAndroidHelperContentRecovery(
        emptyXml,
        _meta(nodeCount: 0),
      );
      expect(result, isNotNull);
      expect(result!.reason, equals('empty-helper-output'));
      expect(
        result.fallbackReason,
        equals('Android snapshot helper returned no accessibility nodes'),
      );
    });

    test('detects empty helper output when metadata.rootPresent is false', () {
      const xml =
          '<hierarchy><node text="ignored" bounds="[0,0][10,10]" /></hierarchy>';
      final result = classifyAndroidHelperContentRecovery(
        xml,
        _meta(rootPresent: false),
      );
      expect(result, isNotNull);
      expect(result!.reason, equals('empty-helper-output'));
    });

    test('detects system-window-only output', () {
      final result = classifyAndroidHelperContentRecovery(
        _systemWindowOnlyXml(),
        _meta(nodeCount: 3, windowCount: 1),
      );
      expect(result, isNotNull);
      expect(result!.reason, equals('system-window-only'));
      expect(
        result.fallbackReason,
        equals(
          'Android snapshot helper returned only non-application windows',
        ),
      );
    });

    test('detects content-poor foreground app window (with appBundleId)', () {
      final result = classifyAndroidHelperContentRecovery(
        _contentPoorFabricAppWindowXml(),
        _meta(nodeCount: 4, windowCount: 2),
        foregroundAppPackage: 'io.example.fabric',
      );
      expect(result, isNotNull);
      expect(result!.reason, equals('content-poor-app-window'));
      expect(
        result.fallbackReason,
        equals(
          'Android snapshot helper returned insufficient foreground app content',
        ),
      );
    });

    test(
        'detects content-poor application window (no appBundleId, has window-type=1)',
        () {
      final result = classifyAndroidHelperContentRecovery(
        _contentPoorFabricAppWindowXml(),
        _meta(nodeCount: 4, windowCount: 2),
      );
      expect(result, isNotNull);
      expect(result!.reason, equals('content-poor-app-window'));
      expect(
        result.fallbackReason,
        equals(
          'Android snapshot helper returned insufficient application window content',
        ),
      );
    });

    test(
        'detects content-poor application window (no appBundleId, no window-type, windowCount>1)',
        () {
      final result = classifyAndroidHelperContentRecovery(
        _contentPoorExpoToolsOverlayXml(),
        _meta(nodeCount: 4, windowCount: 2),
      );
      expect(result, isNotNull);
      expect(result!.reason, equals('content-poor-app-window'));
      expect(
        result.fallbackReason,
        equals(
          'Android snapshot helper returned insufficient application window content',
        ),
      );
    });

    test('returns null for healthy app + system window combo', () {
      final result = classifyAndroidHelperContentRecovery(
        _richAppWithSystemBarXml(),
        _meta(nodeCount: 4, windowCount: 2),
        foregroundAppPackage: 'io.example.fabric',
      );
      expect(result, isNull);
    });

    test('returns null for healthy app + system window without appBundleId', () {
      final result = classifyAndroidHelperContentRecovery(
        _richAppWithSystemBarXml(),
        _meta(nodeCount: 4, windowCount: 2),
      );
      expect(result, isNull);
    });

    test('diagnostics include helperNodeCount and helperWindowTypes', () {
      final result = classifyAndroidHelperContentRecovery(
        _systemWindowOnlyXml(),
        _meta(nodeCount: 3, windowCount: 1, captureMode: 'interactive-windows'),
      );
      expect(result, isNotNull);
      final diag = result!.diagnostics;
      expect(diag['helperNodeCount'], greaterThan(0));
      expect(diag['helperWindowTypes'], isA<List<int>>());
      expect(diag['helperCaptureMode'], equals('interactive-windows'));
    });

    test('diagnostics include foreground app fields when appBundleId given', () {
      final result = classifyAndroidHelperContentRecovery(
        _contentPoorFabricAppWindowXml(),
        _meta(nodeCount: 4, windowCount: 2),
        foregroundAppPackage: 'io.example.fabric',
      );
      expect(result, isNotNull);
      final diag = result!.diagnostics;
      expect(diag['helperForegroundAppPackage'], equals('io.example.fabric'));
      expect(diag.containsKey('helperForegroundAppMeaningfulNodeCount'), isTrue);
      expect(
        diag['helperForegroundAppMeaningfulNodeThreshold'],
        equals(2),
      );
    });

    test('metadata windowCount=0 does not trigger content-poor with no windows',
        () {
      // windowCount=1 but no window-type attributes in XML → windowRootCount=0
      // and windowCount=1 — should NOT trigger the windowCount>1 branch.
      const xml =
          '<hierarchy><node text="Hello" package="com.example" bounds="[0,0][100,100]" visible-to-user="true" /></hierarchy>';
      final result = classifyAndroidHelperContentRecovery(
        xml,
        _meta(nodeCount: 1, windowCount: 1),
      );
      expect(result, isNull);
    });
  });

  // ---------------------------------------------------------------------------
  // snapshotAndroid integration tests for content recovery are in
  // snapshot_content_recovery_integration_test.dart because they require a
  // mock ADB executor and artifact fixture.
  // ---------------------------------------------------------------------------
}
