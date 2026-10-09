import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import '../../../providers/auth_provider.dart';
import '../data/report_outbox.dart';
import '../domain/models.dart';
import '../domain/repositories.dart';
import 'widgets.dart';

class ReportFormScreen extends StatefulWidget {
  const ReportFormScreen({super.key, this.kind = ReportKind.community});
  final ReportKind kind;
  @override
  State<ReportFormScreen> createState() => _ReportFormScreenState();
}

class _ReportFormScreenState extends State<ReportFormScreen> {
  final _form = GlobalKey<FormState>();
  final _village = TextEditingController(),
      _species = TextEditingController(text: 'Elephant');
  final _crop = TextEditingController(), _description = TextEditingController();
  final _latitude = TextEditingController(),
      _longitude = TextEditingController();
  late Future<List<ParkInfo>> _parks;
  ParkInfo? _park;
  String? _areaId;
  late String _type;
  DateTime _occurredAt = DateTime.now();
  Uint8List? _photo;
  String? _filename;
  String _locationSource = 'MANUAL';
  bool _busy = false, _locating = false;

  bool get _community => widget.kind == ReportKind.community;
  @override
  void initState() {
    super.initState();
    _type = _community ? 'WILDLIFE_SIGHTING' : 'SNARE';
    _parks = context.read<ParkRepository>().list();
  }

  @override
  void dispose() {
    for (final controller in [
      _village,
      _species,
      _crop,
      _description,
      _latitude,
      _longitude,
    ]) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _pickPhoto(ImageSource source) async {
    try {
      final file = await ImagePicker().pickImage(
        source: source,
        maxWidth: 1600,
        maxHeight: 1600,
        imageQuality: 75,
      );
      if (file == null) return;
      final bytes = await file.readAsBytes();
      if (bytes.length > 2 * 1024 * 1024) {
        if (mounted) {
          showOperationMessage(
            context,
            'Choose a JPEG or PNG smaller than 2 MiB.',
          );
        }
        return;
      }
      if (mounted) {
        setState(() {
          _photo = bytes;
          _filename = file.name;
        });
      }
    } catch (_) {
      if (mounted) {
        showOperationMessage(
          context,
          'Photo access is unavailable. Try choosing a file from your gallery.',
        );
      }
    }
  }

  Future<void> _locate() async {
    setState(() => _locating = true);
    try {
      if (!await Geolocator.isLocationServiceEnabled()) {
        throw Exception('disabled');
      }
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        throw Exception('denied');
      }
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 15),
        ),
      );
      if (!mounted) return;
      setState(() {
        _latitude.text = position.latitude.toStringAsFixed(6);
        _longitude.text = position.longitude.toStringAsFixed(6);
        _locationSource = 'GPS';
      });
    } catch (_) {
      if (mounted) {
        showOperationMessage(
          context,
          'GPS is unavailable. You can enter the coordinates manually.',
        );
      }
    } finally {
      if (mounted) setState(() => _locating = false);
    }
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final date = await showDatePicker(
      context: context,
      initialDate: _occurredAt,
      firstDate: DateTime(2020),
      lastDate: now,
    );
    if (date == null || !mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_occurredAt),
    );
    if (time == null || !mounted) return;
    final selected = DateTime(
      date.year,
      date.month,
      date.day,
      time.hour,
      time.minute,
    );
    if (selected.isAfter(DateTime.now())) {
      showOperationMessage(
        context,
        'The observation time cannot be in the future.',
      );
      return;
    }
    setState(() => _occurredAt = selected);
  }

  Future<void> _submit() async {
    if (!_form.currentState!.validate()) return;
    if (_park == null || _areaId == null) {
      showOperationMessage(context, 'Select a park and area.');
      return;
    }
    if (!_community && _photo == null) {
      showOperationMessage(context, 'Attach a photo of the incident.');
      return;
    }
    final user = context.read<AuthProvider>().user;
    if (user == null) return;
    setState(() => _busy = true);
    final photoId = _photo == null ? null : const Uuid().v4();
    final lat = double.tryParse(_latitude.text.trim()),
        lng = double.tryParse(_longitude.text.trim());
    final body = <String, dynamic>{
      'parkId': _park!.id,
      'areaId': _areaId,
      'type': _type,
      'description': _description.text.trim(),
      _community ? 'occurredAt' : 'detectedAt': _occurredAt
          .toUtc()
          .toIso8601String(),
      if (lat != null && lng != null)
        'location': {
          'latitude': lat,
          'longitude': lng,
          'source': _locationSource,
        },
      'photoId': ?photoId,
      if (_community) 'village': _village.text.trim(),
      if (_community && _type == 'WILDLIFE_SIGHTING')
        'species': _species.text.trim(),
      if (_community && _type == 'CROP_DAMAGE')
        'cropDetails': _crop.text.trim(),
    };
    try {
      final sent = await context.read<ReportOutbox>().submit(
        PendingReport(
          id: const Uuid().v4(),
          ownerId: user.id,
          kind: widget.kind,
          body: body,
          photoId: photoId,
          photo: _photo == null ? null : base64Encode(_photo!),
          filename: _filename,
        ),
      );
      if (!mounted) return;
      showOperationMessage(
        context,
        sent
            ? 'Report submitted to park operations.'
            : 'Saved on this device. Check Pending sync for delivery status.',
      );
      Navigator.pop(context, true);
    } catch (error) {
      if (mounted) showOperationMessage(context, error.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  String? _coordinate(
    String? value,
    double limit,
    TextEditingController other,
  ) {
    if (value == null || value.trim().isEmpty) {
      return !_community || other.text.trim().isNotEmpty
          ? 'Enter both coordinates'
          : null;
    }
    final number = double.tryParse(value);
    return number == null || !number.isFinite || number.abs() > limit
        ? 'Enter a value between -$limit and $limit'
        : null;
  }

  @override
  Widget build(BuildContext context) => OperationScaffold(
    title: _community ? 'Report wildlife conflict' : 'Report field incident',
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
        if (parks.isEmpty) {
          return Center(
            child: Text(
              _community
                  ? 'No reporting locations are available yet. Please try again later.'
                  : 'No parks are assigned to your account. Contact your park manager.',
            ),
          );
        }
        return SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Form(
            key: _form,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  _community
                      ? 'Report wildlife sightings or crop damage near your village. Choose the nearest park and area so officers can respond. You do not need a park assignment.'
                      : 'Record evidence with a photo, location and description.',
                ),
                const SizedBox(height: 20),
                DropdownButtonFormField<String>(
                  initialValue: _park?.id,
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
                      : (id) => setState(() {
                          _park = parks.firstWhere((park) => park.id == id);
                          _areaId = null;
                        }),
                  validator: requiredText,
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  key: ValueKey(_park?.id),
                  initialValue: _areaId,
                  isExpanded: true,
                  decoration: const InputDecoration(labelText: 'Park area'),
                  items: (_park?.areas ?? [])
                      .map(
                        (area) => DropdownMenuItem(
                          value: area.id,
                          child: Text(area.name),
                        ),
                      )
                      .toList(),
                  onChanged: _busy
                      ? null
                      : (id) => setState(() => _areaId = id),
                  validator: requiredText,
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  initialValue: _type,
                  isExpanded: true,
                  decoration: const InputDecoration(labelText: 'Report type'),
                  items:
                      (_community
                              ? ['WILDLIFE_SIGHTING', 'CROP_DAMAGE']
                              : [
                                  'SNARE',
                                  'INJURED_ANIMAL',
                                  'ANIMAL_CARCASS',
                                  'ILLEGAL_CAMPSITE',
                                  'POACHING_EVIDENCE',
                                  'ANIMAL_FOOTPRINTS',
                                  'OTHER',
                                ])
                          .map(
                            (type) => DropdownMenuItem(
                              value: type,
                              child: Text(
                                type == 'CROP_DAMAGE'
                                    ? 'Crop raiding / damage'
                                    : readable(type),
                              ),
                            ),
                          )
                          .toList(),
                  onChanged: _busy
                      ? null
                      : (type) => setState(() => _type = type!),
                ),
                if (_community) ...[
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _village,
                    maxLength: 150,
                    decoration: const InputDecoration(labelText: 'Village'),
                    validator: requiredText,
                  ),
                  if (_type == 'WILDLIFE_SIGHTING')
                    TextFormField(
                      controller: _species,
                      maxLength: 100,
                      decoration: const InputDecoration(
                        labelText: 'Animal / species',
                      ),
                      validator: requiredText,
                    ),
                  if (_type == 'CROP_DAMAGE')
                    TextFormField(
                      controller: _crop,
                      maxLength: 500,
                      maxLines: 3,
                      decoration: const InputDecoration(
                        labelText: 'Crop and damage details',
                      ),
                      validator: requiredText,
                    ),
                ],
                const SizedBox(height: 16),
                TextFormField(
                  controller: _description,
                  maxLength: 2000,
                  minLines: 3,
                  maxLines: 6,
                  decoration: const InputDecoration(
                    labelText: 'What happened?',
                  ),
                  validator: requiredText,
                ),
                OutlinedButton.icon(
                  onPressed: _busy ? null : _pickDate,
                  icon: const Icon(Icons.schedule),
                  label: Text('Observed: ${dateLabel(_occurredAt)}'),
                ),
                const SizedBox(height: 12),
                SectionCard(
                  title: _community
                      ? 'Location (optional)'
                      : 'Incident location',
                  child: Column(
                    children: [
                      OutlinedButton.icon(
                        onPressed: _locating || _busy ? null : _locate,
                        icon: const Icon(Icons.my_location),
                        label: Text(
                          _locating
                              ? 'Finding location...'
                              : 'Use my GPS location',
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _latitude,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                          signed: true,
                        ),
                        decoration: const InputDecoration(
                          labelText: 'Latitude',
                        ),
                        onChanged: (_) => _locationSource = 'MANUAL',
                        validator: (value) =>
                            _coordinate(value, 90, _longitude),
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _longitude,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                          signed: true,
                        ),
                        decoration: const InputDecoration(
                          labelText: 'Longitude',
                        ),
                        onChanged: (_) => _locationSource = 'MANUAL',
                        validator: (value) =>
                            _coordinate(value, 180, _latitude),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                SectionCard(
                  title: _community ? 'Photo (optional)' : 'Evidence photo',
                  child: Column(
                    children: [
                      if (_photo != null)
                        Image.memory(_photo!, height: 180, fit: BoxFit.contain),
                      Wrap(
                        spacing: 12,
                        children: [
                          OutlinedButton.icon(
                            onPressed: _busy
                                ? null
                                : () => _pickPhoto(ImageSource.camera),
                            icon: const Icon(Icons.camera_alt),
                            label: const Text('Camera'),
                          ),
                          OutlinedButton.icon(
                            onPressed: _busy
                                ? null
                                : () => _pickPhoto(ImageSource.gallery),
                            icon: const Icon(Icons.photo_library),
                            label: const Text('Gallery'),
                          ),
                          if (_photo != null)
                            TextButton(
                              onPressed: _busy
                                  ? null
                                  : () => setState(() {
                                      _photo = null;
                                      _filename = null;
                                    }),
                              child: const Text('Remove'),
                            ),
                        ],
                      ),
                      const Text(
                        'JPEG / PNG, up to 2 MiB for offline storage.',
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                FilledButton.icon(
                  onPressed: _busy ? null : _submit,
                  icon: const Icon(Icons.send),
                  label: Text(_busy ? 'Saving report...' : 'Submit report'),
                ),
                const SizedBox(height: 8),
                const Text(
                  'When offline, reports are saved on this device and retried when a connection is available.',
                ),
              ],
            ),
          ),
        );
      },
    ),
  );
}
