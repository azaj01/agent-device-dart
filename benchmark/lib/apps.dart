import 'driver.dart';
import 'oracle.dart';
import 'snapshot.dart';

/// A benchmark target app: its per-platform bundle id, a stable on-screen
/// element to use for the perf-suite tap, and a deterministic accuracy
/// walkthrough exercising navigation, text input, button sequences, toggles,
/// and observable state transitions.
abstract class BenchApp {
  String get name;
  String bundleId(String platform);

  /// An element reliably on the first screen, used as the perf-suite tap target.
  String get pressTargetId;

  Future<void> walkthrough(Driver d);
}

BenchApp appByName(String n) => switch (n) {
      'test-app' => ExpoTestApp(),
      _ => FlutterFixtureApp(),
    };

// ---------------------------------------------------------------------------
// Flutter fixture (test_apps/agent_device_fixture_app)
// ---------------------------------------------------------------------------

class FlutterFixtureApp extends BenchApp {
  @override
  String get name => 'flutter-fixture';

  @override
  String bundleId(String platform) => fixtureAppId(platform);

  @override
  String get pressTargetId => Ids.homeScenarioTitle;

  @override
  Future<void> walkthrough(Driver d) async {
    final app = bundleId(d.t.platform);

    // --- Home: resolution baseline ---
    await d.relaunch(app);
    var snap = await d.snap();
    for (final id in homeIds) {
      d.check('home: $id resolves', hasId(snap, id), 'Home snapshot should expose $id');
    }

    // --- Catalog: search text input with an observable filter effect ---
    await d.relaunch(app);
    await d.tapId(Ids.homeOpenCatalog);
    snap = await d.snap();
    d.check(
      'catalog: list resolves',
      hasId(snap, Ids.catalogFilter) && hasId(snap, Ids.catalogVisibleCount),
      'Catalog should expose the filter field and visible-count text',
    );
    final beforeCount = firstInt(textOfId(snap, Ids.catalogVisibleCount));
    await d.typeInto(Ids.catalogFilter, 'offline');
    snap = await d.snap();
    final afterCount = firstInt(textOfId(snap, Ids.catalogVisibleCount));
    d.check(
      'catalog: search filters list',
      afterCount == 1 && hasId(snap, Ids.catalogTaskOfflineMode) && !hasId(snap, Ids.catalogTaskReleaseChecklist),
      'Typing "offline" should leave only the Offline Mode task '
          '(before=$beforeCount, after=$afterCount)',
    );

    // --- Catalog: urgent-only toggle changes the visible set ---
    await d.relaunch(app);
    await d.tapId(Ids.homeOpenCatalog);
    await d.tapId(Ids.catalogUrgentToggle);
    snap = await d.snap();
    d.check(
      'catalog: urgent toggle filters list',
      firstInt(textOfId(snap, Ids.catalogVisibleCount)) == 2,
      'Urgent-only should show 2 tasks (got ${textOfId(snap, Ids.catalogVisibleCount)})',
    );

    // --- Catalog detail: drill-in + toggle complete ---
    await d.relaunch(app);
    await d.tapId(Ids.homeOpenCatalog);
    var detailOpened = false;
    for (var attempt = 0; attempt < 2 && !detailOpened; attempt++) {
      await d.tapId(Ids.catalogTaskReleaseChecklist);
      snap = await d.snap();
      detailOpened = hasId(snap, Ids.taskDetailComplete);
    }
    d.check('catalog: detail navigation works', detailOpened, 'Tapping a task should open its detail screen');
    if (detailOpened) {
      await d.tapId(Ids.taskDetailComplete);
      snap = await d.snap();
      d.check(
        'catalog: mark-complete updates status',
        hasId(snap, Ids.taskDetailStatus),
        'Toggling complete should surface the status text',
      );
    }

    // --- Form: field resolution + value extraction ---
    await d.relaunch(app);
    await d.tapId(Ids.homeOpenFormLab);
    snap = await d.snap();
    d.check(
      'form: fields resolve',
      hasId(snap, Ids.formName) && hasId(snap, Ids.formEmail),
      'Form should expose name and email fields',
    );
    d.check(
      'form: field value extracted',
      (textOfId(snap, Ids.formName) ?? '').contains('Taylor Tester'),
      'The prefilled profile-name value should be readable from the snapshot',
    );

    // --- State Lab: multi-button counter sequence + reset ---
    await d.relaunch(app);
    await d.tapId(Ids.homeOpenStateLab);
    snap = await d.snap();
    d.check(
      'state: controls resolve',
      hasId(snap, Ids.stateBatchCount) && hasId(snap, Ids.stateIncrease),
      'State Lab should expose the batch count and increase button',
    );
    final start = firstInt(textOfId(snap, Ids.stateBatchCount));
    await d.tapId(Ids.stateIncrease);
    await d.tapId(Ids.stateIncrease);
    await d.tapId(Ids.stateIncrease);
    await d.tapId(Ids.stateDecrease);
    snap = await d.snap();
    final net = firstInt(textOfId(snap, Ids.stateBatchCount));
    d.check(
      'state: +3/-1 nets +2',
      start != null && net != null && net == start + 2,
      'Three increments and one decrement should net +2 (start=$start, net=$net)',
    );
    await d.tapId(Ids.stateReset);
    snap = await d.snap();
    final afterReset = firstInt(textOfId(snap, Ids.stateBatchCount));
    d.check(
      'state: reset zeroes counter',
      afterReset == 0,
      'Reset should return the counter to 0 (afterReset=$afterReset)',
    );
  }
}

// ---------------------------------------------------------------------------
// Expo / React Native fixture (agent-device/examples/test-app)
// ---------------------------------------------------------------------------

/// testIDs surface as the accessibility `identifier` agent-device reports.
class T {
  T._();
  static const homeTitle = 'home-title';
  static const releaseNotice = 'release-notice';

  // Native bottom-tab labels (the tabs carry no testID).
  static const tabHome = 'Home';
  static const tabCatalog = 'Catalog';
  static const tabForm = 'Form';
  static const tabSettings = 'Settings';

  static const catalogTitle = 'catalog-title';
  static const catalogSearch = 'catalog-search';
  static const productCitrus = 'product-card-citrus-kit';

  static const formTitle = 'form-title';
  static const fieldName = 'field-name';
  static const fieldEmail = 'field-email';
  static const checkboxAgree = 'checkbox-agree';
  static const submitOrder = 'submit-order';
  static const formSuccess = 'form-success';
  static const formErrors = 'form-errors';

  static const settingsTitle = 'settings-title';
  static const toggleNotifications = 'toggle-notifications';
  static const loadDiagnostics = 'load-diagnostics';
  static const diagnosticsReady = 'diagnostics-ready';
  static const diagnosticsError = 'diagnostics-error';
}

class ExpoTestApp extends BenchApp {
  @override
  String get name => 'expo-test-app';

  @override
  String bundleId(String platform) => 'com.callstack.agentdevicelab';

  @override
  String get pressTargetId => T.homeTitle;

  @override
  Future<void> walkthrough(Driver d) async {
    final app = bundleId(d.t.platform);

    // --- Home: resolution baseline ---
    // The app restores the last-used tab across relaunches, so explicitly
    // select the Home tab rather than assuming a fresh launch lands there.
    await d.relaunch(app);
    await d.tapLabel(T.tabHome);
    var snap = await d.snap();
    d.check('home: home-title resolves', hasId(snap, T.homeTitle), 'Home should expose home-title');
    d.check('home: release-notice resolves', hasId(snap, T.releaseNotice), 'Home should expose the release notice');

    // --- Catalog: search text input with an observable filter effect ---
    await d.relaunch(app);
    await d.tapLabel(T.tabCatalog);
    snap = await d.snap();
    d.check(
      'catalog: resolves',
      hasId(snap, T.catalogTitle) && hasId(snap, T.catalogSearch),
      'Catalog should expose its title and search field',
    );
    await d.typeInto(T.catalogSearch, 'citrus');
    snap = await d.snap();
    final searchVal = textOfId(snap, T.catalogSearch) ?? '';
    d.check(
      'catalog: search accepts text input',
      searchVal.isNotEmpty,
      'Typing into the search field should populate it (value="$searchVal")',
    );

    // --- Form: multi-field text input + checkbox toggle ---
    await d.relaunch(app);
    await d.tapLabel(T.tabForm);
    snap = await d.snap();
    d.check(
      'form: fields resolve',
      hasId(snap, T.fieldName) && hasId(snap, T.fieldEmail),
      'Form should expose name and email fields',
    );
    await d.typeInto(T.fieldName, 'Ada');
    await d.typeInto(T.fieldEmail, 'ada@example.com');
    snap = await d.snap();
    // agent-device `type` can drop characters, so assert the fields became
    // non-empty (text entry registered) rather than an exact match.
    final nameVal = textOfId(snap, T.fieldName) ?? '';
    final emailVal = textOfId(snap, T.fieldEmail) ?? '';
    d.check(
      'form: text input registered',
      nameVal.isNotEmpty && emailVal.contains('@'),
      'Typed text should populate the fields (name="$nameVal", email="$emailVal")',
    );

    // --- Form: scroll a below-fold control (submit button) into view. This
    // exercises `scroll` on a long RN screen — a real divergence surfaces here:
    // the Dart port scrolls the RN ScrollView, npm's `scroll` no-ops on it.
    await d.relaunch(app);
    await d.tapLabel(T.tabForm);
    final revealed = await d.revealId(T.submitOrder);
    d.check(
      'form: scroll reveals below-fold submit button',
      revealed,
      '`scroll` should bring the off-screen submit button into view',
    );

    // --- Settings: async diagnostics load -> ready/error ---
    await d.relaunch(app);
    await d.tapLabel(T.tabSettings);
    snap = await d.snap();
    d.check(
      'settings: resolves',
      hasId(snap, T.settingsTitle) && hasId(snap, T.toggleNotifications),
      'Settings should expose its title and a notifications toggle',
    );
    await d.tapIdScrolling(T.loadDiagnostics);
    var settled = false;
    for (var i = 0; i < 8 && !settled; i++) {
      snap = await d.snap();
      settled = hasId(snap, T.diagnosticsReady) || hasId(snap, T.diagnosticsError);
      if (!settled) await Future<void>.delayed(const Duration(milliseconds: 500));
    }
    d.check('settings: diagnostics load resolves', settled, 'Loading diagnostics should reach a ready/error state');
  }
}
