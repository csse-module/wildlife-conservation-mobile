import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/testing.dart';
import 'package:wildlife_conservation_mobile/features/operations/data/api_repositories.dart';
import 'package:wildlife_conservation_mobile/features/operations/domain/models.dart';
import 'package:wildlife_conservation_mobile/features/operations/presentation/camera_images_screen.dart';
import 'package:wildlife_conservation_mobile/features/operations/presentation/reporting_screen.dart';
import 'package:wildlife_conservation_mobile/services/api_service.dart';
import 'test_helpers.dart';

void main() {
  setUpAll(initMockTestEnvironment);
  setUp(initMockTestEnvironment);

  // TEST: Multipart Media Upload Headers and Category Metadata
  // This test verifies that uploading field photos sends multipart/form-data with
  // the appropriate media category, park affiliation, authorization header, and image MIME type.
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

  // TEST: Saved Report Generation and PDF Document Download
  // This test verifies that a researcher can generate and persist an analytical report,
  // save it to the backend reports archive, and download the resulting PDF document bytes.
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

  // TEST: Conflict Trends and Patrol Coverage Analytics Mapping
  // This test verifies that ApiReportingRepository accurately parses conflict types,
  // daily incident counts, hotspot areas, and patrol coverage percentage from API.
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

  // TEST: Robust Analytics Parsing and Numeric Casting
  // This test verifies that mapAnalytics safely handles mixed integer and double types
  // and null area names without throwing type cast exceptions.
  test('mapAnalytics safely casts mixed double/int values and null fields', () {
    final rawJson = {
      'totalIncidents': 12,
      'communityReportCount': 5,
      'resolvedAlertCount': 3,
      'dataAvailable': true,
      'incidentTypeCounts': [
        {'type': 'SNARE', 'count': 8.0}, // Double instead of int
      ],
      'dailyIncidentCounts': [
        {'date': '2026-10-10', 'count': 4.0},
      ],
      'areaCounts': [
        {'areaName': null, 'incidentCount': 6.0, 'potentialHotspot': true},
      ],
      'patrolCoverage': {
        'assignedRouteCount': 10.0,
        'completedRouteCount': 8.0,
        'coveragePercent': 80.0,
      },
      'communityConflict': {
        'typeCounts': {'CROP_DAMAGE': 5.0},
        'dailyCounts': [],
        'areaCounts': [],
      },
    };

    final analytics = mapAnalytics(rawJson);

    expect(analytics.totalIncidents, 12);
    expect(analytics.incidentTypes['SNARE'], 8);
    expect(analytics.incidentAreas.first.name, 'Unknown Area');
    expect(analytics.incidentAreas.first.count, 6);
    expect(analytics.assignedRoutes, 10);
    expect(analytics.completedRoutes, 8);
    expect(analytics.coveragePercent, 80.0);
    expect(analytics.communityTypes['CROP_DAMAGE'], 5);
  });

  // TEST: Camera Trap Monitoring Mock Data Fallback
  // This test verifies that when the camera trap repository returns an empty list,
  // the camera images screen displays rich Sri Lankan wildlife mock data (Leopards, Elephants, etc.).
  testWidgets('camera trap monitoring displays mock data when repository is empty', (tester) async {
    final scenario = Scenario('RESEARCHER');
    await tester.binding.setSurfaceSize(const Size(1100, 1500));
    await tester.pumpWidget(scenario.app(const CameraImagesScreen(parkId: 'park-yala')));
    await tester.pumpAndSettle();

    expect(find.text('Camera trap monitoring'), findsOneWidget);
    expect(find.text('Displaying camera trap monitoring sample data.'), findsOneWidget);
    expect(find.textContaining('Sri Lankan Leopard'), findsOneWidget);
    expect(find.textContaining('Asian Elephant'), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
    scenario.outbox.dispose();
    await tester.binding.setSurfaceSize(null);
  });
}
