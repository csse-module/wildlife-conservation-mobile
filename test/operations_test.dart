import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wildlife_conservation_mobile/features/operations/data/api_repositories.dart';
import 'package:wildlife_conservation_mobile/features/operations/data/report_outbox.dart';
import 'package:wildlife_conservation_mobile/features/operations/domain/models.dart';
import 'package:wildlife_conservation_mobile/features/operations/domain/repositories.dart';
import 'package:wildlife_conservation_mobile/features/operations/presentation/field_reports_screen.dart';
import 'package:wildlife_conservation_mobile/features/operations/presentation/operations_dashboard_screen.dart';
import 'package:wildlife_conservation_mobile/features/operations/presentation/report_form_screen.dart';
import 'package:wildlife_conservation_mobile/features/operations/presentation/reporting_screen.dart';
import 'package:wildlife_conservation_mobile/features/operations/presentation/patrol_assignment_screen.dart';
import 'package:wildlife_conservation_mobile/providers/auth_provider.dart';
import 'package:wildlife_conservation_mobile/models/user_model.dart';
import 'package:wildlife_conservation_mobile/services/api_service.dart';

class MemoryOutbox implements ReportOutboxStore {
  final Map<String, List<PendingReport>> records = {};
  @override
  Future<List<PendingReport>> read(String ownerId) async =>
      List.of(records[ownerId] ?? []);
  @override
  Future<void> write(String ownerId, List<PendingReport> reports) async {
    records[ownerId] = List.of(reports);
  }
}

User user(String role) => User(
  id: role,
  name: 'Demo ${role.toLowerCase()}',
  email: 'demo@example.test',
  role: role,
  parkIds: ['park-yala'],
);

class FixtureAuth extends AuthProvider {
  FixtureAuth(this.fixture);
  final User fixture;
  @override
  User get user => fixture;
  @override
  bool get isAuthenticated => true;
}

Map<String, dynamic> fieldReport() => {
  'id': '10000000-0000-4000-8000-000000000001',
  'parkId': 'park-yala',
  'areaId': 'area-b1',
  'type': 'WILDLIFE_SIGHTING',
  'description': 'Elephant near the village boundary',
  'occurredAt': '2026-10-08T01:00:00Z',
  'reportedBy': 'COMMUNITY_MEMBER',
  'status': 'SUBMITTED',
  'village': 'Boundary Village',
  'species': 'Elephant',
};
Map<String, dynamic> analytics() => {
  'totalIncidents': 4,
  'communityReportCount': 2,
  'resolvedAlertCount': 1,
  'dataAvailable': true,
  'incidentTypeCounts': [
    {'type': 'SNARE', 'count': 4},
  ],
  'dailyIncidentCounts': [
    {'date': '2026-10-08', 'count': 4},
  ],
  'areaCounts': [
    {'areaName': 'Block 1', 'incidentCount': 4, 'potentialHotspot': true},
  ],
  'patrolCoverage': {
    'assignedRouteCount': 4,
    'completedRouteCount': 3,
    'coveragePercent': 75.0,
  },
  'communityConflict': {
    'typeCounts': {'CROP_DAMAGE': 2},
    'dailyCounts': [
      {'date': '2026-10-08', 'count': 2},
    ],
    'areaCounts': [
      {'areaName': 'Block 1', 'reportCount': 2},
    ],
  },
};
http.Response success(dynamic data) => http.Response(
  jsonEncode({
    'status': '00',
    'description': 'SUCCESS',
    'data': data,
    'error': {
      'errorCode': '00',
      'errorDescription': 'SUCCESS',
      'fieldErrors': {},
    },
  }),
  200,
  headers: {'content-type': 'application/json'},
);

class Scenario {
  Scenario(this.role) {
    api = ApiService(
      baseUrl: 'http://test/api/v1',
      client: MockClient((request) async {
        requests.add(request);
        if (offline) throw http.ClientException('offline');
        final path = request.url.path.replaceFirst('/api/v1', '');
        if (path == '/parks') {
          return success({
            'items': [
              {
                'id': 'park-yala',
                'name': 'Yala National Park',
                'areas': [
                  {'id': 'area-b1', 'name': 'Block 1'},
                ],
              },
            ],
            'page': 0,
            'size': 100,
            'totalItems': 1,
          });
        }
        if (path == '/analytics/summary') return success(analytics());
        if (path == '/alerts') {
          return success({'items': [], 'page': 0, 'size': 20, 'totalItems': 0});
        }
        if (path == '/reports') {
          return success({
            'items': savedReports,
            'page': 0,
            'size': 20,
            'totalItems': savedReports.length,
          });
        }
        if (path.startsWith('/reports/')) {
          if (path.endsWith('/download')) {
            return http.Response(
              '%PDF-1.4\nfixture',
              200,
              headers: {'content-type': 'application/pdf'},
            );
          }
          if (request.method == 'PUT') {
            final body = jsonDecode(request.body) as Map<String, dynamic>;
            savedReports.add({
              ...body,
              'id': path.split('/').last,
              'generatedBy': role,
              'generatedAt': '2026-10-09T10:00:00Z',
              'snapshot': analytics(),
            });
          }
          return success(savedReports.last);
        }
        if (path == '/patrol-routes') {
          return success({
            'items': patrolRoutes,
            'page': 0,
            'size': 100,
            'totalItems': patrolRoutes.length,
          });
        }
        if (path == '/users') {
          return success({
            'items': [
              {'id': 'ranger-1', 'name': 'Available ranger'},
            ],
            'page': 0,
            'size': 100,
            'totalItems': 1,
          });
        }
        if (path.startsWith('/patrol-assignments/')) {
          submitted.add(jsonDecode(request.body) as Map<String, dynamic>);
          return success({});
        }
        if (path == '/community-reports') {
          final status = request.url.queryParameters['status'];
          final filtered = reports
              .where((report) => status == null || report['status'] == status)
              .toList();
          return success({
            'items': filtered,
            'page': 0,
            'size': 20,
            'totalItems': filtered.length,
          });
        }
        if (path.endsWith('/accept')) {
          reports.first['status'] = 'RESPONDING';
          reports.first['assignedOfficerId'] = role;
          return success(reports.first);
        }
        if (path.endsWith('/response')) {
          reports.first.addAll(
            jsonDecode(request.body) as Map<String, dynamic>,
          );
          reports.first['status'] = 'RESOLVED';
          return success(reports.first);
        }
        if (path.startsWith('/community-reports/')) {
          if (request.method == 'PUT') {
            submitted.add(jsonDecode(request.body) as Map<String, dynamic>);
            return success({'id': path.split('/').last});
          }
          return success(reports.first);
        }
        throw StateError('Unexpected request: ${request.method} $path');
      }),
    );
    outbox = ReportOutbox(api, store, listenForConnectivity: false)
      ..setUser(user(role));
  }
  final String role;
  final requests = <http.Request>[];
  final reports = <Map<String, dynamic>>[fieldReport()];
  final submitted = <Map<String, dynamic>>[];
  final savedReports = <Map<String, dynamic>>[];
  final patrolRoutes = <Map<String, dynamic>>[
    {'id': 'route-demo', 'name': 'Village patrol', 'areaId': 'area-b1'},
  ];
  final store = MemoryOutbox();
  late ApiService api;
  late ReportOutbox outbox;
  bool offline = false;

  Widget app(Widget home, {GlobalKey? screenshotKey}) => MultiProvider(
    providers: [
      ChangeNotifierProvider<AuthProvider>(
        create: (_) => FixtureAuth(user(role)),
      ),
      ChangeNotifierProvider<ReportOutbox>.value(value: outbox),
      Provider<ParkRepository>.value(value: ApiParkRepository(api)),
      Provider<FieldReportRepository>.value(
        value: ApiFieldReportRepository(api),
      ),
      Provider<ReportingRepository>.value(value: ApiReportingRepository(api)),
      Provider<AlertRepository>.value(value: ApiAlertRepository(api)),
      Provider<CameraRepository>.value(value: ApiCameraRepository(api)),
      Provider<PatrolManagementRepository>.value(
        value: ApiPatrolManagementRepository(api),
      ),
    ],
    child: MaterialApp(
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.green),
        useMaterial3: true,
        inputDecorationTheme: const InputDecorationTheme(
          border: OutlineInputBorder(),
        ),
      ),
      home: RepaintBoundary(key: screenshotKey, child: home),
    ),
  );
}

Future<void> screenshot(WidgetTester tester, GlobalKey key, String name) async {
  await tester.runAsync(() async {
    final boundary =
        key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
    final image = await boundary.toImage(pixelRatio: 1);
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    final directory = Directory('.buildlog/screenshots')
      ..createSync(recursive: true);
    await File(
      '${directory.path}/$name.png',
    ).writeAsBytes(bytes!.buffer.asUint8List());
    image.dispose();
  });
}

void main() {
  setUpAll(() async {
    if (!const bool.fromEnvironment('REVIEW_SCREENSHOTS')) return;
    final sdk = Platform.environment['FLUTTER_ROOT'];
    if (sdk == null) return;
    for (final entry in {
      'Roboto': 'roboto-regular.ttf',
      'MaterialIcons': 'materialicons-regular.otf',
    }.entries) {
      final file = File(
        '$sdk/bin/cache/artifacts/material_fonts/${entry.value}',
      );
      if (file.existsSync()) {
        await (FontLoader(
          entry.key,
        )..addFont(file.readAsBytes().then(ByteData.sublistView))).load();
      }
    }
  });
  setUp(() {
    SharedPreferences.setMockInitialValues({'jwt_token': 'test-token'});
  });

  test(
    'image upload sends the image MIME type and required media metadata',
    () async {
      final api = ApiService(
        baseUrl: 'http://test/api/v1',
        client: MockClient((request) async {
          final multipart = latin1.decode(request.bodyBytes);
          expect(multipart.toLowerCase(), contains('content-type: image/png'));
          expect(multipart, contains('name="parkId"\r\n\r\npark-yala'));
          expect(
            multipart,
            contains('name="category"\r\n\r\nCOMMUNITY_REPORT'),
          );
          expect(request.headers['Authorization'], 'Bearer test-token');
          return success({});
        }),
      );
      await api.uploadImage(
        id: '10000000-0000-4000-8000-000000000001',
        parkId: 'park-yala',
        category: 'COMMUNITY_REPORT',
        bytes: base64Decode(
          'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+jGJkAAAAASUVORK5CYII=',
        ),
        name: 'evidence.png',
      );
    },
  );

  testWidgets('researcher generates a saved report and downloads PDF bytes', (
    tester,
  ) async {
    final scenario = Scenario('RESEARCHER');
    await tester.binding.setSurfaceSize(const Size(1100, 1500));
    await tester.pumpWidget(scenario.app(const ReportingScreen()));
    await tester.pumpAndSettle();
    expect(find.text('Human-wildlife conflict by type'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('Generate report'), 500);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Generate report'));
    await tester.pumpAndSettle();
    expect(find.text('Conservation report'), findsOneWidget);
    final report = scenario.savedReports.single;
    expect(report['sections'], contains('CONFLICT_SUMMARY'));
    final bytes = await ApiReportingRepository(
      scenario.api,
    ).download(report['id'] as String);
    expect(utf8.decode(bytes), startsWith('%PDF-'));
    await tester.pumpWidget(const SizedBox.shrink());
    scenario.outbox.dispose();
    await tester.binding.setSurfaceSize(null);
  });

  testWidgets(
    'manager assigns a configured route to a ranger in the same park',
    (tester) async {
      final scenario = Scenario('PARK_MANAGER');
      await tester.pumpWidget(scenario.app(const PatrolAssignmentScreen()));
      await tester.pumpAndSettle();
      await tester.tap(
        find.widgetWithText(DropdownButtonFormField<String>, 'Park'),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Yala National Park').last);
      await tester.pumpAndSettle();
      await tester.tap(
        find.widgetWithText(DropdownButtonFormField<String>, 'Patrol route'),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Village patrol · area-b1').last);
      await tester.pumpAndSettle();
      await tester.tap(
        find.widgetWithText(DropdownButtonFormField<String>, 'Ranger'),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Available ranger').last);
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Assign patrol'));
      await tester.pumpAndSettle();
      expect(scenario.submitted.single['routeId'], 'route-demo');
      expect(scenario.submitted.single['rangerId'], 'ranger-1');
      expect(
        scenario.requests
            .where(
              (request) =>
                  request.url.path.endsWith('/patrol-routes') ||
                  request.url.path.endsWith('/users'),
            )
            .every(
              (request) => request.url.queryParameters['parkId'] == 'park-yala',
            ),
        isTrue,
      );
      await tester.pumpWidget(const SizedBox.shrink());
      scenario.outbox.dispose();
    },
  );

  testWidgets('routes without an area still show rangers and can be assigned', (
    tester,
  ) async {
    final scenario = Scenario('PARK_MANAGER');
    scenario.patrolRoutes
      ..clear()
      ..addAll([
        {'id': 'route-missing-area', 'name': 'Boundary patrol'},
        {'id': 'route-null-area', 'name': 'Forest patrol', 'areaId': null},
        {'id': 'route-blank-area', 'name': 'River patrol', 'areaId': ' '},
      ]);
    await tester.pumpWidget(scenario.app(const PatrolAssignmentScreen()));
    await tester.pumpAndSettle();
    await tester.tap(
      find.widgetWithText(DropdownButtonFormField<String>, 'Park'),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Yala National Park').last);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await tester.tap(
      find.widgetWithText(DropdownButtonFormField<String>, 'Patrol route'),
    );
    await tester.pumpAndSettle();
    for (final name in ['Boundary patrol', 'Forest patrol', 'River patrol']) {
      expect(find.text(name), findsWidgets);
    }
    await tester.tap(find.text('Boundary patrol').last);
    await tester.pumpAndSettle();
    await tester.tap(
      find.widgetWithText(DropdownButtonFormField<String>, 'Ranger'),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Available ranger').last);
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Assign patrol'));
    await tester.pumpAndSettle();
    expect(scenario.submitted.single['routeId'], 'route-missing-area');
    expect(scenario.submitted.single['rangerId'], 'ranger-1');
    await tester.pumpWidget(const SizedBox.shrink());
    scenario.outbox.dispose();
  });

  testWidgets('community sees reporting actions and no manager privileges', (
    tester,
  ) async {
    final scenario = Scenario('COMMUNITY_MEMBER');
    final key = GlobalKey();
    await tester.binding.setSurfaceSize(const Size(390, 844));
    await tester.pumpWidget(
      scenario.app(const OperationsDashboardScreen(), screenshotKey: key),
    );
    await tester.pumpAndSettle();
    expect(find.text('Community Dashboard'), findsOneWidget);
    expect(find.text('Report sighting or crop damage'), findsOneWidget);
    expect(find.text('Add staff'), findsNothing);
    expect(find.text('Analytics & reports'), findsNothing);
    expect(
      scenario.requests.any((request) => request.url.path.endsWith('/alerts')),
      isFalse,
    );
    await screenshot(tester, key, 'community-dashboard');
    await tester.pumpWidget(const SizedBox.shrink());
    scenario.outbox.dispose();
    await tester.binding.setSurfaceSize(null);
  });

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

  testWidgets(
    'researcher has analytics and camera access without community inbox calls',
    (tester) async {
      final scenario = Scenario('RESEARCHER');
      await tester.pumpWidget(scenario.app(const OperationsDashboardScreen()));
      await tester.pumpAndSettle();
      expect(find.text('Research Dashboard'), findsOneWidget);
      expect(find.text('Analytics & reports'), findsOneWidget);
      expect(find.text('Camera traps'), findsOneWidget);
      expect(find.text('Add staff'), findsNothing);
      expect(
        scenario.requests.any(
          (request) => request.url.path.endsWith('/community-reports'),
        ),
        isFalse,
      );
      await tester.pumpWidget(const SizedBox.shrink());
      scenario.outbox.dispose();
    },
  );

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

  test('analytics maps conflict types trends and coverage from API', () async {
    final scenario = Scenario('RESEARCHER');
    final result = await ApiReportingRepository(
      scenario.api,
    ).analytics('park-yala', DateTime(2026, 10, 1), DateTime(2026, 10, 9));
    expect(result.coveragePercent, 75);
    expect(result.communityTypes['CROP_DAMAGE'], 2);
    expect(result.communityDays.single.count, 2);
    expect(result.communityAreas.single.name, 'Block 1');
    expect(scenario.requests.last.url.queryParameters['from'], '2026-10-01');
    scenario.outbox.dispose();
  });
}
