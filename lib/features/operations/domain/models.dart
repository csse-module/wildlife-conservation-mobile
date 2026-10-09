class ParkArea {
  const ParkArea(this.id, this.name);
  final String id;
  final String name;
}

class ParkInfo {
  const ParkInfo(this.id, this.name, this.areas);
  final String id;
  final String name;
  final List<ParkArea> areas;
}

class ResultPage<T> {
  const ResultPage(this.items, this.page, this.totalItems);
  final List<T> items;
  final int page;
  final int totalItems;
  bool get hasMore => (page + 1) * 20 < totalItems;
}

enum ReportKind { community, incident }

class FieldReport {
  const FieldReport({
    required this.id,
    required this.parkId,
    required this.areaId,
    required this.type,
    required this.description,
    required this.occurredAt,
    required this.status,
    required this.reportedBy,
    this.village,
    this.species,
    this.cropDetails,
    this.photoId,
    this.latitude,
    this.longitude,
    this.assignedOfficerId,
    this.actionTaken,
    this.result,
  });
  final String id, parkId, areaId, type, description, status, reportedBy;
  final DateTime occurredAt;
  final String? village,
      species,
      cropDetails,
      photoId,
      assignedOfficerId,
      actionTaken,
      result;
  final double? latitude, longitude;
}

class AlertInfo {
  const AlertInfo({
    required this.id,
    required this.parkId,
    required this.areaId,
    required this.animal,
    required this.collarId,
    required this.riskLevel,
    required this.status,
    required this.detectedAt,
    required this.latitude,
    required this.longitude,
    required this.supportCount,
    this.assignedOfficerId,
    this.actionTaken,
    this.result,
  });
  final String id, parkId, areaId, animal, collarId, riskLevel, status;
  final DateTime detectedAt;
  final double latitude, longitude;
  final int supportCount;
  final String? assignedOfficerId, actionTaken, result;
}

class DailyStatistic {
  const DailyStatistic(this.date, this.count);
  final DateTime date;
  final int count;
}

class AreaStatistic {
  const AreaStatistic(this.name, this.count, {this.hotspot = false});
  final String name;
  final int count;
  final bool hotspot;
}

class ConservationAnalytics {
  const ConservationAnalytics({
    required this.totalIncidents,
    required this.communityReportCount,
    required this.resolvedAlertCount,
    required this.incidentTypes,
    required this.communityTypes,
    required this.incidentDays,
    required this.communityDays,
    required this.incidentAreas,
    required this.communityAreas,
    required this.assignedRoutes,
    required this.completedRoutes,
    this.coveragePercent,
    required this.dataAvailable,
  });
  final int totalIncidents,
      communityReportCount,
      resolvedAlertCount,
      assignedRoutes,
      completedRoutes;
  final bool dataAvailable;
  final double? coveragePercent;
  final Map<String, int> incidentTypes, communityTypes;
  final List<DailyStatistic> incidentDays, communityDays;
  final List<AreaStatistic> incidentAreas, communityAreas;
}

class ConservationReport {
  const ConservationReport({
    required this.id,
    required this.parkId,
    required this.type,
    required this.from,
    required this.to,
    required this.generatedAt,
    required this.generatedBy,
    this.analytics,
  });
  final String id, parkId, type, generatedBy;
  final DateTime from, to, generatedAt;
  final ConservationAnalytics? analytics;
}

class CameraTrap {
  const CameraTrap(this.id, this.name);
  final String id, name;
}

class PatrolRouteOption {
  const PatrolRouteOption(this.id, this.name, this.areaId);
  final String id, name;
  final String? areaId;
}

class RangerOption {
  const RangerOption(this.id, this.name);
  final String id, name;
}

class CameraImage {
  const CameraImage({
    required this.id,
    required this.cameraTrapId,
    required this.mediaId,
    required this.capturedAt,
    required this.status,
    this.species,
    this.possiblePoacher,
    this.notes,
  });
  final String id, cameraTrapId, mediaId, status;
  final DateTime capturedAt;
  final String? species, notes;
  final bool? possiblePoacher;
}
