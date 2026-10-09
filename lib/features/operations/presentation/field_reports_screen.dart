import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../providers/auth_provider.dart';
import '../data/report_outbox.dart';
import '../domain/models.dart';
import '../domain/repositories.dart';
import 'report_form_screen.dart';
import 'widgets.dart';

class FieldReportsScreen extends StatefulWidget {
  const FieldReportsScreen({
    super.key,
    this.kind = ReportKind.community,
    this.parkId,
  });
  final ReportKind kind;
  final String? parkId;
  @override
  State<FieldReportsScreen> createState() => _FieldReportsScreenState();
}

class _FieldReportsScreenState extends State<FieldReportsScreen> {
  late Future<ResultPage<FieldReport>> _future;
  int _page = 0;
  String? _status;
  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() {
    _future = context.read<FieldReportRepository>().list(
      widget.kind,
      parkId: widget.parkId,
      status: _status,
      page: _page,
    );
  }

  Future<void> _refresh() async {
    setState(_load);
    try {
      await _future;
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final community = widget.kind == ReportKind.community;
    final user = context.watch<AuthProvider>().user;
    return OperationScaffold(
      title: community
          ? (user?.role == 'COMMUNITY_MEMBER'
                ? 'My community reports'
                : 'Community reports')
          : 'Field incidents',
      actions: [
        IconButton(
          onPressed: _refresh,
          icon: const Icon(Icons.refresh),
          tooltip: 'Refresh',
        ),
      ],
      floatingActionButton: community && user?.role == 'COMMUNITY_MEMBER'
          ? FloatingActionButton.extended(
              onPressed: () async {
                await Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const ReportFormScreen()),
                );
                if (mounted) await _refresh();
              },
              icon: const Icon(Icons.add),
              label: const Text('New report'),
            )
          : null,
      body: Column(
        children: [
          if (community)
            Padding(
              padding: const EdgeInsets.all(12),
              child: DropdownButtonFormField<String>(
                initialValue: _status ?? 'ALL',
                decoration: const InputDecoration(labelText: 'Status'),
                items: ['ALL', 'SUBMITTED', 'RESPONDING', 'RESOLVED']
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
          if (context.watch<ReportOutbox>().pending.any(
            (item) => item.kind == widget.kind,
          ))
            const OutboxBanner(),
          Expanded(
            child: FutureBuilder<ResultPage<FieldReport>>(
              future: _future,
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return FailurePanel(
                    snapshot.error.toString(),
                    retry: _refresh,
                  );
                }
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }
                final data = snapshot.data!;
                return RefreshIndicator(
                  onRefresh: _refresh,
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(12, 0, 12, 88),
                    physics: const AlwaysScrollableScrollPhysics(),
                    children: [
                      if (data.items.isEmpty)
                        const Padding(
                          padding: EdgeInsets.all(32),
                          child: Text(
                            'No reports found for this selection.',
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ...data.items.map(
                        (report) => FieldReportTile(
                          report: report,
                          onTap: () async {
                            await Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => FieldReportDetailScreen(
                                  id: report.id,
                                  kind: widget.kind,
                                ),
                              ),
                            );
                            if (mounted) await _refresh();
                          },
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
                          Text(
                            'Page ${_page + 1} · ${data.totalItems} reports',
                          ),
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
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class FieldReportTile extends StatelessWidget {
  const FieldReportTile({super.key, required this.report, required this.onTap});
  final FieldReport report;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => Card(
    child: ListTile(
      isThreeLine: true,
      leading: Icon(
        report.type == 'CROP_DAMAGE' ? Icons.agriculture : Icons.pets,
      ),
      title: Text(readable(report.type)),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${report.village ?? report.areaId} · ${dateLabel(report.occurredAt)}',
          ),
          Text(
            report.description,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          StatusChip(report.status),
        ],
      ),
      trailing: const Icon(Icons.chevron_right),
      onTap: onTap,
    ),
  );
}

class FieldReportDetailScreen extends StatefulWidget {
  const FieldReportDetailScreen({
    super.key,
    required this.id,
    required this.kind,
  });
  final String id;
  final ReportKind kind;
  @override
  State<FieldReportDetailScreen> createState() =>
      _FieldReportDetailScreenState();
}

class _FieldReportDetailScreenState extends State<FieldReportDetailScreen> {
  late Future<FieldReport> _future;
  bool _busy = false;
  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() {
    _future = context.read<FieldReportRepository>().get(widget.kind, widget.id);
  }

  Future<void> _perform(Future<FieldReport> Function() operation) async {
    setState(() => _busy = true);
    try {
      final updated = await operation();
      if (mounted) {
        setState(() {
          _future = Future.value(updated);
        });
      }
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
    title: 'Report details',
    body: FutureBuilder<FieldReport>(
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
        final report = snapshot.data!,
            user = context.watch<AuthProvider>().user;
        final canRespond =
            widget.kind == ReportKind.community &&
            (user?.role == 'RANGER' || user?.role == 'LIAISON_OFFICER');
        return ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Text(
              readable(report.type),
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            Align(
              alignment: Alignment.centerLeft,
              child: StatusChip(report.status),
            ),
            DetailRow('Report ID', report.id),
            DetailRow('Park / area', '${report.parkId} / ${report.areaId}'),
            if (report.village != null) DetailRow('Village', report.village!),
            if (report.species != null) DetailRow('Species', report.species!),
            DetailRow('Observed', dateLabel(report.occurredAt)),
            DetailRow('Description', report.description),
            if (report.cropDetails != null)
              DetailRow('Crop damage', report.cropDetails!),
            if (report.latitude != null)
              DetailRow(
                'Coordinates',
                '${report.latitude}, ${report.longitude}',
              ),
            if (report.photoId != null)
              ProtectedPhoto(
                load: context.read<FieldReportRepository>().photo(
                  report.photoId!,
                ),
              ),
            if (report.assignedOfficerId != null)
              DetailRow('Responding officer', report.assignedOfficerId!),
            if (report.actionTaken != null)
              DetailRow('Action taken', report.actionTaken!),
            if (report.result != null) DetailRow('Outcome', report.result!),
            if (canRespond && report.status == 'SUBMITTED')
              FilledButton.icon(
                onPressed: _busy
                    ? null
                    : () => _perform(
                        () => context.read<FieldReportRepository>().accept(
                          report.id,
                        ),
                      ),
                icon: const Icon(Icons.check_circle_outline),
                label: const Text('Accept report'),
              ),
            if (canRespond &&
                report.status == 'RESPONDING' &&
                report.assignedOfficerId == user?.id)
              FilledButton.icon(
                onPressed: _busy
                    ? null
                    : () async {
                        final response = await responseDialog(context);
                        if (response == null || !mounted) return;
                        await _perform(
                          () => context.read<FieldReportRepository>().resolve(
                            report.id,
                            response.action,
                            response.result,
                          ),
                        );
                      },
                icon: const Icon(Icons.task_alt),
                label: const Text('Record response and resolve'),
              ),
            if (_busy)
              const Padding(
                padding: EdgeInsets.all(12),
                child: LinearProgressIndicator(),
              ),
          ],
        );
      },
    ),
  );
}

class OutboxBanner extends StatelessWidget {
  const OutboxBanner({super.key});
  @override
  Widget build(BuildContext context) {
    final outbox = context.watch<ReportOutbox>();
    if (outbox.pending.isEmpty) return const SizedBox.shrink();
    return Card(
      color: Colors.amber.shade50,
      child: ListTile(
        leading: const Icon(Icons.cloud_upload_outlined),
        title: Text('${outbox.pending.length} reports pending sync'),
        subtitle: const Text('Visible to park operations after delivery.'),
        trailing: const Icon(Icons.chevron_right),
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const ReportOutboxScreen()),
        ),
      ),
    );
  }
}

class ReportOutboxScreen extends StatelessWidget {
  const ReportOutboxScreen({super.key});
  @override
  Widget build(BuildContext context) {
    final outbox = context.watch<ReportOutbox>();
    return OperationScaffold(
      title: 'Pending sync',
      actions: [
        IconButton(
          onPressed: outbox.syncing ? null : outbox.sync,
          icon: const Icon(Icons.sync),
          tooltip: 'Sync saved reports',
        ),
      ],
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (outbox.syncing) const LinearProgressIndicator(),
          if (outbox.error != null)
            Padding(
              padding: const EdgeInsets.all(12),
              child: Text(outbox.error!),
            ),
          if (outbox.pending.isEmpty)
            const Padding(
              padding: EdgeInsets.all(24),
              child: Text('All field reports have been delivered.'),
            ),
          ...outbox.pending.map(
            (report) => Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(readable(report.body['type'] as String)),
                    const StatusChip('PENDING_SYNC'),
                    Text(report.body['description'] as String),
                    Text('Reference: ${report.id}'),
                    if (report.error != null)
                      Text(
                        report.error!,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.error,
                        ),
                      ),
                    TextButton.icon(
                      onPressed: outbox.syncing
                          ? null
                          : () async {
                              final confirmed = await showDialog<bool>(
                                context: context,
                                builder: (context) => AlertDialog(
                                  title: const Text('Discard saved report?'),
                                  content: const Text(
                                    'This removes the local copy. It may already have reached the server if delivery was interrupted.',
                                  ),
                                  actions: [
                                    TextButton(
                                      onPressed: () =>
                                          Navigator.pop(context, false),
                                      child: const Text('Keep'),
                                    ),
                                    TextButton(
                                      onPressed: () =>
                                          Navigator.pop(context, true),
                                      child: const Text('Discard'),
                                    ),
                                  ],
                                ),
                              );
                              if (confirmed == true) {
                                await outbox.remove(report.id);
                              }
                            },
                      icon: const Icon(Icons.delete_outline),
                      label: const Text('Discard local copy'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
