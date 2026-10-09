import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import '../domain/models.dart';
import '../domain/repositories.dart';
import 'widgets.dart';

class CameraImagesScreen extends StatefulWidget {
  const CameraImagesScreen({super.key, this.parkId});
  final String? parkId;
  @override
  State<CameraImagesScreen> createState() => _CameraImagesScreenState();
}

class _CameraImagesScreenState extends State<CameraImagesScreen> {
  late Future<List<ParkInfo>> _parks;
  Future<ResultPage<CameraImage>>? _images;
  String? _parkId, _status;
  int _page = 0;
  @override
  void initState() {
    super.initState();
    _parkId = widget.parkId;
    _loadParks();
  }

  void _loadParks() {
    _parks = context.read<ParkRepository>().list().then((parks) {
      _parkId ??= parks.isEmpty ? null : parks.first.id;
      if (mounted) _load();
      return parks;
    });
  }

  void _load() {
    if (_parkId != null) {
      _images = context.read<CameraRepository>().images(
        _parkId!,
        status: _status,
        page: _page,
      );
    }
  }

  @override
  Widget build(BuildContext context) => OperationScaffold(
    title: 'Camera trap monitoring',
    actions: [
      IconButton(
        onPressed: _parkId == null ? null : () => setState(_load),
        icon: const Icon(Icons.refresh),
        tooltip: 'Refresh',
      ),
    ],
    floatingActionButton: _parkId == null
        ? null
        : FloatingActionButton.extended(
            onPressed: () async {
              await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => CameraUploadScreen(parkId: _parkId!),
                ),
              );
              if (mounted) setState(_load);
            },
            icon: const Icon(Icons.add_a_photo),
            label: const Text('Upload image'),
          ),
    body: FutureBuilder<List<ParkInfo>>(
      future: _parks,
      builder: (context, parks) {
        if (parks.hasError) {
          return FailurePanel(
            parks.error.toString(),
            retry: () => setState(_loadParks),
          );
        }
        if (!parks.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        if (parks.data!.isEmpty) {
          return const Center(
            child: Text('No parks are assigned to this account.'),
          );
        }
        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                children: [
                  DropdownButtonFormField<String>(
                    initialValue: _parkId,
                    isExpanded: true,
                    decoration: const InputDecoration(labelText: 'Park'),
                    items: parks.data!
                        .map(
                          (park) => DropdownMenuItem(
                            value: park.id,
                            child: Text(park.name),
                          ),
                        )
                        .toList(),
                    onChanged: (id) => setState(() {
                      _parkId = id;
                      _page = 0;
                      _load();
                    }),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    initialValue: _status ?? 'ALL',
                    decoration: const InputDecoration(
                      labelText: 'Review status',
                    ),
                    items: ['ALL', 'PENDING_REVIEW', 'REVIEWED']
                        .map(
                          (status) => DropdownMenuItem(
                            value: status,
                            child: Text(readable(status)),
                          ),
                        )
                        .toList(),
                    onChanged: (status) => setState(() {
                      _status = status == 'ALL' ? null : status;
                      _page = 0;
                      _load();
                    }),
                  ),
                ],
              ),
            ),
            Expanded(
              child: FutureBuilder<ResultPage<CameraImage>>(
                future: _images,
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
                          padding: EdgeInsets.all(24),
                          child: Text(
                            'No camera images found for this selection.',
                          ),
                        ),
                      ...data.items.map(
                        (image) => Card(
                          child: ListTile(
                            leading: Icon(
                              image.possiblePoacher == true
                                  ? Icons.person_search
                                  : Icons.camera_outdoor,
                            ),
                            title: Text(
                              image.species ?? 'Unreviewed camera image',
                            ),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '${image.cameraTrapId} · ${dateLabel(image.capturedAt)}',
                                ),
                                StatusChip(image.status),
                                if (image.possiblePoacher == true)
                                  Text(
                                    'Possible poacher flagged',
                                    style: TextStyle(
                                      color: Theme.of(
                                        context,
                                      ).colorScheme.error,
                                    ),
                                  ),
                              ],
                            ),
                            trailing: const Icon(Icons.chevron_right),
                            onTap: () async {
                              await Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) =>
                                      CameraReviewScreen(image: image),
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
                          Text('Page ${_page + 1} · ${data.totalItems} images'),
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
        );
      },
    ),
  );
}

class CameraReviewScreen extends StatefulWidget {
  const CameraReviewScreen({super.key, required this.image});
  final CameraImage image;
  @override
  State<CameraReviewScreen> createState() => _CameraReviewScreenState();
}

class _CameraReviewScreenState extends State<CameraReviewScreen> {
  final _form = GlobalKey<FormState>();
  late TextEditingController _species, _notes;
  late Future<Uint8List> _photo;
  late CameraImage _image;
  bool _poacher = false, _busy = false;
  @override
  void initState() {
    super.initState();
    _image = widget.image;
    _species = TextEditingController(text: _image.species ?? 'Unknown');
    _notes = TextEditingController(text: _image.notes ?? '');
    _poacher = _image.possiblePoacher ?? false;
    _photo = context.read<CameraRepository>().photo(_image.mediaId);
  }

  @override
  void dispose() {
    _species.dispose();
    _notes.dispose();
    super.dispose();
  }

  Future<void> _review() async {
    if (!_form.currentState!.validate()) return;
    setState(() => _busy = true);
    try {
      final updated = await context.read<CameraRepository>().review(
        _image.id,
        _species.text.trim(),
        _poacher,
        _notes.text.trim(),
      );
      if (mounted) {
        setState(() => _image = updated);
        showOperationMessage(context, 'Camera image review saved.');
      }
    } catch (error) {
      if (mounted) showOperationMessage(context, error.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => OperationScaffold(
    title: 'Review camera image',
    body: ListView(
      padding: const EdgeInsets.all(20),
      children: [
        ProtectedPhoto(load: _photo),
        const SizedBox(height: 16),
        StatusChip(_image.status),
        DetailRow('Camera trap', _image.cameraTrapId),
        DetailRow('Captured', dateLabel(_image.capturedAt)),
        if (_image.status == 'REVIEWED') ...[
          DetailRow('Species', _image.species ?? 'Unknown'),
          DetailRow(
            'Possible poacher',
            _image.possiblePoacher == true ? 'Yes' : 'No',
          ),
          if (_image.notes != null) DetailRow('Review notes', _image.notes!),
          const Text('This final review has been saved.'),
        ] else
          Form(
            key: _form,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextFormField(
                  controller: _species,
                  maxLength: 100,
                  decoration: const InputDecoration(
                    labelText: 'Identified species',
                  ),
                  validator: requiredText,
                ),
                CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  value: _poacher,
                  onChanged: _busy
                      ? null
                      : (value) => setState(() => _poacher = value!),
                  title: const Text('Possible poacher visible'),
                  subtitle: const Text(
                    'Flag suspicious human activity for staff review.',
                  ),
                ),
                TextFormField(
                  controller: _notes,
                  maxLength: 2000,
                  minLines: 2,
                  maxLines: 5,
                  decoration: const InputDecoration(
                    labelText: 'Review notes (optional)',
                  ),
                ),
                const SizedBox(height: 16),
                FilledButton.icon(
                  onPressed: _busy ? null : _review,
                  icon: const Icon(Icons.fact_check),
                  label: Text(_busy ? 'Saving...' : 'Save final review'),
                ),
              ],
            ),
          ),
      ],
    ),
  );
}

class CameraUploadScreen extends StatefulWidget {
  const CameraUploadScreen({super.key, required this.parkId});
  final String parkId;
  @override
  State<CameraUploadScreen> createState() => _CameraUploadScreenState();
}

class _CameraUploadScreenState extends State<CameraUploadScreen> {
  late Future<List<CameraTrap>> _traps;
  final _form = GlobalKey<FormState>();
  String? _trapId, _filename;
  Uint8List? _bytes;
  String _id = const Uuid().v4();
  DateTime _captured = DateTime.now();
  bool _busy = false;
  @override
  void initState() {
    super.initState();
    _traps = context.read<CameraRepository>().traps(widget.parkId);
  }

  Future<void> _choose() async {
    try {
      final file = await ImagePicker().pickImage(
        source: ImageSource.gallery,
        maxWidth: 2400,
        maxHeight: 2400,
        imageQuality: 85,
      );
      if (file == null) return;
      final bytes = await file.readAsBytes();
      if (bytes.length > 5 * 1024 * 1024) {
        if (mounted) {
          showOperationMessage(context, 'Choose an image smaller than 5 MiB.');
        }
        return;
      }
      if (mounted) {
        setState(() {
          _bytes = bytes;
          _filename = file.name;
          _id = const Uuid().v4();
        });
      }
    } catch (_) {
      if (mounted) {
        showOperationMessage(context, 'Could not open the image picker.');
      }
    }
  }

  Future<void> _upload() async {
    if (!_form.currentState!.validate()) return;
    if (_bytes == null) {
      showOperationMessage(context, 'Choose a camera trap image.');
      return;
    }
    setState(() => _busy = true);
    try {
      await context.read<CameraRepository>().upload(
        _id,
        widget.parkId,
        _trapId!,
        _bytes!,
        _filename!,
        _captured,
      );
      if (mounted) {
        showOperationMessage(context, 'Camera image uploaded for review.');
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
    title: 'Upload camera trap image',
    body: FutureBuilder<List<CameraTrap>>(
      future: _traps,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return FailurePanel(
            snapshot.error.toString(),
            retry: () => setState(() {
              _traps = context.read<CameraRepository>().traps(widget.parkId);
            }),
          );
        }
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.data!.isEmpty) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: Text('No camera traps are configured for this park.'),
            ),
          );
        }
        return ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Form(
              key: _form,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  DropdownButtonFormField<String>(
                    isExpanded: true,
                    decoration: const InputDecoration(labelText: 'Camera trap'),
                    items: snapshot.data!
                        .map(
                          (trap) => DropdownMenuItem(
                            value: trap.id,
                            child: Text(trap.name),
                          ),
                        )
                        .toList(),
                    validator: requiredText,
                    onChanged: _busy
                        ? null
                        : (id) {
                            _trapId = id;
                            _id = const Uuid().v4();
                          },
                  ),
                  const SizedBox(height: 16),
                  OutlinedButton.icon(
                    onPressed: _busy
                        ? null
                        : () async {
                            final date = await showDatePicker(
                              context: context,
                              initialDate: _captured,
                              firstDate: DateTime(2020),
                              lastDate: DateTime.now(),
                            );
                            if (date == null || !context.mounted) return;
                            final time = await showTimePicker(
                              context: context,
                              initialTime: TimeOfDay.fromDateTime(_captured),
                            );
                            if (time == null || !context.mounted) return;
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
                                'Capture time cannot be in the future.',
                              );
                              return;
                            }
                            setState(() {
                              _captured = selected;
                              _id = const Uuid().v4();
                            });
                          },
                    icon: const Icon(Icons.schedule),
                    label: Text('Captured: ${dateLabel(_captured)}'),
                  ),
                  if (_bytes != null)
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Image.memory(_bytes!, height: 220),
                    ),
                  OutlinedButton.icon(
                    onPressed: _busy ? null : _choose,
                    icon: const Icon(Icons.image_outlined),
                    label: const Text('Choose image'),
                  ),
                  const SizedBox(height: 20),
                  FilledButton.icon(
                    onPressed: _busy ? null : _upload,
                    icon: const Icon(Icons.upload),
                    label: Text(_busy ? 'Uploading...' : 'Upload for review'),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    ),
  );
}
