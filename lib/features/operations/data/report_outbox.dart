import 'dart:async';
import 'dart:convert';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../models/user_model.dart';
import '../../../services/api_exception.dart';
import '../../../services/api_service.dart';
import '../domain/models.dart';

class PendingReport {
  const PendingReport({
    required this.id,
    required this.ownerId,
    required this.kind,
    required this.body,
    this.photoId,
    this.photo,
    this.filename,
    this.error,
  });
  final String id, ownerId;
  final ReportKind kind;
  final Map<String, dynamic> body;
  final String? photoId, photo, filename, error;

  Map<String, dynamic> toJson() => {
    'id': id,
    'ownerId': ownerId,
    'kind': kind.name,
    'body': body,
    'photoId': photoId,
    'photo': photo,
    'filename': filename,
    'error': error,
  };

  factory PendingReport.fromJson(Map<String, dynamic> json) => PendingReport(
    id: json['id'] as String,
    ownerId: json['ownerId'] as String,
    kind: ReportKind.values.byName(json['kind'] as String),
    body: Map<String, dynamic>.from(json['body'] as Map),
    photoId: json['photoId'] as String?,
    photo: json['photo'] as String?,
    filename: json['filename'] as String?,
    error: json['error'] as String?,
  );

  PendingReport withError(String? message) => PendingReport(
    id: id,
    ownerId: ownerId,
    kind: kind,
    body: body,
    photoId: photoId,
    photo: photo,
    filename: filename,
    error: message,
  );
}

abstract interface class ReportOutboxStore {
  Future<List<PendingReport>> read(String ownerId);
  Future<void> write(String ownerId, List<PendingReport> reports);
}

class PreferencesReportOutboxStore implements ReportOutboxStore {
  String _key(String ownerId) => 'field_report_outbox_v1_$ownerId';
  @override
  Future<List<PendingReport>> read(String ownerId) async {
    final preferences = await SharedPreferences.getInstance();
    final raw = preferences.getString(_key(ownerId));
    if (raw == null) return [];
    return (jsonDecode(raw) as List)
        .map(
          (row) =>
              PendingReport.fromJson(Map<String, dynamic>.from(row as Map)),
        )
        .toList();
  }

  @override
  Future<void> write(String ownerId, List<PendingReport> reports) async {
    final encoded = jsonEncode(
      reports.map((report) => report.toJson()).toList(),
    );
    if (reports.length > 20 || utf8.encode(encoded).length > 4 * 1024 * 1024) {
      throw const ApiException(
        'Offline storage is full. Sync or remove saved reports before adding another.',
      );
    }
    final preferences = await SharedPreferences.getInstance();
    if (!await preferences.setString(_key(ownerId), encoded)) {
      throw const ApiException(
        'The report could not be saved on this device. Please retry.',
      );
    }
  }
}

class ReportOutbox extends ChangeNotifier {
  ReportOutbox(this._api, this._store, {bool listenForConnectivity = true}) {
    if (listenForConnectivity) {
      _subscription = Connectivity().onConnectivityChanged.listen((states) {
        if (states.any((state) => state != ConnectivityResult.none)) {
          unawaited(sync());
        }
      });
    }
  }
  final ApiService _api;
  final ReportOutboxStore _store;
  StreamSubscription<List<ConnectivityResult>>? _subscription;
  User? _user;
  List<PendingReport> _pending = [];
  bool _syncing = false, _disposed = false;
  String? _error;
  List<PendingReport> get pending => List.unmodifiable(_pending);
  bool get syncing => _syncing;
  String? get error => _error;

  void setUser(User? user) {
    if (_user?.id == user?.id &&
        _user?.passwordChangeRequired == user?.passwordChangeRequired) {
      return;
    }
    _user = user;
    _pending = [];
    _error = null;
    if (user != null) unawaited(_load(user.id));
  }

  Future<void> _load(String ownerId) async {
    try {
      final reports = await _store.read(ownerId);
      if (_disposed || _user?.id != ownerId) return;
      _pending = reports;
      _notify();
      await sync();
    } catch (_) {
      if (_user?.id == ownerId) {
        _error = 'Cannot read saved reports on this device.';
        _notify();
      }
    }
  }

  Future<bool> submit(PendingReport report) async {
    if (_user?.id != report.ownerId || _user!.passwordChangeRequired) {
      throw const ApiException(
        'Please sign in and complete your password change before reporting.',
      );
    }
    if (_syncing) {
      throw const ApiException(
        'Reports are synchronizing. Please try again shortly.',
      );
    }
    final existing = await _store.read(report.ownerId);
    if (!existing.any((item) => item.id == report.id)) {
      await _store.write(report.ownerId, [...existing, report]);
    }
    final pending = await _store.read(report.ownerId);
    if (_user?.id != report.ownerId) return false;
    _pending = pending;
    _notify();
    await sync();
    return _user?.id == report.ownerId &&
        !_pending.any((item) => item.id == report.id);
  }

  Future<void> sync() async {
    final user = _user;
    if (_syncing || user == null || user.passwordChangeRequired || _disposed) {
      return;
    }
    _syncing = true;
    _error = null;
    _notify();
    try {
      final reports = await _store.read(user.id);
      for (final report in List<PendingReport>.of(reports)) {
        if (_user?.id != user.id || _disposed) break;
        try {
          if (report.photo != null) {
            await _api.uploadImage(
              id: report.photoId!,
              parkId: report.body['parkId'] as String,
              category: report.kind == ReportKind.community
                  ? 'COMMUNITY_REPORT'
                  : 'INCIDENT',
              bytes: Uint8List.fromList(base64Decode(report.photo!)),
              name: report.filename!,
            );
          }
          if (_user?.id != user.id || _disposed) break;
          final resource = report.kind == ReportKind.community
              ? 'community-reports'
              : 'incidents';
          await _api.putData('/$resource/${report.id}', report.body);
          reports.removeWhere((item) => item.id == report.id);
        } on ApiException catch (exception) {
          final index = reports.indexWhere((item) => item.id == report.id);
          reports[index] = report.withError(exception.message);
          _error = exception.message;
          await _store.write(user.id, reports);
          if (exception.canRetry ||
              exception.statusCode == 401 ||
              exception.statusCode == 403) {
            break;
          }
          continue;
        }
        await _store.write(user.id, reports);
      }
      if (_user?.id == user.id) _pending = await _store.read(user.id);
    } catch (_) {
      _error =
          'Saved reports are still on this device. Retry synchronization when connected.';
    } finally {
      _syncing = false;
      _notify();
      if (!_disposed && _user != null && _user!.id != user.id) {
        unawaited(sync());
      }
    }
  }

  Future<void> remove(String id) async {
    final user = _user;
    if (user == null || _syncing) return;
    final reports = (await _store.read(user.id))
      ..removeWhere((report) => report.id == id);
    await _store.write(user.id, reports);
    if (_user?.id == user.id) _pending = reports;
    _notify();
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    unawaited(_subscription?.cancel());
    super.dispose();
  }
}
