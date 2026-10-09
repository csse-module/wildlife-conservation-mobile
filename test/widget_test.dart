import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wildlife_conservation_mobile/features/operations/presentation/widgets.dart';

void main() {
  testWidgets('report status is accessible at narrow widths and large text', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(320, 640));
    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: const MediaQueryData(textScaler: TextScaler.linear(2)),
          child: const Scaffold(
            body: SectionCard(
              title: 'Community reporting',
              child: StatusChip('RESPONDING'),
            ),
          ),
        ),
      ),
    );
    expect(find.text('Responding'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.binding.setSurfaceSize(null);
  });
}
