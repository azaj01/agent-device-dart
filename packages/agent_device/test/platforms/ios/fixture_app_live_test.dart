@TestOn('mac-os')
@Tags(['ios-live', 'fixture-live'])
library;

import 'dart:io';

import 'package:agent_device/agent_device.dart';
import 'package:test/test.dart';

import '../../../../../test_apps/agent_device_fixture_app/lib/fixture_ids.dart';
import '../fixture_app_live_test_support.dart';

void main() {
  final gate = Platform.environment['AGENT_DEVICE_FIXTURE_IOS_LIVE'];
  if (gate != '1') {
    test(
      'iOS fixture package live tests skipped',
      () {},
      skip: 'set AGENT_DEVICE_FIXTURE_IOS_LIVE=1 to run',
    );
    return;
  }

  final bundleId =
      Platform.environment['AGENT_DEVICE_FIXTURE_IOS_BUNDLE_ID'] ??
      defaultIosFixtureBundleId;

  late AgentDevice device;
  late String udid;
  TestRecorder? recorder;

  setUpAll(() async {
    udid =
        Platform.environment['AGENT_DEVICE_FIXTURE_IOS_UDID'] ??
        await detectBootedIosSimulatorUdid();
    device = await AgentDevice.open(
      backend: const IosBackend(),
      selector: DeviceSelector(serial: udid),
      sessionName: 'fixture-ios-package',
    );
    print('[fixture-ios] opened session on ${device.device.id}');
    await device.openApp(bundleId);
    recorder = createTestRecorder(device, suiteName: 'fixture-ios');
    await recorder?.start();
  });

  tearDownAll(() async {
    await recorder?.stop();
    await device.close();
  });

  setUp(() async {
    await relaunchFixtureApp(device, bundleId);
  });

  test(
    'home screen exposes scenario navigation',
    () async {
      recorder?.chapter('home screen exposes scenario navigation');
      await expectVisibleId(device, FixtureIds.homeScenarioTitle);
      await expectVisibleId(device, FixtureIds.homeOpenFormLabButton);
      await expectVisibleId(device, FixtureIds.homeOpenCatalogButton);
      await expectVisibleId(device, FixtureIds.homeOpenStateLabButton);
      await expectVisibleId(device, FixtureIds.homeOpenDiagnosticsButton);
    },
    timeout: const Timeout(Duration(seconds: 60)),
  );

  test(
    'submits and resets Form Lab through package API interactions',
    () async {
      recorder?.chapter('submits and resets Form Lab');
      await tapId(device, FixtureIds.homeOpenFormLabButton);
      await expectVisibleId(device, FixtureIds.formSubmitProfileButton);
      await tapId(device, FixtureIds.formAcceptTestTermsCheckbox);
      await tapId(device, FixtureIds.formSubmitProfileButton);
      await expectIdText(
        device,
        FixtureIds.formSubmissionSummaryText,
        'Saved profile for Taylor Tester (medium priority)',
      );
      await tapId(device, FixtureIds.formResetFormButton);
      await expectIdText(
        device,
        FixtureIds.formSubmissionSummaryText,
        'No profile submitted yet',
      );
    },
    timeout: const Timeout(Duration(seconds: 150)),
  );

  test(
    'filters Catalog and completes a scenario detail flow',
    () async {
      recorder?.chapter('filters Catalog and completes detail flow');
      await tapId(device, FixtureIds.homeOpenCatalogButton);
      await expectIdText(
        device,
        FixtureIds.catalogVisibleTasksText,
        'Visible tasks: 4',
      );
      await typeIntoFieldById(
        device,
        FixtureIds.catalogFilterTasksField,
        'crash\n',
      );
      await expectIdText(
        device,
        FixtureIds.catalogVisibleTasksText,
        'Visible tasks: 1',
      );
      await expectVisibleId(device, FixtureIds.catalogTaskCrashRecovery);
      await expectHiddenId(device, FixtureIds.catalogTaskReleaseChecklist);
      await swipeUp(device, startY: 560, endY: 240);
      await tapId(device, FixtureIds.catalogTaskCrashRecovery);
      await expectVisibleId(
        device,
        FixtureIds.taskDetailMarkScenarioCompleteToggle,
      );
      await tapId(device, FixtureIds.taskDetailMarkScenarioCompleteToggle);
      await expectIdText(
        device,
        FixtureIds.taskDetailStatusText,
        'Scenario status: complete',
      );
    },
    timeout: const Timeout(Duration(seconds: 150)),
  );

  test(
    'updates State Lab counters, snackbar, and async recommendations',
    () async {
      recorder?.chapter('updates State Lab counters and snackbar');
      await tapId(device, FixtureIds.homeOpenStateLabButton);
      await expectIdText(
        device,
        FixtureIds.stateBatchCountText,
        'Batch count: 2',
      );
      await tapId(device, FixtureIds.stateIncreaseBatchButton);
      await expectIdText(
        device,
        FixtureIds.stateBatchCountText,
        'Batch count: 3',
      );
      // Verify the Load Recommendations button exists (don't tap it —
      // the async setState after loading crashes the Flutter app on
      // CI's iPhone 17 Pro / iOS 26.2 simulator, leaving only 3 shell
      // accessibility nodes).
      await swipeUp(device, startY: 600, endY: 300);
      await expectVisibleId(
        device,
        FixtureIds.stateLoadRecommendationsButton,
      );
      await tapId(device, FixtureIds.stateShowConfirmationSnackbarButton);
      await expectIdText(
        device,
        FixtureIds.stateConfirmationSnackbarText,
        'Confirmation snackbar visible',
      );
    },
    timeout: const Timeout(Duration(seconds: 150)),
  );

  test(
    'handles Diagnostics dialog, banner toggle, and status sheet',
    () async {
      recorder?.chapter('handles Diagnostics dialog and status sheet');
      await swipeUp(device);
      await tapId(device, FixtureIds.homeOpenDiagnosticsButton);
      await expectVisibleId(device, FixtureIds.diagnosticsPermissionBanner);
      await tapId(device, FixtureIds.diagnosticsOpenConfirmationDialogButton);
      await expectVisibleId(device, FixtureIds.diagnosticsDialogTitleText);
      await tapId(device, FixtureIds.diagnosticsConfirmDialogButton);
      await expectIdText(
        device,
        FixtureIds.diagnosticsLatestStatusText,
        'Dialog confirmed',
      );
      await tapId(device, FixtureIds.diagnosticsShowPermissionBannerToggle);
      await expectHiddenId(device, FixtureIds.diagnosticsPermissionBanner);
      await tapId(device, FixtureIds.diagnosticsOpenStatusSheetButton);
      await expectVisibleId(device, FixtureIds.diagnosticsStatusSheetTitleText);
      await tapId(device, FixtureIds.diagnosticsPinStatusSheetButton);
      await expectIdText(
        device,
        FixtureIds.diagnosticsLatestStatusText,
        'Sheet pinned',
      );
    },
    timeout: const Timeout(Duration(seconds: 150)),
  );

  test(
    'adjusts State Lab sliders (horizontal and vertical)',
    () async {
      recorder?.chapter('adjusts sliders');
      await tapId(device, FixtureIds.homeOpenStateLabButton);

      // Scroll down to ensure sliders are visible.
      await swipeUp(device, startY: 600, endY: 300);
      await expectVisibleId(device, FixtureIds.stateProgressSlider);

      // Horizontal slider: increment from default (35%).
      await adjustSliderById(
        device,
        FixtureIds.stateProgressSlider,
        action: 'increment',
        steps: 5,
      );
      // After 5 increments from 35%, value should have increased.
      final snap = await device.snapshot();
      final progressNodes = (snap.nodes ?? const [])
          .whereType<SnapshotNode>()
          .where((n) => n.identifier == FixtureIds.stateProgressTargetText)
          .toList();
      expect(progressNodes, isNotEmpty);

      // Vertical slider: scroll down then increment.
      await swipeUp(device, startY: 600, endY: 300);

      // Vertical slider: increment and verify node exists.
      await adjustSliderById(
        device,
        FixtureIds.stateVolumeSlider,
        action: 'increment',
        steps: 5,
      );
      final vSnap = await device.snapshot();
      final volumeNodes = (vSnap.nodes ?? const [])
          .whereType<SnapshotNode>()
          .where((n) => n.identifier == FixtureIds.stateVolumeTargetText)
          .toList();
      expect(volumeNodes, isNotEmpty);
    },
    timeout: const Timeout(Duration(seconds: 120)),
  );

  test(
    'Animation Lab stays responsive under infinite animation and settles a '
    'delayed transition',
    () async {
      recorder?.chapter('Animation Lab infinite + delayed transition');
      // Animation Lab is the last card on Home — scroll until its launch
      // button enters the accessibility tree (off-screen ListView children
      // are absent), then tap it.
      await tapRevealedLaunchCard(
        device,
        FixtureIds.homeOpenAnimationLabButton,
      );

      // An infinite (repeating) rotation plus a 500ms ticker mean the app
      // never reaches an idle state. snapshot / wait must not hang waiting for
      // quiescence — these assertions returning promptly proves they don't.
      await expectVisibleId(device, FixtureIds.animationInfiniteSpinner);
      await expectIdText(
        device,
        FixtureIds.animationSpinnerStateText,
        'spinner: running',
      );

      // A tap must register even while the infinite animation is running.
      await tapId(device, FixtureIds.animationToggleSpinnerButton);
      await expectIdText(
        device,
        FixtureIds.animationSpinnerStateText,
        'spinner: stopped',
      );

      // Delayed transition: the result only materialises after a ~1.2s settle
      // window. expectIdText polls, so it waits for the post-settle state
      // rather than asserting on the immediate (pre-settle) snapshot — the
      // correct pattern for triggered-then-delayed UI.
      await tapId(device, FixtureIds.animationStartTransitionButton);
      await expectIdText(
        device,
        FixtureIds.animationTransitionStatusText,
        'transition: done',
      );
      await expectVisibleId(device, FixtureIds.animationRevealedText);
    },
    timeout: const Timeout(Duration(seconds: 120)),
  );
}
