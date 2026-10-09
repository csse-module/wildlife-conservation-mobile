import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import '../../../providers/auth_provider.dart';
import '../domain/models.dart';
import '../domain/repositories.dart';
import 'widgets.dart';

class AlertsScreen extends StatefulWidget {
  const AlertsScreen({super.key, this.parkId});
  final String? parkId;
  @override
  State<AlertsScreen> createState() => _AlertsScreenState();
}

class _AlertsScreenState extends State<AlertsScreen> {
  late Future<ResultPage<AlertInfo>> _future;
  String? _status;
  int _page = 0;
  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() {
    _future = context.read<AlertRepository>().list(
      parkId: widget.parkId,
      status: _status,
      page: _page,
    );
  }

  @override
  Widget build(BuildContext context) => OperationScaffold(
    title: 'Conflict alerts',
    actions: [
      IconButton(
        onPressed: () => setState(_load),
        icon: const Icon(Icons.refresh),
        tooltip: 'Refresh',
      ),
    ],
    floatingActionButton:
        context.watch<AuthProvider>().user?.role == 'PARK_MANAGER'
        ? FloatingActionButton.extended(
            onPressed: () async {
              await Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const CreateAlertScreen()),
              );
              if (mounted) setState(_load);
            },
            icon: const Icon(Icons.add_alert),
            label: const Text('Create alert'),
          )
        : null,
    body: Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(12),
          child: DropdownButtonFormField<String>(
            initialValue: _status ?? 'ALL',
            decoration: const InputDecoration(labelText: 'Alert status'),
            items: ['ALL', 'NEW', 'RESPONDING', 'RESOLVED']
                .map(
                  (value) => DropdownMenuItem(
                    value: value,
                    child: Text(readable(value)),
                  ),
                )
                .toList(),
            onChanged: (value) => setState(() {
              _status = value == 'ALL' ? null : value;
              _page = 0;
              _load();
            }),
          ),
        ),
        Expanded(
          child: FutureBuilder<ResultPage<AlertInfo>>(
            future: _future,
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return FailurePanel(
                  snapshot.error.toString(),
                  retry: () => setState(_load),
                );
              }
              if (!snapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }
              final data = snapshot.data!;
              return ListView(
                padding: const EdgeInsets.fromLTRB(12, 0, 12, 88),
                children: [
                  if (data.items.isEmpty)
                    const Padding(
                      padding: EdgeInsets.all(32),
                      child: Text('No alerts found for this selection.'),
                    ),
                  ...data.items.map(
                    (alert) => Card(
                      child: ListTile(
                        title: Text('${alert.animal} · ${alert.areaId}'),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(dateLabel(alert.detectedAt)),
                            Wrap(
                              spacing: 8,
                              children: [
                                StatusChip(alert.status),
                                StatusChip(alert.riskLevel),
                              ],
                            ),
                          ],
                        ),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () async {
                          await Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => AlertDetailScreen(id: alert.id),
                            ),
                          );
                          if (mounted) setState(_load);
                        },
                      ),
                    ),
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      TextButton(
                        onPressed: _page == 0
                            ? null
                            : () => setState(() {
                                _page--;
                                _load();
                              }),
                        child: const Text('Previous'),
                      ),
                      Text('Page ${_page + 1} · ${data.totalItems} alerts'),
                      TextButton(
                        onPressed: !data.hasMore
                            ? null
                            : () => setState(() {
                                _page++;
                                _load();
                              }),
                        child: const Text('Next'),
                      ),
                    ],
                  ),
                ],
              );
            },
          ),
        ),
      ],
    ),
  );
}

class AlertDetailScreen extends StatefulWidget {
  const AlertDetailScreen({super.key, required this.id});
  final String id;
  @override
  State<AlertDetailScreen> createState() => _AlertDetailScreenState();
}

class _AlertDetailScreenState extends State<AlertDetailScreen> {
  late Future<AlertInfo> _future;
  bool _busy = false;
  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() {
    _future = context.read<AlertRepository>().get(widget.id);
  }

  Future<void> _perform(Future<void> Function() action) async {
    setState(() => _busy = true);
    try {
      await action();
      if (mounted) setState(_load);
    } catch (error) {
      if (mounted) {
        showOperationMessage(context, error.toString());
        setState(_load);
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => OperationScaffold(
    title: 'Alert details',
    body: FutureBuilder<AlertInfo>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return FailurePanel(
            snapshot.error.toString(),
            retry: () => setState(_load),
          );
        }
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final alert = snapshot.data!, user = context.watch<AuthProvider>().user;
        final responder =
            user?.role == 'RANGER' || user?.role == 'LIAISON_OFFICER';
        return ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Text(
              '${alert.animal} near ${alert.areaId}',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            Wrap(
              spacing: 8,
              children: [StatusChip(alert.status), StatusChip(alert.riskLevel)],
            ),
            DetailRow('Park / area', '${alert.parkId} / ${alert.areaId}'),
            DetailRow('Collar reference', alert.collarId),
            DetailRow('Detected', dateLabel(alert.detectedAt)),
            DetailRow('Location', '${alert.latitude}, ${alert.longitude}'),
            if (alert.assignedOfficerId != null)
              DetailRow('Responding officer', alert.assignedOfficerId!),
            DetailRow('Support requests recorded', '${alert.supportCount}'),
            if (alert.actionTaken != null)
              DetailRow('Action taken', alert.actionTaken!),
            if (alert.result != null) DetailRow('Outcome', alert.result!),
            if (responder && alert.status == 'NEW') ...[
              FilledButton.icon(
                onPressed: _busy
                    ? null
                    : () => _perform(() async {
                        await context.read<AlertRepository>().accept(alert.id);
                      }),
                icon: const Icon(Icons.check),
                label: const Text('Accept alert'),
              ),
              OutlinedButton(
                onPressed: _busy
                    ? null
                    : () async {
                        final reason = await _reasonDialog(
                          context,
                          'Decline alert',
                        );
                        if (reason == null || !context.mounted) return;
                        await _perform(
                          () => context.read<AlertRepository>().decline(
                            alert.id,
                            reason,
                          ),
                        );
                      },
                child: const Text('Cannot respond'),
              ),
            ],
            if (responder &&
                alert.status == 'RESPONDING' &&
                alert.assignedOfficerId == user?.id) ...[
              OutlinedButton.icon(
                onPressed: _busy
                    ? null
                    : () async {
                        final reason = await _reasonDialog(
                          context,
                          'Request support',
                        );
                        if (reason == null || !context.mounted) return;
                        await _perform(
                          () => context.read<AlertRepository>().support(
                            alert.id,
                            reason,
                          ),
                        );
                        if (context.mounted) {
                          showOperationMessage(
                            context,
                            'Support request recorded in park operations.',
                          );
                        }
                      },
                icon: const Icon(Icons.support_agent),
                label: const Text('Request support'),
              ),
              FilledButton.icon(
                onPressed: _busy
                    ? null
                    : () async {
                        final response = await responseDialog(context);
                        if (response == null || !context.mounted) return;
                        await _perform(() async {
                          await context.read<AlertRepository>().resolve(
                            alert.id,
                            response.action,
                            response.result,
                          );
                        });
                      },
                icon: const Icon(Icons.task_alt),
                label: const Text('Record response and resolve'),
              ),
            ],
            if (_busy) const LinearProgressIndicator(),
          ],
        );
      },
    ),
  );
}

Future<String?> _reasonDialog(BuildContext context, String title) =>
    showDialog<String>(context: context, builder: (_) => _ReasonDialog(title));

class _ReasonDialog extends StatefulWidget {
  const _ReasonDialog(this.title);
  final String title;
  @override
  State<_ReasonDialog> createState() => _ReasonDialogState();
}

class _ReasonDialogState extends State<_ReasonDialog> {
  final _reason = TextEditingController();
  final _form = GlobalKey<FormState>();
  @override
  void dispose() {
    _reason.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(widget.title),
    content: Form(
      key: _form,
      child: TextFormField(
        controller: _reason,
        maxLength: 500,
        maxLines: 3,
        decoration: const InputDecoration(labelText: 'Reason'),
        validator: requiredText,
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
            Navigator.pop(context, _reason.text.trim());
          }
        },
        child: const Text('Confirm'),
      ),
    ],
  );
}

class CreateAlertScreen extends StatefulWidget {
  const CreateAlertScreen({super.key});
  @override
  State<CreateAlertScreen> createState() => _CreateAlertScreenState();
}

class _CreateAlertScreenState extends State<CreateAlertScreen> {
  final _form = GlobalKey<FormState>();
  final _animal = TextEditingController(text: 'Elephant'),
      _collar = TextEditingController();
  final _latitude = TextEditingController(),
      _longitude = TextEditingController();
  late Future<List<ParkInfo>> _parks;
  ParkInfo? _park;
  String? _area;
  String _risk = 'HIGH';
  bool _busy = false;
  String? _id;
  Map<String, dynamic>? _submitted;
  @override
  void initState() {
    super.initState();
    _parks = context.read<ParkRepository>().list();
  }

  @override
  void dispose() {
    for (final controller in [_animal, _collar, _latitude, _longitude]) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_form.currentState!.validate()) return;
    final payload = <String, dynamic>{
      'parkId': _park!.id,
      'areaId': _area,
      'animal': _animal.text.trim(),
      'collarId': _collar.text.trim(),
      'riskLevel': _risk,
      'location': {
        'latitude': double.parse(_latitude.text),
        'longitude': double.parse(_longitude.text),
        'source': 'MANUAL',
      },
    };
    final comparable = Map<String, dynamic>.of(_submitted ?? {})
      ..remove('locationUpdatedAt')
      ..remove('detectedAt');
    if (_id == null || payload.toString() != comparable.toString()) {
      _id = const Uuid().v4();
      final time = DateTime.now().toUtc().toIso8601String();
      _submitted = {...payload, 'locationUpdatedAt': time, 'detectedAt': time};
    }
    setState(() => _busy = true);
    try {
      await context.read<AlertRepository>().create(_id!, _submitted!);
      if (mounted) {
        showOperationMessage(context, 'Conflict alert created.');
        Navigator.pop(context, true);
      }
    } catch (error) {
      if (mounted) showOperationMessage(context, error.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => OperationScaffold(
    title: 'Create conflict alert',
    body: FutureBuilder<List<ParkInfo>>(
      future: _parks,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return FailurePanel(
            snapshot.error.toString(),
            retry: () => setState(() {
              _parks = context.read<ParkRepository>().list();
            }),
          );
        }
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        return ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Form(
              key: _form,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text(
                    'Record an observed high-risk wildlife location for ranger or liaison response.',
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    isExpanded: true,
                    decoration: const InputDecoration(labelText: 'Park'),
                    items: snapshot.data!
                        .map(
                          (park) => DropdownMenuItem(
                            value: park.id,
                            child: Text(park.name),
                          ),
                        )
                        .toList(),
                    validator: requiredText,
                    onChanged: _busy
                        ? null
                        : (id) => setState(() {
                            _park = snapshot.data!.firstWhere(
                              (park) => park.id == id,
                            );
                            _area = null;
                          }),
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    key: ValueKey(_park?.id),
                    isExpanded: true,
                    decoration: const InputDecoration(labelText: 'Area'),
                    items: (_park?.areas ?? [])
                        .map(
                          (area) => DropdownMenuItem(
                            value: area.id,
                            child: Text(area.name),
                          ),
                        )
                        .toList(),
                    validator: requiredText,
                    onChanged: _busy ? null : (area) => _area = area,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _animal,
                    maxLength: 100,
                    decoration: const InputDecoration(labelText: 'Animal'),
                    validator: requiredText,
                  ),
                  TextFormField(
                    controller: _collar,
                    maxLength: 80,
                    decoration: const InputDecoration(
                      labelText: 'Collar reference',
                    ),
                    validator: requiredText,
                  ),
                  DropdownButtonFormField<String>(
                    initialValue: _risk,
                    decoration: const InputDecoration(labelText: 'Risk'),
                    items: ['LOW', 'MEDIUM', 'HIGH']
                        .map(
                          (risk) => DropdownMenuItem(
                            value: risk,
                            child: Text(readable(risk)),
                          ),
                        )
                        .toList(),
                    onChanged: (risk) => _risk = risk!,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _latitude,
                    decoration: const InputDecoration(labelText: 'Latitude'),
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                      signed: true,
                    ),
                    validator: (value) => _number(value, 90),
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _longitude,
                    decoration: const InputDecoration(labelText: 'Longitude'),
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                      signed: true,
                    ),
                    validator: (value) => _number(value, 180),
                  ),
                  const SizedBox(height: 24),
                  FilledButton(
                    onPressed: _busy ? null : _submit,
                    child: Text(_busy ? 'Creating...' : 'Create alert'),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    ),
  );
  String? _number(String? value, double bound) {
    final parsed = double.tryParse(value ?? '');
    return parsed == null || !parsed.isFinite || parsed.abs() > bound
        ? 'Enter a coordinate between -$bound and $bound'
        : null;
  }
}
