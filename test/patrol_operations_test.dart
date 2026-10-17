import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:wildlife_conservation_mobile/features/operations/data/api_repositories.dart';
import 'package:wildlife_conservation_mobile/features/operations/presentation/patrol_assignment_screen.dart';
import 'package:wildlife_conservation_mobile/providers/patrol_provider.dart';
import 'package:wildlife_conservation_mobile/screens/ranger_details_screen.dart';
import 'package:wildlife_conservation_mobile/screens/rangers_list_screen.dart';
import 'package:wildlife_conservation_mobile/services/api_service.dart';
import 'test_helpers.dart';

void main() {
  setUpAll(initMockTestEnvironment);
  setUp(initMockTestEnvironment);

  // TEST: Manager Patrol Assignment
  // This test verifies that a Park Manager can select an available route in their park,
  // pick an assigned ranger, and submit the patrol assignment payload to the backend repository.
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

  // TEST: Route Assignment Without Configured Area
  // This test verifies that routes defined without a specific sub-area (or blank area)
  // can still be loaded, display eligible rangers, and be assigned without runtime errors.
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

  // TEST: Admin Patrol Route Creation API
  // This test verifies that creating a patrol route submits the parkId, areaId, route name,
  // planned distance in meters, and path points to the /patrol-routes endpoint.
  test('admin can create patrol routes with planned distance and path points', () async {
    Map<String, dynamic>? createdRoute;
    final api = ApiService(
      baseUrl: 'http://test/api/v1',
      client: MockClient((request) async {
        if (request.url.path.endsWith('/patrol-routes') && request.method == 'POST') {
          createdRoute = jsonDecode(request.body) as Map<String, dynamic>;
          return http.Response(
            jsonEncode({
              'status': 201,
              'data': {
                'id': 'route-new-001',
                ...createdRoute!,
              },
            }),
            201,
            headers: {'content-type': 'application/json'},
          );
        }
        return http.Response('Not Found', 404);
      }),
    );

    final response = await api.post('/patrol-routes', {
      'parkId': 'park-yala',
      'areaId': 'area-b1',
      'name': 'North Boundary Trail',
      'plannedDistanceMeters': 3500.0,
      'pathPoints': [
        {'latitude': 6.371, 'longitude': 81.381},
        {'latitude': 6.375, 'longitude': 81.389},
      ],
    });

    expect(response.statusCode, 201);
    expect(createdRoute?['name'], 'North Boundary Trail');
    expect(createdRoute?['plannedDistanceMeters'], 3500.0);
    expect((createdRoute?['pathPoints'] as List).length, 2);
  });

  // TEST: Ranger Emergency Alert Dispatch
  // This test verifies that triggering an emergency alert submits a HIGH risk level alert
  // conforming to the backend RiskLevel enum (LOW, MEDIUM, HIGH) with ranger distress details
  // to the AlertRepository so administrators are immediately notified.
  test('ranger emergency alert dispatches critical risk alert to repository', () async {
    Map<String, dynamic>? alertPayload;
    final api = ApiService(
      baseUrl: 'http://test/api/v1',
      client: MockClient((request) async {
        if (request.url.path.contains('/alerts/') && request.method == 'PUT') {
          alertPayload = jsonDecode(request.body) as Map<String, dynamic>;
          return success({'message': 'Alert created'});
        }
        return http.Response('Not Found', 404);
      }),
    );

    final alertRepo = ApiAlertRepository(api);
    await alertRepo.create('alert-emergency-999', {
      'parkId': 'park-yala',
      'areaId': 'area-b1',
      'animal': 'EMERGENCY: Ranger in Distress (Ranger Perera)',
      'collarId': 'RANGER-007',
      'riskLevel': 'HIGH',
      'location': {'latitude': 6.375, 'longitude': 81.382, 'source': 'GPS'},
      'locationUpdatedAt': '2026-10-10T10:00:00Z',
      'detectedAt': '2026-10-10T10:00:00Z',
    });

    expect(alertPayload?['riskLevel'], 'HIGH');
    expect(alertPayload?['animal'], contains('Ranger in Distress'));
    expect(alertPayload?['location']?['latitude'], 6.375);
    expect(alertPayload?['location']?['source'], 'GPS');
  });

  // TEST: Ranger Manual Waypoint Recording
  // This test verifies that PatrolProvider correctly records manual waypoints
  // with exact coordinates, timestamp, and descriptive labels.
  test('ranger manual waypoint records waypoint with coordinates and label', () {
    final patrolProvider = PatrolProvider();
    expect(patrolProvider.waypoints, isEmpty);

    patrolProvider.markWaypointAt('Waterhole Observation Point', 6.3742, 81.3815);

    expect(patrolProvider.waypoints, hasLength(1));
    final wp = patrolProvider.waypoints.first;
    expect(wp['label'], 'Waterhole Observation Point');
    expect(wp['location']['latitude'], 6.3742);
    expect(wp['location']['longitude'], 81.3815);
  });

  // TEST: Track Rangers Status (Available vs On Patrol)
  // This test verifies that completed patrol assignments (status == 'COMPLETED') do NOT mark
  // the ranger as busy, displaying 'Available', while uncompleted assignments (status == 'ASSIGNED')
  // correctly mark the ranger as 'On Patrol'.
  testWidgets('admin track rangers marks completed patrol rangers as available and pending as on patrol', (tester) async {
    final api = ApiService(
      baseUrl: 'http://test/api/v1',
      client: MockClient((request) async {
        final path = request.url.path;
        if (path.endsWith('/users')) {
          return success({
            'items': [
              {'id': 'ranger-avail', 'name': 'Available Ranger', 'role': 'RANGER'},
              {'id': 'ranger-busy', 'name': 'Busy Ranger', 'role': 'RANGER'},
            ],
            'page': 0,
            'size': 100,
            'totalPages': 1,
            'totalItems': 2,
          });
        }
        if (path.endsWith('/patrol-assignments')) {
          return success({
            'items': [
              {
                'id': 'assign-1',
                'rangerId': 'ranger-avail',
                'status': 'COMPLETED',
                'isCompleted': true,
              },
              {
                'id': 'assign-2',
                'rangerId': 'ranger-busy',
                'status': 'ASSIGNED',
                'isCompleted': false,
              },
            ],
            'page': 0,
            'size': 100,
            'totalPages': 1,
            'totalItems': 2,
          });
        }
        return http.Response('Not Found', 404);
      }),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: RangersListScreen(apiService: api),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Available Ranger'), findsOneWidget);
    expect(find.text('Busy Ranger'), findsOneWidget);
    expect(find.text('Available'), findsOneWidget);
    expect(find.text('On Patrol'), findsOneWidget);
  });

  // TEST: Ranger Details Completed Patrols and Incidents Query Pagination
  // This test verifies that RangerDetailsScreen queries /patrols and /incidents with page size <= 100
  // to adhere to backend Spring Boot @Max(100) constraint, and correctly presents completed patrols
  // and reported incidents matching the ranger.
  testWidgets('ranger details queries completed patrols and incidents with size <= 100 and shows records', (tester) async {
    final api = ApiService(
      baseUrl: 'http://test/api/v1',
      client: MockClient((request) async {
        final path = request.url.path;
        final size = int.tryParse(request.url.queryParameters['size'] ?? '') ?? 0;
        expect(size <= 100, isTrue, reason: 'Page query size must not exceed backend limit of 100');

        if (path.endsWith('/patrols')) {
          return success({
            'items': [
              {
                'id': 'patrol-1',
                'rangerId': 'ranger-demo',
                'endedAt': '2026-10-10T12:00:00Z',
                'recordedDistanceMeters': 3500.0,
                'waypointCount': 4,
                'observationCount': 2,
              },
            ],
            'page': 0,
            'size': 100,
            'totalPages': 1,
            'totalItems': 1,
          });
        }
        if (path.endsWith('/incidents')) {
          return success({
            'items': [
              {
                'id': 'incident-1',
                'reportedBy': 'ranger-demo',
                'type': 'POACHING_TRAP',
                'description': 'Removed wire snare near river',
                'detectedAt': '2026-10-10T11:00:00Z',
              },
            ],
            'page': 0,
            'size': 100,
            'totalPages': 1,
            'totalItems': 1,
          });
        }
        return http.Response('Not Found', 404);
      }),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: RangerDetailsScreen(
          rangerId: 'ranger-demo',
          rangerName: 'Ranger Demo',
          apiService: api,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Completed Patrols'), findsOneWidget);
    expect(find.text('Distance: 3.50 km\nWaypoints: 4 | Sightings: 2'), findsOneWidget);

    // Switch to Reported Incidents tab
    await tester.tap(find.text('Reported Incidents'));
    await tester.pumpAndSettle();

    expect(find.text('POACHING TRAP'), findsOneWidget);
    expect(find.textContaining('Removed wire snare near river'), findsOneWidget);
  });
}
