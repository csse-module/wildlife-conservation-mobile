import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import '../domain/models.dart';
import '../domain/repositories.dart';
import 'widgets.dart';

class PatrolAssignmentScreen extends StatefulWidget {
  const PatrolAssignmentScreen({super.key});
  @override
  State<PatrolAssignmentScreen> createState() => _PatrolAssignmentScreenState();
}

class _PatrolAssignmentScreenState extends State<PatrolAssignmentScreen> {
  late Future<List<ParkInfo>> _parks;
  Future<(List<PatrolRouteOption>, List<RangerOption>)>? _options;
  String? _park, _route, _ranger, _assignmentId;
  DateTime? _start, _end;
  int _hours = 8;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _parks = context.read<ParkRepository>().list();
  }

  void _selectPark(String? value) {
    _park = value;
    _route = _ranger = null;
    _resetDraft();
    if (value != null) {
      final repository = context.read<PatrolManagementRepository>();
      _options =
          Future.wait([
            repository.routes(value),
            repository.rangers(value),
          ]).then(
            (data) => (
              data[0] as List<PatrolRouteOption>,
              data[1] as List<RangerOption>,
            ),
          );
    }
  }

  void _resetDraft() {
    _assignmentId = null;
    _start = _end = null;
  }

  String _routeLabel(PatrolRouteOption route) {
    final areaId = route.areaId;
    return areaId == null || areaId.trim().isEmpty
        ? route.name
        : '${route.name} · $areaId';
  }

  Future<void> _assign() async {
    if (_route == null || _ranger == null) return;
    _assignmentId ??= const Uuid().v4();
    _start ??= DateTime.now();
    _end ??= _start!.add(Duration(hours: _hours));
    setState(() => _busy = true);
    try {
      await context.read<PatrolManagementRepository>().assign(
        _assignmentId!,
        _route!,
        _ranger!,
        _start!,
        _end!,
      );
      if (!mounted) return;
      showOperationMessage(context, 'Patrol assigned successfully.');
      Navigator.pop(context);
    } catch (error) {
      if (mounted) showOperationMessage(context, error.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => OperationScaffold(
    title: 'Assign patrol',
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
        final parks = snapshot.data!;
        return ListView(
          padding: const EdgeInsets.all(20),
          children: [
            const Text(
              'Select a configured route and a ranger assigned to the same park.',
            ),
            const SizedBox(height: 20),
            DropdownButtonFormField<String>(
              initialValue: _park,
              isExpanded: true,
              decoration: const InputDecoration(labelText: 'Park'),
              items: parks
                  .map(
                    (park) => DropdownMenuItem(
                      value: park.id,
                      child: Text(park.name),
                    ),
                  )
                  .toList(),
              onChanged: _busy
                  ? null
                  : (value) => setState(() => _selectPark(value)),
            ),
            if (parks.isEmpty)
              const Text('Create or assign a park before assigning patrols.'),
            if (_options != null)
              FutureBuilder<(List<PatrolRouteOption>, List<RangerOption>)>(
                future: _options,
                builder: (context, options) {
                  if (options.hasError) {
                    return FailurePanel(
                      options.error.toString(),
                      retry: () => setState(() => _selectPark(_park)),
                    );
                  }
                  if (options.connectionState != ConnectionState.done ||
                      !options.hasData) {
                    return const LinearProgressIndicator();
                  }
                  final (routes, rangers) = options.data!;
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const SizedBox(height: 16),
                      DropdownButtonFormField<String>(
                        key: ValueKey('route-$_park'),
                        initialValue: _route,
                        isExpanded: true,
                        decoration: const InputDecoration(
                          labelText: 'Patrol route',
                        ),
                        items: routes
                            .map(
                              (route) => DropdownMenuItem(
                                value: route.id,
                                child: Text(_routeLabel(route)),
                              ),
                            )
                            .toList(),
                        onChanged: _busy
                            ? null
                            : (value) => setState(() {
                                _route = value;
                                _resetDraft();
                              }),
                      ),
                      if (routes.isEmpty)
                        const Text(
                          'No routes configured for this park. Add a route through the route API or use the demo seed.',
                        ),
                      const SizedBox(height: 16),
                      DropdownButtonFormField<String>(
                        key: ValueKey('ranger-$_park'),
                        initialValue: _ranger,
                        isExpanded: true,
                        decoration: const InputDecoration(labelText: 'Ranger'),
                        items: rangers
                            .map(
                              (ranger) => DropdownMenuItem(
                                value: ranger.id,
                                child: Text(ranger.name),
                              ),
                            )
                            .toList(),
                        onChanged: _busy
                            ? null
                            : (value) => setState(() {
                                _ranger = value;
                                _resetDraft();
                              }),
                      ),
                      if (rangers.isEmpty)
                        const Text(
                          'Create a ranger account for this park first.',
                        ),
                      const SizedBox(height: 16),
                      DropdownButtonFormField<int>(
                        initialValue: _hours,
                        decoration: const InputDecoration(
                          labelText: 'Patrol duration (starting now)',
                        ),
                        items: [2, 4, 8, 12]
                            .map(
                              (hours) => DropdownMenuItem(
                                value: hours,
                                child: Text('$hours hours'),
                              ),
                            )
                            .toList(),
                        onChanged: _busy
                            ? null
                            : (value) => setState(() {
                                _hours = value!;
                                _resetDraft();
                              }),
                      ),
                      const SizedBox(height: 24),
                      FilledButton.icon(
                        onPressed: _busy || _route == null || _ranger == null
                            ? null
                            : _assign,
                        icon: const Icon(Icons.route),
                        label: Text(_busy ? 'Assigning…' : 'Assign patrol'),
                      ),
                    ],
                  );
                },
              ),
          ],
        );
      },
    ),
  );
}
