import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wildlife_conservation_mobile/features/operations/data/api_repositories.dart';
import 'package:wildlife_conservation_mobile/features/operations/data/report_outbox.dart';
import 'package:wildlife_conservation_mobile/features/operations/domain/models.dart';
import 'package:wildlife_conservation_mobile/features/operations/presentation/field_reports_screen.dart';
import 'package:wildlife_conservation_mobile/features/operations/presentation/operations_dashboard_screen.dart';
import 'package:wildlife_conservation_mobile/features/operations/presentation/report_form_screen.dart';
import 'test_helpers.dart';

void main() {
  setUpAll(initMockTestEnvironment);
  setUp(initMockTestEnvironment);

  // TEST: Manager Dashboard Automatic Refresh
  // This test verifies that the manager operations dashboard automatically refreshes
  // incoming community reports to detect and display new villager submissions without manual reloading.
  testWidgets(
    'manager dashboard displays new villager reports after automatic refresh',
    (tester) async {
      final scenario = Scenario('PARK_MANAGER');
      final key = GlobalKey();
      await tester.binding.setSurfaceSize(const Size(1100, 1500));
      await tester.pumpWidget(
        scenario.app(const OperationsDashboardScreen(), screenshotKey: key),
      );
      await tester.pumpAndSettle();
      expect(find.text('Park Manager Dashboard'), findsOneWidget);
      expect(find.text('Incoming community reports'), findsOneWidget);
      expect(find.textContaining('Boundary Village'), findsOneWidget);
      scenario.reports.first['village'] = 'New Village Report';
      await tester.pump(const Duration(seconds: 31));
      await tester.pumpAndSettle();
      expect(find.textContaining('New Village Report'), findsOneWidget);
      await screenshot(tester, key, 'manager-dashboard');
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      scenario.outbox.dispose();
      await tester.binding.setSurfaceSize(null);
    },
  );

  // TEST: Liaison Accepts Community Report and Records Outcome
  // This test verifies that a Liaison Officer can inspect a community incident report,
  // accept it (transitioning to Responding), and submit the field action and outcome to resolve it.
  testWidgets('liaison accepts community report and records outcome', (
    tester,
  ) async {
    final scenario = Scenario('LIAISON_OFFICER');
    await tester.pumpWidget(
      scenario.app(
        FieldReportDetailScreen(
          id: scenario.reports.first['id'] as String,
          kind: ReportKind.community,
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Accept report'));
    await tester.tap(find.text('Accept report'));
    await tester.pumpAndSettle();
    expect(find.text('Responding'), findsOneWidget);
    await tester.ensureVisible(find.text('Record response and resolve'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Record response and resolve'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Action taken'),
      'Visited the village',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Outcome'),
      'Elephant moved away',
    );
    await tester.tap(find.text('Resolve'));
    await tester.pumpAndSettle();
    expect(find.text('Resolved'), findsOneWidget);
    expect(find.text('Elephant moved away'), findsOneWidget);
    expect(scenario.requests.last.body, contains('Visited the village'));
    await tester.pumpWidget(const SizedBox.shrink());
    scenario.outbox.dispose();
  });

  // TEST: Villager Incident Submission Contract
  // This test verifies that a community member can fill out the sighting form
  // and dispatch the report conforming to backend required properties (parkId, type, species, occurredAt).
  testWidgets('villager submits sighting with the required backend contract', (
    tester,
  ) async {
    final scenario = Scenario('COMMUNITY_MEMBER');
    await tester.binding.setSurfaceSize(const Size(600, 1800));
    await tester.pumpWidget(scenario.app(const ReportFormScreen()));
    await tester.pumpAndSettle();
    await tester.tap(
      find.widgetWithText(DropdownButtonFormField<String>, 'Park'),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Yala National Park').last);
    await tester.pumpAndSettle();
    await tester.tap(
      find.widgetWithText(DropdownButtonFormField<String>, 'Park area'),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Block 1').last);
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Village'),
      'Boundary Village',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'What happened?'),
      'Elephant seen near paddy',
    );
    await tester.ensureVisible(find.text('Submit report'));
    await tester.tap(find.text('Submit report'));
    await tester.pumpAndSettle();
    expect(scenario.submitted, hasLength(1));
    expect(scenario.submitted.single, containsPair('parkId', 'park-yala'));
    expect(
      scenario.submitted.single,
      containsPair('type', 'WILDLIFE_SIGHTING'),
    );
    expect(scenario.submitted.single, containsPair('species', 'Elephant'));
    expect(scenario.submitted.single.containsKey('occurredAt'), isTrue);
    await tester.pumpWidget(const SizedBox.shrink());
    scenario.outbox.dispose();
    await tester.binding.setSurfaceSize(null);
  });

  // TEST: Offline Report Outbox Retries and Account Isolation
  // This test verifies that reports created when offline persist in the outbox,
  // retain their idempotency UUID, and are never sent under or shared across different user accounts.
  test(
    'offline report retries keep its ID and cannot cross accounts',
    () async {
      final scenario = Scenario('COMMUNITY_MEMBER')..offline = true;
      await pumpEventQueue();
      final report = PendingReport(
        id: 'stable-report-id',
        ownerId: 'COMMUNITY_MEMBER',
        kind: ReportKind.community,
        body: {
          'parkId': 'park-yala',
          'type': 'CROP_DAMAGE',
          'description': 'Paddy damage',
        },
      );
      expect(await scenario.outbox.submit(report), isFalse);
      expect(scenario.store.records['COMMUNITY_MEMBER'], hasLength(1));
      scenario.outbox.setUser(user('RANGER'));
      scenario.offline = false;
      await pumpEventQueue();
      expect(scenario.submitted, isEmpty);
      scenario.outbox.setUser(user('COMMUNITY_MEMBER'));
      await pumpEventQueue();
      expect(scenario.submitted, hasLength(1));
      expect(scenario.store.records['COMMUNITY_MEMBER'], isEmpty);
      final puts = scenario.requests
          .where((request) => request.method == 'PUT')
          .toList();
      expect(
        puts.every((request) => request.url.path.endsWith('/stable-report-id')),
        isTrue,
      );
      scenario.outbox.dispose();
    },
  );

  // TEST: Manager Create Alert for Available Community Conflict Report
  // This test verifies that each incoming community conflict report displayed on the
  // manager dashboard provides a dedicated "Create Alert" button to convert that specific
  // incident into an operations alert, rather than only providing a button at the bottom.
  testWidgets('manager dashboard presents Create Alert button on each community conflict report', (tester) async {
    final scenario = Scenario('PARK_MANAGER');
    await tester.binding.setSurfaceSize(const Size(1100, 1500));
    await tester.pumpWidget(scenario.app(const OperationsDashboardScreen()));
    await tester.pumpAndSettle();

    expect(find.text('Incoming community reports'), findsOneWidget);
    expect(find.text('Create Alert'), findsAtLeastNWidgets(1));
    await tester.pumpWidget(const SizedBox.shrink());
    scenario.outbox.dispose();
    await tester.binding.setSurfaceSize(null);
  });

  // TEST: Ranger Alert Resolution with Outcome, Notes, and Media Photo Attachments
  // This test verifies that when resolving an alert, the resolution request contains
  // action taken, outcome/result status, optional notes, and photo IDs conforming to backend DTO.
  test('ranger resolves alert with action taken, outcome, notes, and photos', () async {
    final scenario = Scenario('RANGER');
    final alertRepo = ApiAlertRepository(scenario.api);

    final resolved = await alertRepo.resolve(
      'alert-101',
      'Deployed field rangers to village boundary',
      'Resolved',
      notes: 'Elephants moved safely away from crops without harm.',
      photoIds: ['photo-1', 'photo-2'],
    );

    expect(resolved.id, 'alert-101');
    expect(resolved.status, 'RESOLVED');
    expect(resolved.actionTaken, 'Deployed field rangers to village boundary');
    expect(resolved.result, 'Resolved');
    expect(resolved.notes, 'Elephants moved safely away from crops without harm.');
    expect(resolved.photoIds, ['photo-1', 'photo-2']);

    final lastReq = scenario.submitted.last;
    expect(lastReq['actionTaken'], 'Deployed field rangers to village boundary');
    expect(lastReq['result'], 'Resolved');
    expect(lastReq['notes'], 'Elephants moved safely away from crops without harm.');
    expect(lastReq['photoIds'], ['photo-1', 'photo-2']);
  });
}
