/// The accuracy oracle: stable accessibility identifiers exposed by the Flutter
/// fixture app (mirrors `test_apps/agent_device_fixture_app/lib/fixture_ids.dart`)
/// plus the per-screen expectations the walkthrough asserts.
///
/// Keeping these as plain constants (rather than importing the fixture package)
/// keeps the benchmark harness dependency-free and decoupled from the app build.
library;

class Ids {
  Ids._();

  // Home
  static const homeScenarioTitle = 'fixture.home.scenario_title';
  static const homeOpenFormLab = 'fixture.home.open_form_lab_button';
  static const homeOpenCatalog = 'fixture.home.open_catalog_button';
  static const homeOpenStateLab = 'fixture.home.open_state_lab_button';
  static const homeOpenDiagnostics = 'fixture.home.open_diagnostics_button';
  static const homeOpenGestureLab = 'fixture.home.open_gesture_lab_button';

  // Form Lab
  static const formName = 'fixture.form.profile_name_field';
  static const formEmail = 'fixture.form.email_address_field';
  static const formAcceptTerms = 'fixture.form.accept_test_terms_checkbox';
  static const formSubmit = 'fixture.form.submit_profile_button';
  static const formSummary = 'fixture.form.submission_summary_text';

  // Catalog
  static const catalogFilter = 'fixture.catalog.filter_tasks_field';
  static const catalogUrgentToggle = 'fixture.catalog.show_urgent_only_toggle';
  static const catalogVisibleCount = 'fixture.catalog.visible_tasks_text';
  static const catalogTaskReleaseChecklist = 'fixture.catalog.task.release_checklist';
  static const catalogTaskOfflineMode = 'fixture.catalog.task.offline_mode';
  static const catalogTaskCrashRecovery = 'fixture.catalog.task.crash_recovery';
  static const taskDetailComplete = 'fixture.task_detail.mark_scenario_complete_toggle';
  static const taskDetailStatus = 'fixture.task_detail.status_text';

  // State Lab
  static const stateBatchCount = 'fixture.state.batch_count_text';
  static const stateIncrease = 'fixture.state.increase_batch_button';
  static const stateDecrease = 'fixture.state.decrease_batch_button';
  static const stateReset = 'fixture.state.reset_batch_button';

  // Diagnostics
  static const diagPermissionBanner = 'fixture.diagnostics.permission_banner';
  static const diagShowBannerToggle = 'fixture.diagnostics.show_permission_banner_toggle';

  // Gesture Lab
  static const gestureScale = 'fixture.gesture.scale_text';
  static const gesturePan = 'fixture.gesture.pan_position_text';
  static const gestureFlingStatus = 'fixture.gesture.fling_status_text';
  static const gesturePinchTarget = 'fixture.gesture.pinch_target';
  static const gesturePanTarget = 'fixture.gesture.pan_target';
  static const gestureFlingTarget = 'fixture.gesture.fling_target';

  // Animation Lab (non-quiescent UI: infinite animation + delayed transition)
  static const homeOpenAnimationLab = 'fixture.home.open_animation_lab_button';
  static const animationInfiniteSpinner = 'fixture.animation.infinite_spinner';
  static const animationSpinnerState = 'fixture.animation.spinner_state_text';
  static const animationToggleSpinner =
      'fixture.animation.toggle_spinner_button';
  static const animationTick = 'fixture.animation.tick_text';
  static const animationStartTransition =
      'fixture.animation.start_transition_button';
  static const animationTransitionStatus =
      'fixture.animation.transition_status_text';
  static const animationRevealed = 'fixture.animation.revealed_text';
}

/// Per-platform bundle / package identifier of the fixture app.
String fixtureAppId(String platform) =>
    platform == 'ios' ? 'com.example.agentDeviceFixtureApp' : 'com.example.agent_device_fixture_app';

/// Identifiers expected above the fold on Home — the resolution baseline.
/// (Gesture Lab's launch card sits below the fold and gestures have divergent
/// contracts, so it is covered in the feature matrix rather than here.)
const homeIds = <String>[
  Ids.homeScenarioTitle,
  Ids.homeOpenFormLab,
  Ids.homeOpenCatalog,
  Ids.homeOpenStateLab,
  Ids.homeOpenDiagnostics,
];
