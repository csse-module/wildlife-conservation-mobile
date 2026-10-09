import 'package:flutter/material.dart';
import '../features/operations/domain/models.dart';
import '../features/operations/presentation/report_form_screen.dart';

class ReportIncidentScreen extends StatelessWidget {
  const ReportIncidentScreen({super.key});
  @override
  Widget build(BuildContext context) =>
      const ReportFormScreen(kind: ReportKind.incident);
}
