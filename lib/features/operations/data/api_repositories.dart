import 'dart:typed_data';
import 'dart:convert';
import 'package:uuid/uuid.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../services/api_service.dart';
import '../../../services/api_exception.dart';
import '../domain/models.dart';
import '../domain/repositories.dart';

typedef Json = Map<String, dynamic>;

class ApiPatrolManagementRepository implements PatrolManagementRepository {
  ApiPatrolManagementRepository(this._api);
  final ApiService _api;

  Future<List<Json>> _all(String path, Map<String, String> filters) async {
    final result = <Json>[];
    for (var page = 0; ; page++) {
      final data = await _api.getData(path, {
        ...filters,
        'page': '$page',
        'size': '100',
      });
      final items = _rows(data['items']);
      result.addAll(items);
      if (items.isEmpty || result.length >= (data['totalItems'] as int)) {
        return result;
      }
    }
  }

  @override
  Future<List<PatrolRouteOption>> routes(String parkId) async =>
      (await _all('/patrol-routes', {'parkId': parkId}))
          .map(
            (row) => PatrolRouteOption(
              row['id'] as String,
              row['name'] as String,
              row['areaId'] as String,
            ),
          )
          .toList();

  @override
  Future<List<RangerOption>> rangers(String parkId) async =>
      (await _all('/users', {'parkId': parkId, 'role': 'RANGER'}))
          .map(
            (row) => RangerOption(row['id'] as String, row['name'] as String),
          )
          .toList();

  @override
  Future<void> assign(
    String id,
    String routeId,
    String rangerId,
    DateTime start,
    DateTime end,
  ) async {
    await _api.putData('/patrol-assignments/$id', {
      'routeId': routeId,
      'rangerId': rangerId,
      'scheduledStartAt': start.toUtc().toIso8601String(),
      'scheduledEndAt': end.toUtc().toIso8601String(),
    });
  }
}

List<Json> _rows(dynamic value) => (value as List)
    .map((item) => Map<String, dynamic>.from(item as Map))
    .toList();
DateTime _date(dynamic value) => DateTime.parse(value as String);
String _day(DateTime value) => value.toIso8601String().substring(0, 10);

ResultPage<T> _page<T>(dynamic data, T Function(Json) map) {
  final json = data as Json;
  return ResultPage(
    _rows(json['items']).map(map).toList(),
    json['page'] as int,
    json['totalItems'] as int,
  );
}

class ApiParkRepository implements ParkRepository {
  ApiParkRepository(this._api, {this._ownerId});
  final ApiService _api;
  final String? Function()? _ownerId;
  @override
  Future<List<ParkInfo>> list() async {
    final owner = _ownerId?.call();
    final preferences = await SharedPreferences.getInstance();
    try {
      final data = await _api.getData('/parks', {'size': '100'});
      if (owner != null && owner == _ownerId?.call()) {
        await preferences.setString(
          'park_catalog_v1_$owner',
          jsonEncode(data['items']),
        );
      }
      return _rows(data['items']).map(_park).toList();
    } on ApiException catch (error) {
      if (error.canRetry && owner != null && owner == _ownerId?.call()) {
        final cached = preferences.getString('park_catalog_v1_$owner');
        if (cached != null) {
          return _rows(jsonDecode(cached)).map(_park).toList();
        }
      }
      rethrow;
    }
  }

  @override
  Future<List<ParkInfo>> registrationParks() async =>
      _rows(await _api.getData('/auth/registration-parks')).map(_park).toList();
  ParkInfo _park(Json json) => ParkInfo(
    json['id'] as String,
    json['name'] as String,
    _rows(json['areas'] ?? [])
        .map((area) => ParkArea(area['id'] as String, area['name'] as String))
        .toList(),
  );
}

class ApiFieldReportRepository implements FieldReportRepository {
  ApiFieldReportRepository(this._api);
  final ApiService _api;
  String _path(ReportKind kind) =>
      kind == ReportKind.community ? '/community-reports' : '/incidents';
  @override
  Future<ResultPage<FieldReport>> list(
    ReportKind kind, {
    String? parkId,
    String? status,
    int page = 0,
  }) async => _page(
    await _api.getData(_path(kind), {
      'page': '$page',
      'size': '20',
      'parkId': ?parkId,
      if (status != null && kind == ReportKind.community) 'status': status,
    }),
    _report,
  );
  @override
  Future<FieldReport> get(ReportKind kind, String id) async =>
      _report(await _api.getData('${_path(kind)}/$id'));
  @override
  Future<FieldReport> accept(String id) async =>
      _report(await _api.postData('/community-reports/$id/accept'));
  @override
  Future<FieldReport> resolve(
    String id,
    String actionTaken,
    String result,
  ) async => _report(
    await _api.putData('/community-reports/$id/response', {
      'actionTaken': actionTaken,
      'result': result,
    }),
  );
  @override
  Future<Uint8List> photo(String id) => _api.getBytes('/media/$id/content');

  FieldReport _report(Json json) {
    final location = json['location'] as Json?;
    return FieldReport(
      id: json['id'] as String,
      parkId: json['parkId'] as String,
      areaId: json['areaId'] as String,
      type: json['type'] as String,
      description: json['description'] as String,
      occurredAt: _date(json['occurredAt'] ?? json['detectedAt']),
      status: json['status'] as String? ?? 'SUBMITTED',
      reportedBy: json['reportedBy'] as String,
      village: json['village'] as String?,
      species: json['species'] as String?,
      cropDetails: json['cropDetails'] as String?,
      photoId: json['photoId'] as String?,
      latitude: (location?['latitude'] as num?)?.toDouble(),
      longitude: (location?['longitude'] as num?)?.toDouble(),
      assignedOfficerId: json['assignedOfficerId'] as String?,
      actionTaken: json['actionTaken'] as String?,
      result: json['result'] as String?,
    );
  }
}

ConservationAnalytics mapAnalytics(Json json) {
  final coverage = json['patrolCoverage'] as Json? ?? {};
  final conflict = json['communityConflict'] as Json? ?? {};
  List<DailyStatistic> days(dynamic value) => _rows(value ?? [])
      .map((row) => DailyStatistic(_date(row['date']), row['count'] as int))
      .toList();
  List<AreaStatistic> areas(dynamic value, String count) => _rows(value ?? [])
      .map(
        (row) => AreaStatistic(
          row['areaName'] as String,
          row[count] as int,
          hotspot: row['potentialHotspot'] == true,
        ),
      )
      .toList();
  return ConservationAnalytics(
    totalIncidents: json['totalIncidents'] as int,
    communityReportCount: json['communityReportCount'] as int,
    resolvedAlertCount: json['resolvedAlertCount'] as int,
    incidentTypes: {
      for (final row in _rows(json['incidentTypeCounts'] ?? []))
        row['type'] as String: row['count'] as int,
    },
    communityTypes: Map<String, int>.from(conflict['typeCounts'] as Map? ?? {}),
    incidentDays: days(json['dailyIncidentCounts']),
    communityDays: days(conflict['dailyCounts']),
    incidentAreas: areas(json['areaCounts'], 'incidentCount'),
    communityAreas: areas(conflict['areaCounts'], 'reportCount'),
    assignedRoutes: coverage['assignedRouteCount'] as int? ?? 0,
    completedRoutes: coverage['completedRouteCount'] as int? ?? 0,
    coveragePercent: (coverage['coveragePercent'] as num?)?.toDouble(),
    dataAvailable: json['dataAvailable'] == true,
  );
}

class ApiReportingRepository implements ReportingRepository {
  ApiReportingRepository(this._api);
  final ApiService _api;
  @override
  Future<ConservationAnalytics> analytics(
    String parkId,
    DateTime from,
    DateTime to,
  ) async => mapAnalytics(
    await _api.getData('/analytics/summary', {
      'parkId': parkId,
      'from': _day(from),
      'to': _day(to),
    }),
  );
  @override
  Future<ResultPage<ConservationReport>> list(
    String parkId, {
    int page = 0,
  }) async => _page(
    await _api.getData('/reports', {
      'parkId': parkId,
      'page': '$page',
      'size': '20',
    }),
    _report,
  );
  @override
  Future<ConservationReport> get(String id) async =>
      _report(await _api.getData('/reports/$id'));
  @override
  Future<ConservationReport> generate(
    String id,
    String parkId,
    String type,
    DateTime from,
    DateTime to,
  ) async => _report(
    await _api.putData('/reports/$id', {
      'parkId': parkId,
      'reportType': type,
      'from': _day(from),
      'to': _day(to),
      'sections': switch (type) {
        'INCIDENTS' => [
          'INCIDENT_STATISTICS',
          'INCIDENT_TRENDS',
          'HOTSPOT_SUMMARY',
        ],
        'PATROL_COVERAGE' => ['PATROL_COVERAGE'],
        'CONFLICTS' => ['CONFLICT_SUMMARY'],
        _ => [
          'INCIDENT_STATISTICS',
          'INCIDENT_TRENDS',
          'HOTSPOT_SUMMARY',
          'PATROL_COVERAGE',
          'CONFLICT_SUMMARY',
        ],
      },
    }),
  );
  @override
  Future<Uint8List> download(String id) =>
      _api.getBytes('/reports/$id/download');
  ConservationReport _report(Json json) => ConservationReport(
    id: json['id'] as String,
    parkId: json['parkId'] as String,
    type: json['reportType'] as String,
    from: _date(json['from']),
    to: _date(json['to']),
    generatedAt: _date(json['generatedAt']),
    generatedBy: json['generatedBy'] as String? ?? '',
    analytics: json['snapshot'] == null
        ? null
        : mapAnalytics(json['snapshot'] as Json),
  );
}

class ApiAlertRepository implements AlertRepository {
  ApiAlertRepository(this._api);
  final ApiService _api;
  @override
  Future<ResultPage<AlertInfo>> list({
    String? parkId,
    String? status,
    int page = 0,
  }) async => _page(
    await _api.getData('/alerts', {
      'page': '$page',
      'size': '20',
      'parkId': ?parkId,
      'status': ?status,
    }),
    _alert,
  );
  @override
  Future<AlertInfo> get(String id) async =>
      _alert(await _api.getData('/alerts/$id'));
  @override
  Future<AlertInfo> accept(String id) async =>
      _alert(await _api.postData('/alerts/$id/accept'));
  @override
  Future<void> decline(String id, String reason) async {
    await _api.postData('/alerts/$id/decline', {'reason': reason});
  }

  @override
  Future<void> support(String id, String reason) async {
    await _api.postData('/alerts/$id/support', {
      'requestId': const Uuid().v4(),
      'reason': reason,
    });
  }

  @override
  Future<AlertInfo> resolve(
    String id,
    String actionTaken,
    String result,
  ) async => _alert(
    await _api.putData('/alerts/$id/response', {
      'actionTaken': actionTaken,
      'result': result,
    }),
  );
  @override
  Future<void> create(String id, Json payload) async {
    await _api.putData('/alerts/$id', payload);
  }

  AlertInfo _alert(Json json) {
    final location = json['location'] as Json;
    final response = json['response'] as Json?;
    return AlertInfo(
      id: json['id'] as String,
      parkId: json['parkId'] as String,
      areaId: json['areaId'] as String,
      animal: json['animal'] as String,
      collarId: json['collarId'] as String,
      riskLevel: json['riskLevel'] as String,
      status: json['status'] as String,
      detectedAt: _date(json['detectedAt']),
      latitude: (location['latitude'] as num).toDouble(),
      longitude: (location['longitude'] as num).toDouble(),
      supportCount: (json['supportRequests'] as List? ?? []).length,
      assignedOfficerId: json['assignedOfficerId'] as String?,
      actionTaken: response?['actionTaken'] as String?,
      result: response?['result'] as String?,
    );
  }
}

class ApiCameraRepository implements CameraRepository {
  ApiCameraRepository(this._api);
  final ApiService _api;
  @override
  Future<List<CameraTrap>> traps(String parkId) async =>
      _rows(
            (await _api.getData('/camera-traps', {
              'parkId': parkId,
              'size': '100',
            }))['items'],
          )
          .map((row) => CameraTrap(row['id'] as String, row['name'] as String))
          .toList();
  @override
  Future<ResultPage<CameraImage>> images(
    String parkId, {
    String? status,
    int page = 0,
  }) async => _page(
    await _api.getData('/camera-trap-images', {
      'parkId': parkId,
      'page': '$page',
      'size': '20',
      'status': ?status,
    }),
    _image,
  );
  @override
  Future<CameraImage> review(
    String id,
    String species,
    bool possiblePoacher,
    String? notes,
  ) async => _image(
    await _api.putData('/camera-trap-images/$id/review', {
      'species': species,
      'possiblePoacher': possiblePoacher,
      if (notes != null && notes.isNotEmpty) 'notes': notes,
    }),
  );
  @override
  Future<void> upload(
    String id,
    String parkId,
    String trapId,
    Uint8List bytes,
    String filename,
    DateTime capturedAt,
  ) async {
    final mediaId = id;
    await _api.uploadImage(
      id: mediaId,
      parkId: parkId,
      category: 'CAMERA_TRAP',
      bytes: bytes,
      name: filename,
    );
    await _api.putData('/camera-trap-images/$id', {
      'cameraTrapId': trapId,
      'mediaId': mediaId,
      'capturedAt': capturedAt.toUtc().toIso8601String(),
    });
  }

  @override
  Future<Uint8List> photo(String id) => _api.getBytes('/media/$id/content');
  CameraImage _image(Json json) {
    final review = json['review'] as Json?;
    return CameraImage(
      id: json['id'] as String,
      cameraTrapId: json['cameraTrapId'] as String,
      mediaId: json['mediaId'] as String,
      capturedAt: _date(json['capturedAt']),
      status: json['status'] as String,
      species: review?['species'] as String?,
      possiblePoacher: review?['possiblePoacher'] as bool?,
      notes: review?['notes'] as String?,
    );
  }
}
