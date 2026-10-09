import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/admin_provider.dart';
import '../utils/constants.dart';
import 'map_picker_screen.dart';

class AssignPatrolScreen extends StatefulWidget {
  const AssignPatrolScreen({Key? key}) : super(key: key);

  @override
  State<AssignPatrolScreen> createState() => _AssignPatrolScreenState();
}

class _AssignPatrolScreenState extends State<AssignPatrolScreen> {
  final _formKey = GlobalKey<FormState>();
  String? _selectedRanger;
  String? _selectedRoute; // GPS coordinate string
  
  List<Map<String, String>> _rangers = [];
  bool _isLoadingRangers = true;

  @override
  void initState() {
    super.initState();
    _loadRangers();
  }

  Future<void> _loadRangers() async {
    final adminProvider = Provider.of<AdminProvider>(context, listen: false);
    final rangers = await adminProvider.fetchRangers();
    setState(() {
      _rangers = rangers;
      _isLoadingRangers = false;
    });
  }

  void _openMapPicker() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const MapPickerScreen()),
    );
    if (result != null) {
      setState(() {
        _selectedRoute = result as String;
      });
    }
  }

  void _assignPatrol() async {
    if (_formKey.currentState!.validate()) {
      if (_selectedRoute == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please select a route location on the map.')),
        );
        return;
      }
      
      final adminProvider = Provider.of<AdminProvider>(context, listen: false);
      final success = await adminProvider.assignPatrol(
        rangerId: _selectedRanger!,
        routeId: _selectedRoute!,
      );

      if (success) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Patrol Assigned Successfully!'),
            backgroundColor: AppConstants.primaryGreen,
          ),
        );
        Navigator.pop(context);
      } else {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(adminProvider.errorMessage ?? 'Assignment failed.'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppConstants.background,
      appBar: AppBar(
        title: const Text('Assign Patrol'),
        backgroundColor: AppConstants.primaryGreen,
        foregroundColor: Colors.white,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'Patrol Assignment',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: AppConstants.primaryGreen,
                  ),
                ),
                const SizedBox(height: 16),
                
                // Select Ranger
                _isLoadingRangers 
                  ? const Center(child: CircularProgressIndicator())
                  : DropdownButtonFormField<String>(
                      value: _rangers.any((r) => r['id'] == _selectedRanger) ? _selectedRanger : null,
                      decoration: InputDecoration(
                        labelText: 'Select Ranger',
                        prefixIcon: const Icon(Icons.person, color: AppConstants.primaryGreen),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        filled: true,
                        fillColor: Colors.white,
                      ),
                      items: _rangers.isEmpty
                          ? [
                              const DropdownMenuItem<String>(
                                value: null,
                                child: Text('No Rangers Available'),
                              )
                            ]
                          : _rangers.map((ranger) {
                              return DropdownMenuItem<String>(
                                value: ranger['id'],
                                child: Text(ranger['name'] ?? 'Unknown'),
                              );
                            }).toList(),
                      onChanged: _rangers.isEmpty ? null : (value) => setState(() => _selectedRanger = value),
                      validator: (value) => value == null ? 'Please select a ranger' : null,
                    ),
                const SizedBox(height: 16),

                // Select Route Map Picker
                InkWell(
                  onTap: _openMapPicker,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey),
                      borderRadius: BorderRadius.circular(12),
                      color: Colors.white,
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.map, color: AppConstants.primaryGreen),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            _selectedRoute != null ? 'Route: $_selectedRoute' : 'Tap to select Route Location on Map',
                            style: TextStyle(
                              fontSize: 16, 
                              color: _selectedRoute != null ? Colors.black : Colors.grey[700],
                            ),
                          ),
                        ),
                        const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 32),

                Consumer<AdminProvider>(
                  builder: (context, adminProvider, child) {
                    return ElevatedButton(
                      onPressed: adminProvider.isLoading ? null : _assignPatrol,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppConstants.primaryGreen,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: adminProvider.isLoading 
                          ? const SizedBox(
                              height: 24, width: 24, 
                              child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)
                            )
                          : const Text(
                              'ASSIGN PATROL',
                              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                            ),
                    );
                  }
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
