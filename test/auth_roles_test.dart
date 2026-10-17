import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:wildlife_conservation_mobile/features/operations/domain/role_capabilities.dart';
import 'package:wildlife_conservation_mobile/features/operations/presentation/operations_dashboard_screen.dart';
import 'package:wildlife_conservation_mobile/providers/auth_provider.dart';
import 'package:wildlife_conservation_mobile/services/api_service.dart';
import 'test_helpers.dart';

void main() {
  setUpAll(initMockTestEnvironment);
  setUp(initMockTestEnvironment);

  // TEST: Password Reset Flow
  // This test verifies that AuthProvider.resetPassword submits email and new password
  // to the public /auth/reset-password endpoint and returns true upon success.
  test('password reset sends email and new password to /auth/reset-password', () async {
    Map<String, dynamic>? receivedPayload;
    final api = ApiService(
      baseUrl: 'http://test/api/v1',
      client: MockClient((request) async {
        if (request.url.path.endsWith('/auth/reset-password')) {
          receivedPayload = jsonDecode(request.body) as Map<String, dynamic>;
          return success({'message': 'Password reset successful'});
        }
        return http.Response('Not Found', 404);
      }),
    );

    final authProvider = AuthProvider(api: api);
    final result = await authProvider.resetPassword('ranger@wildlife.gov', 'NewSafePass123');

    expect(result, isTrue);
    expect(receivedPayload?['email'], 'ranger@wildlife.gov');
    expect(receivedPayload?['newPassword'], 'NewSafePass123');
  });

  // TEST: Community Member Dashboard Privileges
  // This test verifies that Community Members have access to sighting submissions
  // but are restricted from operational actions such as patrol management or routes.
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

  // TEST: Community Member Dashboard Configuration
  // This test verifies that COMMUNITY_MEMBER does not have the communityReports action
  // in their assigned actions list, satisfying the requirement to remove community reports from community dashboard.
  test('community dashboard does not include community reports action', () {
    final communityActions = actionsForRole('COMMUNITY_MEMBER');
    expect(communityActions.contains(OperationAction.communityReports), isFalse);
    expect(communityActions.contains(OperationAction.reportConflict), isTrue);
    expect(communityActions.contains(OperationAction.outbox), isTrue);
  });

  // TEST: Researcher Role Authorization Boundaries
  // This test verifies that Researchers have access to analytical summaries and camera traps
  // without fetching or querying private community inbox records.
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
}
