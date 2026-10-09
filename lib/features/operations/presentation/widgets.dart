import 'dart:typed_data';
import 'package:flutter/material.dart';
import '../../../utils/constants.dart';

String readable(String value) => value
    .split('_')
    .map(
      (part) =>
          part.isEmpty ? '' : '${part[0]}${part.substring(1).toLowerCase()}',
    )
    .join(' ');
String dateLabel(DateTime date) =>
    date.toLocal().toIso8601String().substring(0, 16).replaceFirst('T', ' ');

class OperationScaffold extends StatelessWidget {
  const OperationScaffold({
    super.key,
    required this.title,
    required this.body,
    this.actions,
    this.floatingActionButton,
  });
  final String title;
  final Widget body;
  final List<Widget>? actions;
  final Widget? floatingActionButton;
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Text(title),
      actions: actions,
      backgroundColor: AppConstants.primaryGreen,
      foregroundColor: Colors.white,
    ),
    floatingActionButton: floatingActionButton,
    body: SafeArea(
      child: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1100),
          child: body,
        ),
      ),
    ),
  );
}

class FailurePanel extends StatelessWidget {
  const FailurePanel(this.message, {super.key, required this.retry});
  final String message;
  final VoidCallback retry;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.all(24),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(Icons.cloud_off_outlined, size: 40, color: Colors.grey),
        const SizedBox(height: 12),
        Text(message, textAlign: TextAlign.center),
        const SizedBox(height: 12),
        OutlinedButton.icon(
          onPressed: retry,
          icon: const Icon(Icons.refresh),
          label: const Text('Retry'),
        ),
      ],
    ),
  );
}

class StatusChip extends StatelessWidget {
  const StatusChip(this.status, {super.key});
  final String status;
  @override
  Widget build(BuildContext context) {
    final color = switch (status) {
      'RESOLVED' || 'REVIEWED' => Colors.green,
      'RESPONDING' => Colors.blue,
      'PENDING_SYNC' => Colors.grey,
      'HIGH' || 'CRITICAL' => Colors.red,
      _ => Colors.orange,
    };
    return Chip(
      label: Text(
        readable(status),
        style: TextStyle(fontSize: 12, color: color.shade800),
      ),
      backgroundColor: color.shade50,
      side: BorderSide.none,
      visualDensity: VisualDensity.compact,
    );
  }
}

class DetailRow extends StatelessWidget {
  const DetailRow(this.label, this.value, {super.key});
  final String label, value;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 8),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: Theme.of(context).textTheme.labelLarge),
        const SizedBox(height: 3),
        SelectableText(value),
      ],
    ),
  );
}

class SectionCard extends StatelessWidget {
  const SectionCard({super.key, required this.title, required this.child});
  final String title;
  final Widget child;
  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(title, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 12),
          child,
        ],
      ),
    ),
  );
}

class ProtectedPhoto extends StatelessWidget {
  const ProtectedPhoto({super.key, required this.load});
  final Future<Uint8List> load;
  @override
  Widget build(BuildContext context) => FutureBuilder<Uint8List>(
    future: load,
    builder: (context, snapshot) {
      if (snapshot.hasError) {
        return const Padding(
          padding: EdgeInsets.all(16),
          child: Text('Photo could not be loaded.'),
        );
      }
      if (!snapshot.hasData) {
        return const SizedBox(
          height: 120,
          child: Center(child: CircularProgressIndicator()),
        );
      }
      return ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Image.memory(
          snapshot.data!,
          height: 250,
          fit: BoxFit.contain,
          errorBuilder: (_, error, stack) => const Text('Image unavailable.'),
        ),
      );
    },
  );
}

void showOperationMessage(BuildContext context, String message) =>
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));

Future<({String action, String result})?> responseDialog(
  BuildContext context,
) async {
  return showDialog<({String action, String result})>(
    context: context,
    builder: (_) => const _ResponseDialog(),
  );
}

class _ResponseDialog extends StatefulWidget {
  const _ResponseDialog();
  @override
  State<_ResponseDialog> createState() => _ResponseDialogState();
}

class _ResponseDialogState extends State<_ResponseDialog> {
  final _form = GlobalKey<FormState>();
  final _action = TextEditingController(), _result = TextEditingController();
  @override
  void dispose() {
    _action.dispose();
    _result.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Record response'),
    content: SingleChildScrollView(
      child: Form(
        key: _form,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextFormField(
              controller: _action,
              maxLength: 1000,
              minLines: 2,
              maxLines: 5,
              decoration: const InputDecoration(labelText: 'Action taken'),
              validator: requiredText,
            ),
            TextFormField(
              controller: _result,
              maxLength: 500,
              minLines: 2,
              maxLines: 4,
              decoration: const InputDecoration(labelText: 'Outcome'),
              validator: requiredText,
            ),
          ],
        ),
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Cancel'),
      ),
      FilledButton(
        onPressed: () {
          if (_form.currentState!.validate()) {
            Navigator.pop(context, (
              action: _action.text.trim(),
              result: _result.text.trim(),
            ));
          }
        },
        child: const Text('Resolve'),
      ),
    ],
  );
}

String? requiredText(String? value) =>
    value == null || value.trim().isEmpty ? 'This field is required' : null;
