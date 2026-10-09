import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import 'package:geolocator/geolocator.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../providers/incident_provider.dart';
import '../utils/constants.dart';
import 'pending_incidents_screen.dart';

class ReportIncidentScreen extends StatefulWidget {
  const ReportIncidentScreen({Key? key}) : super(key: key);

  @override
  State<ReportIncidentScreen> createState() => _ReportIncidentScreenState();
}

class _ReportIncidentScreenState extends State<ReportIncidentScreen> {
  int _currentStep = 1;
  final int _totalSteps = 4;

  // Step 1: Type
  String? _selectedType;
  final List<Map<String, dynamic>> _incidentTypes = [
    {'title': 'Snare', 'subtitle': 'Trap or wire snare', 'icon': Icons.close},
    {'title': 'Injured Animal', 'subtitle': 'Injured or distressed wildlife', 'icon': Icons.healing},
    {'title': 'Carcass', 'subtitle': 'Deceased animal', 'icon': Icons.pest_control_rodent},
    {'title': 'Campsite', 'subtitle': 'Unauthorized campsite', 'icon': Icons.park},
    {'title': 'Poaching', 'subtitle': 'Evidence of poaching', 'icon': Icons.warning},
    {'title': 'Footprints', 'subtitle': 'Tracks or signs of wildlife', 'icon': Icons.pets},
    {'title': 'Other', 'subtitle': 'Another incident type', 'icon': Icons.more_horiz},
  ];

  // Step 2: Evidence
  File? _imageFile;
  final ImagePicker _picker = ImagePicker();

  // Step 3: Details
  final _descriptionController = TextEditingController();
  double? _lat;
  double? _lng;
  bool _gettingLocation = false;

  @override
  void initState() {
    super.initState();
    _fetchLocation();
  }

  @override
  void dispose() {
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _fetchLocation() async {
    setState(() => _gettingLocation = true);
    final provider = Provider.of<IncidentProvider>(context, listen: false);
    Position? position = await provider.getCurrentLocation();
    
    if (position != null) {
      if (!mounted) return;
      setState(() {
        _lat = position.latitude;
        _lng = position.longitude;
      });
    } else {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Weak GPS signal. Cannot determine location automatically.')),
      );
    }
    if (!mounted) return;
    setState(() => _gettingLocation = false);
  }

  Future<void> _takePhoto() async {
    final XFile? photo = await _picker.pickImage(source: ImageSource.camera);
    if (photo != null) {
      if (!mounted) return;
      setState(() {
        _imageFile = File(photo.path);
      });
    }
  }

  void _nextStep() {
    if (_currentStep < _totalSteps) {
      setState(() => _currentStep++);
    }
  }

  void _prevStep() {
    if (_currentStep > 1) {
      setState(() => _currentStep--);
    } else {
      Navigator.pop(context);
    }
  }

  void _submitReport() async {
    if (_selectedType == null || _lat == null || _lng == null || _imageFile == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Missing required information to submit.')),
      );
      return;
    }

    final provider = Provider.of<IncidentProvider>(context, listen: false);
    final success = await provider.reportIncident(
      type: _selectedType!,
      lat: _lat!,
      lng: _lng!,
      description: _descriptionController.text.trim(),
      localImagePath: _imageFile?.path,
    );

    if (success) {
      if (!mounted) return;
      _showSuccessDialog();
    } else {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(provider.errorMessage ?? 'Failed to report'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _showSuccessDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.check_circle_outline, color: AppConstants.primaryGreen, size: 64),
            const SizedBox(height: 16),
            const Text(
              'Report Submitted Successfully',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            const Text(
              'Your wildlife incident report has been synchronized with the central system (or saved offline).',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, color: Colors.grey),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  Navigator.pop(context); // close dialog
                  Navigator.pop(context); // close screen
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppConstants.primaryGreen,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: const Text('Done', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    String stepTitle = '';
    if (_currentStep == 1) stepTitle = 'INCIDENT TYPE';
    if (_currentStep == 2) stepTitle = 'EVIDENCE PHOTO';
    if (_currentStep == 3) stepTitle = 'DETAILS & LOCATION';
    if (_currentStep == 4) stepTitle = 'REVIEW REPORT';

    return Scaffold(
      backgroundColor: AppConstants.background,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: _prevStep,
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Report Incident', style: TextStyle(fontSize: 18)),
            Text(
              'STEP $_currentStep OF $_totalSteps: $stepTitle',
              style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w400, color: Colors.white70),
            ),
          ],
        ),
        backgroundColor: AppConstants.primaryGreen,
        foregroundColor: Colors.white,
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Linear Progress Indicator
            LinearProgressIndicator(
              value: _currentStep / _totalSteps,
              backgroundColor: Colors.grey[300],
              valueColor: const AlwaysStoppedAnimation<Color>(AppConstants.lightGreen),
              minHeight: 4,
            ),
            Expanded(
              child: _buildStepContent(),
            ),
          ],
        ),
      ),
      bottomNavigationBar: _buildBottomBar(),
    );
  }

  Widget _buildStepContent() {
    switch (_currentStep) {
      case 1:
        return _buildStep1();
      case 2:
        return _buildStep2();
      case 3:
        return _buildStep3();
      case 4:
        return _buildStep4();
      default:
        return const SizedBox();
    }
  }

  // STEP 1: Select Incident Type
  Widget _buildStep1() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'What type of incident did you find? *',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppConstants.textDark),
          ),
          const SizedBox(height: 8),
          const Text(
            'Select the option that best describes the incident.',
            style: TextStyle(fontSize: 14, color: Colors.grey),
          ),
          const SizedBox(height: 24),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 16,
              mainAxisSpacing: 16,
              childAspectRatio: 1.1,
            ),
            itemCount: _incidentTypes.length,
            itemBuilder: (context, index) {
              final type = _incidentTypes[index];
              final isSelected = _selectedType == type['title'];
              return InkWell(
                onTap: () => setState(() => _selectedType = type['title']),
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: isSelected ? AppConstants.primaryGreen.withOpacity(0.05) : Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isSelected ? AppConstants.primaryGreen : Colors.grey[300]!,
                      width: isSelected ? 2 : 1,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Icon(type['icon'], color: isSelected ? AppConstants.primaryGreen : Colors.grey[600]),
                          if (isSelected)
                            const Icon(Icons.check_circle, color: AppConstants.primaryGreen, size: 20),
                        ],
                      ),
                      const Spacer(),
                      Text(
                        type['title'],
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: isSelected ? AppConstants.primaryGreen : AppConstants.textDark,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        type['subtitle'],
                        style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  // STEP 2: Capture Evidence
  Widget _buildStep2() {
    return Column(
      children: [
        Expanded(
          child: Container(
            margin: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.grey[200],
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.grey[400]!),
            ),
            child: _imageFile == null
                ? Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.camera_alt, size: 64, color: Colors.grey[500]),
                      const SizedBox(height: 16),
                      const Text(
                        'Capture a clear photo of the incident evidence.',
                        style: TextStyle(color: Colors.grey),
                      ),
                      const SizedBox(height: 24),
                      ElevatedButton.icon(
                        onPressed: _takePhoto,
                        icon: const Icon(Icons.camera, color: Colors.white),
                        label: const Text('TAKE PHOTO', style: TextStyle(color: Colors.white)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppConstants.primaryGreen,
                          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                        ),
                      ),
                    ],
                  )
                : ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        Image.file(_imageFile!, fit: BoxFit.cover),
                        Positioned(
                          bottom: 16,
                          left: 16,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: Colors.black54,
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.location_on, color: Colors.white, size: 14),
                                const SizedBox(width: 4),
                                Text(
                                  _lat != null && _lng != null ? 'Location Captured' : 'Location Unknown',
                                  style: const TextStyle(color: Colors.white, fontSize: 12),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
          ),
        ),
        if (_imageFile != null)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 10.0),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: _takePhoto,
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: AppConstants.primaryGreen),
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: const Text('Retake', style: TextStyle(color: AppConstants.primaryGreen)),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  // STEP 3: Incident Details
  Widget _buildStep3() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Map View
          Container(
            height: 180,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey[300]!),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: _lat != null && _lng != null
                  ? FlutterMap(
                      options: MapOptions(
                        initialCenter: LatLng(_lat!, _lng!),
                        initialZoom: 15,
                        interactionOptions: const InteractionOptions(flags: InteractiveFlag.none),
                      ),
                      children: [
                        TileLayer(
                          urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                          userAgentPackageName: 'com.example.wildlife_conservation_mobile',
                        ),
                        MarkerLayer(
                          markers: [
                            Marker(
                              point: LatLng(_lat!, _lng!),
                              width: 40,
                              height: 40,
                              child: const Icon(Icons.location_pin, color: Colors.red, size: 40),
                            ),
                          ],
                        ),
                      ],
                    )
                  : const Center(child: Text('Location not available')),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              const Icon(Icons.gps_fixed, size: 16, color: Colors.grey),
              const SizedBox(width: 8),
              Text(
                _lat != null && _lng != null ? '${_lat!.toStringAsFixed(5)}° N, ${_lng!.toStringAsFixed(5)}° E' : 'Fetching location...',
                style: const TextStyle(fontSize: 12, color: Colors.grey, fontWeight: FontWeight.bold),
              ),
              const Spacer(),
              if (_gettingLocation)
                const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
              else
                TextButton(
                  onPressed: _fetchLocation,
                  child: const Text('Update Location', style: TextStyle(fontSize: 12)),
                ),
            ],
          ),
          const SizedBox(height: 24),
          
          // Image Preview thumbnail
          const Text('EVIDENCE PHOTO', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey)),
          const SizedBox(height: 8),
          Container(
            height: 100,
            width: double.infinity,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey[300]!),
              image: _imageFile != null
                  ? DecorationImage(image: FileImage(_imageFile!), fit: BoxFit.cover)
                  : null,
            ),
          ),
          const SizedBox(height: 24),

          // Description
          const Text('DESCRIPTION / OBSERVATIONS', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey)),
          const SizedBox(height: 8),
          TextFormField(
            controller: _descriptionController,
            maxLines: 4,
            decoration: InputDecoration(
              hintText: 'Enter any additional details...',
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              filled: true,
              fillColor: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  // STEP 4: Review Report
  Widget _buildStep4() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildReviewCard(
            title: 'INCIDENT TYPE',
            content: _selectedType ?? '',
            icon: Icons.category,
            onEdit: () => setState(() => _currentStep = 1),
          ),
          const SizedBox(height: 16),
          _buildReviewCard(
            title: 'EVIDENCE PHOTO',
            content: 'Photo Captured',
            icon: Icons.camera_alt,
            image: _imageFile,
            onEdit: () => setState(() => _currentStep = 2),
          ),
          const SizedBox(height: 16),
          _buildReviewCard(
            title: 'LOCATION',
            content: _lat != null ? '${_lat!.toStringAsFixed(5)}° N, ${_lng!.toStringAsFixed(5)}° E' : 'Unknown',
            icon: Icons.location_on,
            onEdit: () => setState(() => _currentStep = 3),
          ),
          const SizedBox(height: 16),
          _buildReviewCard(
            title: 'DESCRIPTION',
            content: _descriptionController.text.isNotEmpty ? _descriptionController.text : 'No description provided.',
            icon: Icons.description,
            onEdit: () => setState(() => _currentStep = 3),
          ),
        ],
      ),
    );
  }

  Widget _buildReviewCard({required String title, required String content, required IconData icon, File? image, required VoidCallback onEdit}) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[300]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 16, right: 8, top: 8, bottom: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(title, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.grey)),
                TextButton(
                  onPressed: onEdit,
                  style: TextButton.styleFrom(
                    minimumSize: Size.zero,
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: const Text('Edit', style: TextStyle(fontSize: 12)),
                ),
              ],
            ),
          ),
          const Divider(height: 1, thickness: 1),
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: image != null
                ? Column(
                    children: [
                      Container(
                        height: 120,
                        width: double.infinity,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(8),
                          image: DecorationImage(image: FileImage(image), fit: BoxFit.cover),
                        ),
                      ),
                    ],
                  )
                : Row(
                    children: [
                      Icon(icon, color: AppConstants.primaryGreen, size: 20),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          content,
                          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                        ),
                      ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomBar() {
    final provider = Provider.of<IncidentProvider>(context);
    
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, -5))],
      ),
      child: SafeArea(
        child: _currentStep == _totalSteps
            ? Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () {
                        // "Save for Later" just mimics submission which falls back to offline or we can force offline.
                        // For wireframe accuracy, we just submit. Our logic handles offline safely.
                        _submitReport();
                      },
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: const Text('Save for Later', style: TextStyle(color: Colors.grey)),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    flex: 2,
                    child: ElevatedButton(
                      onPressed: provider.isLoading ? null : _submitReport,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppConstants.primaryGreen,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: provider.isLoading
                          ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                          : const Text('Submit Report →', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    ),
                  ),
                ],
              )
            : ElevatedButton(
                onPressed: () {
                  if (_currentStep == 1 && _selectedType == null) {
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please select an incident type.')));
                    return;
                  }
                  if (_currentStep == 2 && _imageFile == null) {
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please capture an evidence photo.')));
                    return;
                  }
                  _nextStep();
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppConstants.textDark,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: Text(
                  _currentStep == 3 ? 'Continue to Review →' : 'Continue',
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
      ),
    );
  }
}
