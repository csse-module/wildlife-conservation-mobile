import 'dart:typed_data';
import 'models.dart';

abstract interface class ParkRepository {
  Future<List<ParkInfo>> list();
  Future<List<ParkInfo>> registrationParks();
}

abstract interface class PatrolManagementRepository {
  Future<List<PatrolRouteOption>> routes(String parkId);
  Future<List<RangerOption>> rangers(String parkId);
  Future<void> assign(
    String id,
    String routeId,
    String rangerId,
    DateTime start,
    DateTime end,
  );
}

abstract interface class FieldReportRepository {
  Future<ResultPage<FieldReport>> list(
    ReportKind kind, {
    String? parkId,
    String? status,
    int page = 0,
  });
  Future<FieldReport> get(ReportKind kind, String id);
  Future<FieldReport> accept(String id);
  Future<FieldReport> resolve(String id, String actionTaken, String result);
  Future<Uint8List> photo(String id);
}

abstract interface class ReportingRepository {
  Future<ConservationAnalytics> analytics(
    String parkId,
    DateTime from,
    DateTime to,
  );
  Future<ResultPage<ConservationReport>> list(String parkId, {int page = 0});
  Future<ConservationReport> get(String id);
  Future<ConservationReport> generate(
    String id,
    String parkId,
    String type,
    DateTime from,
    DateTime to,
  );
  Future<Uint8List> download(String id);
}

abstract interface class AlertRepository {
  Future<ResultPage<AlertInfo>> list({
    String? parkId,
    String? status,
    int page = 0,
  });
  Future<AlertInfo> get(String id);
  Future<AlertInfo> accept(String id);
  Future<void> decline(String id, String reason);
  Future<void> support(String id, String reason);
  Future<AlertInfo> resolve(String id, String actionTaken, String result);
  Future<void> create(String id, Map<String, dynamic> payload);
}

abstract interface class CameraRepository {
  Future<List<CameraTrap>> traps(String parkId);
  Future<ResultPage<CameraImage>> images(
    String parkId, {
    String? status,
    int page = 0,
  });
  Future<CameraImage> review(
    String id,
    String species,
    bool possiblePoacher,
    String? notes,
  );
  Future<void> upload(
    String id,
    String parkId,
    String trapId,
    Uint8List bytes,
    String filename,
    DateTime capturedAt,
  );
  Future<Uint8List> photo(String id);
}
