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

    // --- Multi-page navigation with confirmations, including back. Each hop
    // asserts the destination appeared AND the previous screen is gone, so a
    // missed tap can't pass as a successful navigation. Back uses the nav-bar
    // "Back" button on iOS (the runner has no in-app back for Flutter routes)
    // and the hardware back on Android, via Driver.goBack(). ---
    await d.relaunch(app);
    await d.tapId(Ids.homeOpenCatalog);
    snap = await d.snap();
    d.check(
      'nav: Home→Catalog confirmed',
      hasId(snap, Ids.catalogFilter) && !hasId(snap, Ids.homeScenarioTitle),
      'Catalog should appear and Home should be gone',
    );
    var navDetailOpened = false;
    for (var attempt = 0; attempt < 2 && !navDetailOpened; attempt++) {
      await d.tapId(Ids.catalogTaskReleaseChecklist);
      snap = await d.snap();
      navDetailOpened = hasId(snap, Ids.taskDetailComplete);
    }
    d.check(
      'nav: Catalog→Detail confirmed',
      navDetailOpened && !hasId(snap, Ids.catalogFilter),
      'Task detail should appear and the catalog list should be gone',
    );
    await d.goBack();
    snap = await d.snap();
    d.check(
      'nav: Detail→Catalog (back) confirmed',
      hasId(snap, Ids.catalogFilter) && !hasId(snap, Ids.taskDetailComplete),
      'Back should return to the catalog list',
    );
    await d.goBack();
    snap = await d.snap();
    d.check(
      'nav: Catalog→Home (back) confirmed',
      hasId(snap, Ids.homeScenarioTitle) && !hasId(snap, Ids.catalogFilter),
      'Back should return to Home',
    );

    // --- diff: `diff snapshot` against the session baseline after a mutation.
    // A genuine divergence — npm supports snapshot diffing, the Dart port does
    // not yet, so this passes on npm and fails on Dart. ---
    await d.relaunch(app);
    await d.tapId(Ids.homeOpenStateLab);
    await d.snap(); // establish a snapshot baseline for the session
    await d.tapId(Ids.stateIncrease); // mutate
    final diff = await d.t.run(['diff', 'snapshot']);
    d.check('diff: snapshot diff supported', diff.ok,
        'diff snapshot should report what changed (npm); Dart lacks the command');

    // --- Animation Lab: non-quiescent UI. An infinite (repeating) rotation
    // plus a 500ms ticker mean the app never reaches idle; a separate button
    // triggers a result that only appears after a ~1.2s settle window. This
    // checks three things head-to-head: snapshots stay responsive while the
    // app never idles, a tap registers mid-animation, and a triggered-then-
    // delayed result is observed only after waiting (not on the immediate,
    // pre-settle snapshot). The launch card sits below the fold, so reach it
    // by scrolling. ---
    await d.relaunch(app);
    final animReached = await d.tapIdScrolling(Ids.homeOpenAnimationLab);
    snap = await d.snap();
    d.check(
      'animation: lab opens and snapshot is responsive under infinite animation',
      animReached &&
          hasId(snap, Ids.animationInfiniteSpinner) &&
          (textOfId(snap, Ids.animationSpinnerState) ?? '').contains('running'),
      'Animation Lab should open and report "spinner: running" — snapshot must '
          'not hang on quiescence while the app animates forever',
    );
    // A tap must register even while the infinite animation is running.
    await d.tapId(Ids.animationToggleSpinner);
    snap = await d.snap();
    d.check(
      'animation: tap registers mid-animation',
      (textOfId(snap, Ids.animationSpinnerState) ?? '').contains('stopped'),
      'Toggling should stop the spinner while it is animating '
          '(got "${textOfId(snap, Ids.animationSpinnerState)}")',
    );
    // Delayed transition: the result only materialises after a settle window.
    // We must wait before asserting — an immediate snapshot would see the
    // pre-settle ("running") state.
    await d.tapId(Ids.animationStartTransition);
    await Future<void>.delayed(const Duration(milliseconds: 1500));
    snap = await d.snap();
    d.check(
      'animation: delayed transition settles after a wait',
      (textOfId(snap, Ids.animationTransitionStatus) ?? '').contains('done') &&
          hasId(snap, Ids.animationRevealed),
      'After ~1.2s the transition should read "done" and reveal its result '
          '(got "${textOfId(snap, Ids.animationTransitionStatus)}")',
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
  static const detailsCitrus = 'details-citrus-kit';

  static const productTitle = 'product-title';
  static const productBack = 'product-back';

  static const homeOpenModal = 'home-open-modal';

  // Gesture lab (embedded on the Home screen).
  static const gestureTarget = 'gesture-target';
  static const gestureChangeStatus = 'gesture-change-status';
  static const gestureTransformStatus = 'gesture-transform-status';
  static const gestureFlingStatus = 'gesture-fling-status';

  // Product detail (numeric quantity stepper) + catalog long list.
  static const quantityIncrease = 'quantity-increase';
  static const quantityDecrease = 'quantity-decrease';
  static const quantityValue = 'quantity-value';
  static const catalogFooter = 'catalog-footer';

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

    // --- Multi-page navigation, confirming each transition (destination
    // present AND previous screen gone). Exercises tab nav, drill-in to a
    // product detail, and an in-app back button across six hops. ---
    await d.relaunch(app);
    await d.tapLabel(T.tabHome);

    Future<void> hop(String name, Future<void> Function() act, String to, String from) async {
      await act();
      final s = await d.snap();
      d.check('nav: $name confirmed', hasId(s, to) && !hasId(s, from),
          '$to should appear and $from should be gone');
    }

    await hop('Home→Catalog', () => d.tapLabel(T.tabCatalog), T.catalogTitle, T.homeTitle);
    await hop('Catalog→Product', () => d.tapIdScrolling(T.detailsCitrus), T.productTitle, T.catalogTitle);
    await hop('Product→Catalog (back)', () => d.tapIdScrolling(T.productBack), T.catalogTitle, T.productTitle);
    await hop('Catalog→Form', () => d.tapLabel(T.tabForm), T.formTitle, T.catalogTitle);
    await hop('Form→Settings', () => d.tapLabel(T.tabSettings), T.settingsTitle, T.formTitle);
    await hop('Settings→Home', () => d.tapLabel(T.tabHome), T.homeTitle, T.settingsTitle);

    // --- Multi-touch gestures on the Home gesture lab (mirrors the upstream
    // gesture-lab replay). pan/rotate/fling are real multi-finger syntheses and
    // register; pinch is omitted because the shared runner fakes it with a
    // single-finger "map zoom" drag that react-native-gesture-handler ignores
    // (a runner limitation, not a CLI difference). ---
    await d.relaunch(app);
    await d.tapLabel(T.tabHome);
    final g = await d.centerArgs(T.gestureTarget);
    if (g == null) {
      d.check('gesture: target present', false, 'gesture-target should be on Home');
    } else {
      // pan (positive offsets — the Dart CLI parses a negative positional as a
      // flag, so panning right/down is the portable direction).
      await d.gesture(['pan', ...g, '120', '0']);
      final transform = textOfId(await d.snap(), T.gestureTransformStatus) ?? '';
      d.check('gesture: pan moves target', transform.contains('x ') && !transform.contains('x 0,'),
          'Pan should change the x offset (got "$transform")');

      await d.gesture(['rotate', '40', ...g]);
      final afterRotate = textOfId(await d.snap(), T.gestureChangeStatus) ?? '';
      d.check('gesture: rotate registers', afterRotate.contains('rotate changed yes'),
          'Rotate should set rotate-changed (got "$afterRotate")');

      final beforeFling = firstInt(textOfId(await d.snap(), T.gestureFlingStatus));
      await d.gesture(['fling', 'left', ...g, '180']);
      final afterFling = firstInt(textOfId(await d.snap(), T.gestureFlingStatus));
      d.check('gesture: fling registers',
          afterFling != null && (beforeFling == null || afterFling > beforeFling),
          'Fling should increment the fling counter (before=$beforeFling, after=$afterFling)');
    }

    // --- Numeric state: product-detail quantity stepper (+2/−1 nets +1). ---
    await d.relaunch(app);
    await d.openTab(T.tabCatalog, T.catalogTitle);
    await d.tapIdScrolling(T.detailsCitrus);
    await d.revealId(T.quantityValue); // let the detail render before reading
    final qStart = firstInt(textOfId(await d.snap(), T.quantityValue));
    await d.tapIdScrolling(T.quantityIncrease);
    await d.tapIdScrolling(T.quantityIncrease);
    await d.tapIdScrolling(T.quantityDecrease);
    final qEnd = firstInt(textOfId(await d.snap(), T.quantityValue));
    d.check('numeric: quantity stepper +2/−1', qStart != null && qEnd != null && qEnd == qStart + 1,
        'Quantity should net +1 (start=$qStart, end=$qEnd)');

    // --- Long list: scroll the long catalog and confirm it actually moved.
    // (The catalog footer sits ~4000px down.) Surfaces the same RN divergence
    // as the form: the Dart port scrolls the list, npm's `scroll` no-ops. ---
    await d.relaunch(app);
    await d.openTab(T.tabCatalog, T.catalogTitle);
    double? footerY(Map<String, dynamic>? s) {
      final r = nodeById(s, T.catalogFooter)?['rect'];
      return (r is Map && r['y'] is num) ? (r['y'] as num).toDouble() : null;
    }
    final y0 = footerY(await d.snap());
    await d.t.run(['scroll', 'up', '400']);
    await Future<void>.delayed(const Duration(milliseconds: 600));
    final y1 = footerY(await d.snap());
    d.check('longlist: scroll moves the long list', y0 != null && y1 != null && y1 < y0 - 50,
        'Scrolling should move the long catalog (footer y $y0 → $y1)');

    // --- wait: the `wait` command for an async result. A genuine interface
    // divergence: npm is `wait <text> [timeoutMs]`, the Dart port is
    // `wait <predicate> <selector> --timeout`, so this npm-grammar call passes
    // on npm and fails on Dart. ---
    await d.relaunch(app);
    await d.tapLabel(T.tabSettings);
    await d.tapIdScrolling(T.loadDiagnostics);
    final waited = (await d.t.run(['wait', 'Retry diagnostics', '8000'])).ok;
    d.check('wait: text-wait command (npm grammar)', waited,
        'wait <text> <timeout> blocks until the async result (npm); Dart uses a different wait grammar');

    // Note: a behavioural native-alert check (home-open-modal → dismiss) is not
    // included — the native iOS alert isn't in the app snapshot (so it can't be
    // tapped by coordinate), Dart has no `alert` command, and npm's `alert`
    // rejects the benchmark's --udid selector. The `alert` capability gap is
    // captured in the feature-parity matrix instead.
  }
}
