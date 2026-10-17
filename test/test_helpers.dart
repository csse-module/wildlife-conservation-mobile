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
import 'package:wildlife_conservation_mobile/models/user_model.dart';
import 'package:wildlife_conservation_mobile/providers/auth_provider.dart';
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
  parkIds: role == 'COMMUNITY_MEMBER' ? [] : ['park-yala'],
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
        if (path.startsWith('/alerts/') && path.endsWith('/response')) {
          final body = jsonDecode(request.body) as Map<String, dynamic>;
          submitted.add(body);
          return success({
            'id': path.split('/')[2],
            'parkId': 'park-yala',
            'areaId': 'area-b1',
            'animal': 'Elephant',
            'collarId': 'COLLAR-1',
            'riskLevel': 'HIGH',
            'status': 'RESOLVED',
            'detectedAt': '2026-10-09T10:00:00Z',
            'location': {'latitude': 6.3, 'longitude': 81.5},
            'supportRequests': [],
            'response': body,
          });
        }
        if (path == '/camera-trap-images') {
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
      Provider<ApiService>.value(value: api),
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

Future<void> initMockTestEnvironment() async {
  SharedPreferences.setMockInitialValues({'jwt_token': 'test-token'});
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
}
