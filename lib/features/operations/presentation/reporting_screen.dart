import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import '../../../services/pdf_export.dart';
import '../domain/models.dart';
import '../domain/repositories.dart';
import 'widgets.dart';

class ReportingScreen extends StatefulWidget {
  const ReportingScreen({super.key, this.parkId});
  final String? parkId;
  @override
  State<ReportingScreen> createState() => _ReportingScreenState();
}

class _ReportingScreenState extends State<ReportingScreen> {
  late Future<List<ParkInfo>> _parks;
  Future<ConservationAnalytics>? _analytics;
  Future<ResultPage<ConservationReport>>? _reports;
  String? _parkId;
  DateTime _to = DateUtils.dateOnly(DateTime.now());
  late DateTime _from;
  String _type = 'MONTHLY_CONSERVATION';
  bool _generating = false;
  int _page = 0;
  String? _generationId, _generationKey;
  @override
  void initState() {
    super.initState();
    _from = _to.subtract(const Duration(days: 29));
    _parkId = widget.parkId;
    _parks = context.read<ParkRepository>().list().then((parks) {
      if (!mounted) return parks;
      _parkId ??= parks.isEmpty ? null : parks.first.id;
      if (_parkId != null) _load();
      return parks;
    });
  }

  void _load() {
    if (_parkId == null) return;
    _analytics = context.read<ReportingRepository>().analytics(
      _parkId!,
      _from,
      _to,
    );
    _reports = context.read<ReportingRepository>().list(_parkId!, page: _page);
  }

  Future<void> _period() async {
    final range = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      initialDateRange: DateTimeRange(start: _from, end: _to),
      helpText: 'Report period (up to 92 days)',
    );
    if (range == null || !mounted) return;
    if (range.end.difference(range.start).inDays >= 92) {
      showOperationMessage(context, 'Select a period of at most 92 days.');
      return;
    }
    setState(() {
      _from = range.start;
      _to = range.end;
      _load();
    });
  }

  Future<void> _generate() async {
    if (_parkId == null) return;
    final key = '$_parkId|$_type|$_from|$_to';
    if (key != _generationKey) {
      _generationKey = key;
      _generationId = const Uuid().v4();
    }
    setState(() => _generating = true);
    try {
      final report = await context.read<ReportingRepository>().generate(
        _generationId!,
        _parkId!,
        _type,
        _from,
        _to,
      );
      _generationId = null;
      _generationKey = null;
      if (!mounted) return;
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ConservationReportScreen(id: report.id),
        ),
      );
      if (mounted) setState(_load);
    } catch (error) {
      if (mounted) showOperationMessage(context, error.toString());
    } finally {
      if (mounted) setState(() => _generating = false);
    }
  }

  @override
  Widget build(BuildContext context) => OperationScaffold(
    title: 'Analytics & reports',
    actions: [
      IconButton(
        onPressed: _parkId == null ? null : () => setState(_load),
        icon: const Icon(Icons.refresh),
        tooltip: 'Refresh',
      ),
    ],
    body: FutureBuilder<List<ParkInfo>>(
      future: _parks,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return FailurePanel(
            snapshot.error.toString(),
            retry: () => setState(() {
              _parks = context.read<ParkRepository>().list().then((parks) {
                _parkId ??= parks.isEmpty ? null : parks.first.id;
                _load();
                return parks;
              });
            }),
          );
        }
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.data!.isEmpty) {
          return const Center(
            child: Text('No parks are assigned to your account.'),
          );
        }
        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            DropdownButtonFormField<String>(
              initialValue: _parkId,
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
              onChanged: _generating
                  ? null
                  : (id) => setState(() {
                      _parkId = id;
                      _page = 0;
                      _load();
                    }),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: _generating ? null : _period,
              icon: const Icon(Icons.date_range),
              label: Text(
                '${dateLabel(_from).substring(0, 10)} - ${dateLabel(_to).substring(0, 10)}',
              ),
            ),
            FutureBuilder<ConservationAnalytics>(
              future: _analytics,
              builder: (context, data) {
                if (data.hasError) {
                  return FailurePanel(
                    data.error.toString(),
                    retry: () => setState(_load),
                  );
                }
                if (!data.hasData) {
                  return const Padding(
                    padding: EdgeInsets.all(24),
                    child: Center(child: CircularProgressIndicator()),
                  );
                }
                return AnalyticsView(data.data!);
              },
            ),
            const SizedBox(height: 16),
            SectionCard(
              title: 'Generate a conservation report',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  DropdownButtonFormField<String>(
                    initialValue: _type,
                    isExpanded: true,
                    decoration: const InputDecoration(labelText: 'Report type'),
                    items:
                        [
                              'MONTHLY_CONSERVATION',
                              'INCIDENTS',
                              'PATROL_COVERAGE',
                              'CONFLICTS',
                            ]
                            .map(
                              (type) => DropdownMenuItem(
                                value: type,
                                child: Text(readable(type)),
                              ),
                            )
                            .toList(),
                    onChanged: _generating
                        ? null
                        : (type) => setState(() => _type = type!),
                  ),
                  const SizedBox(height: 12),
                  FilledButton.icon(
                    onPressed: _generating ? null : _generate,
                    icon: const Icon(Icons.picture_as_pdf),
                    label: Text(
                      _generating ? 'Generating...' : 'Generate report',
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Reports preserve a snapshot of the selected park and period for later download.',
                  ),
                ],
              ),
            ),
            SectionCard(
              title: 'Saved reports',
              child: FutureBuilder<ResultPage<ConservationReport>>(
                future: _reports,
                builder: (context, data) {
                  if (data.hasError) {
                    return FailurePanel(
                      data.error.toString(),
                      retry: () => setState(_load),
                    );
                  }
                  if (!data.hasData) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  return Column(
                    children: [
                      if (data.data!.items.isEmpty)
                        const Text('No reports generated for this park yet.'),
                      ...data.data!.items.map(
                        (report) => ListTile(
                          leading: const Icon(Icons.description_outlined),
                          title: Text(readable(report.type)),
                          subtitle: Text(
                            '${dateLabel(report.from).substring(0, 10)} - ${dateLabel(report.to).substring(0, 10)}',
                          ),
                          trailing: const Icon(Icons.chevron_right),
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) =>
                                  ConservationReportScreen(id: report.id),
                            ),
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
                          Text('Page ${_page + 1}'),
                          TextButton(
                            onPressed: !data.data!.hasMore
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
        );
      },
    ),
  );
}

class AnalyticsView extends StatelessWidget {
  const AnalyticsView(this.data, {super.key});
  final ConservationAnalytics data;
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      if (!data.dataAvailable)
        const Padding(
          padding: EdgeInsets.all(12),
          child: Text(
            'No conservation records in this period. Counts below are zero.',
          ),
        ),
      Wrap(
        spacing: 12,
        runSpacing: 8,
        children: [
          _metric(context, 'Incidents', '${data.totalIncidents}'),
          _metric(context, 'Community reports', '${data.communityReportCount}'),
          _metric(context, 'Resolved alerts', '${data.resolvedAlertCount}'),
          _metric(
            context,
            'Route completion',
            data.coveragePercent == null
                ? 'No assigned routes'
                : '${data.coveragePercent}%',
          ),
        ],
      ),
      SectionCard(
        title: 'Incidents by type',
        child: _counts(data.incidentTypes),
      ),
      SectionCard(
        title: 'Incident hotspots',
        child: data.incidentAreas.isEmpty
            ? const Text('No incident locations in this period.')
            : Column(
                children: data.incidentAreas
                    .map(
                      (area) => ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text(area.name),
                        subtitle: area.hotspot
                            ? const Text(
                                'Potential hotspot: 3 or more incidents',
                              )
                            : null,
                        trailing: Text('${area.count}'),
                      ),
                    )
                    .toList(),
              ),
      ),
      SectionCard(
        title: 'Patrol coverage',
        child: Text(
          '${data.completedRoutes} of ${data.assignedRoutes} assigned routes completed.\nCoverage measures route completion, not geographic area.',
        ),
      ),
      SectionCard(
        title: 'Human-wildlife conflict by type',
        child: _counts(data.communityTypes),
      ),
      SectionCard(
        title: 'Conflict locations',
        child: data.communityAreas.isEmpty
            ? const Text('No community report locations in this period.')
            : Column(
                children: data.communityAreas
                    .map(
                      (area) => ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text(area.name),
                        trailing: Text('${area.count}'),
                      ),
                    )
                    .toList(),
              ),
      ),
      SectionCard(
        title: 'Daily trends',
        child: Column(
          children: [
            _trend('Field incidents', data.incidentDays),
            const SizedBox(height: 16),
            _trend('Community conflicts', data.communityDays),
          ],
        ),
      ),
    ],
  );
  Widget _metric(BuildContext context, String label, String value) => SizedBox(
    width: 220,
    child: Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label),
            const SizedBox(height: 8),
            Text(value, style: Theme.of(context).textTheme.titleLarge),
          ],
        ),
      ),
    ),
  );
  Widget _counts(Map<String, int> counts) => counts.isEmpty
      ? const Text('No records in this period.')
      : Column(
          children: counts.entries
              .map(
                (row) => ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(readable(row.key)),
                  trailing: Text('${row.value}'),
                ),
              )
              .toList(),
        );
  Widget _trend(String label, List<DailyStatistic> days) {
    final active = days.where((day) => day.count > 0).toList();
    final max = active.fold<int>(
      1,
      (value, day) => day.count > value ? day.count : value,
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
        if (active.isEmpty) const Text('No activity in this period.'),
        ...active.map(
          (day) => Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text('${dateLabel(day.date).substring(0, 10)}: ${day.count}'),
                const SizedBox(height: 4),
                LinearProgressIndicator(
                  value: day.count / max,
                  semanticsLabel: '$label on ${day.date}',
                  semanticsValue: '${day.count}',
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class ConservationReportScreen extends StatefulWidget {
  const ConservationReportScreen({super.key, required this.id});
  final String id;
  @override
  State<ConservationReportScreen> createState() =>
      _ConservationReportScreenState();
}

class _ConservationReportScreenState extends State<ConservationReportScreen> {
  late Future<ConservationReport> _future;
  bool _downloading = false;
  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() {
    _future = context.read<ReportingRepository>().get(widget.id);
  }

  Future<void> _download() async {
    setState(() => _downloading = true);
    try {
      final bytes = await context.read<ReportingRepository>().download(
        widget.id,
      );
      final result = await exportPdf(bytes, 'wildlife-report-${widget.id}.pdf');
      if (mounted && result != null) showOperationMessage(context, result);
    } catch (error) {
      if (mounted) showOperationMessage(context, error.toString());
    } finally {
      if (mounted) setState(() => _downloading = false);
    }
  }

  @override
  Widget build(BuildContext context) => OperationScaffold(
    title: 'Conservation report',
    body: FutureBuilder<ConservationReport>(
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
        final report = snapshot.data!;
        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text(
              readable(report.type),
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            DetailRow('Park', report.parkId),
            DetailRow(
              'Period',
              '${dateLabel(report.from).substring(0, 10)} - ${dateLabel(report.to).substring(0, 10)}',
            ),
            DetailRow('Generated', dateLabel(report.generatedAt)),
            DetailRow('Reference', report.id),
            FilledButton.icon(
              onPressed: _downloading ? null : _download,
              icon: const Icon(Icons.download),
              label: Text(_downloading ? 'Downloading...' : 'Download PDF'),
            ),
            if (report.analytics != null) AnalyticsView(report.analytics!),
          ],
        );
      },
    ),
  );
}
