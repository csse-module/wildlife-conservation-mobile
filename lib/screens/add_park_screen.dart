import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/admin_provider.dart';
import '../utils/constants.dart';

class AddParkScreen extends StatefulWidget {
  const AddParkScreen({Key? key}) : super(key: key);

  @override
  State<AddParkScreen> createState() => _AddParkScreenState();
}

class _AddParkScreenState extends State<AddParkScreen> {
  final _formKey = GlobalKey<FormState>();
  final _idController = TextEditingController();
  final _nameController = TextEditingController();
  final _timezoneController = TextEditingController(text: 'UTC');
  
  final List<Map<String, TextEditingController>> _areas = [];

  @override
  void initState() {
    super.initState();
    // Start with one default area
    _addAreaField();
  }

  @override
  void dispose() {
    _idController.dispose();
    _nameController.dispose();
    _timezoneController.dispose();
    for (var area in _areas) {
      area['id']!.dispose();
      area['name']!.dispose();
    }
    super.dispose();
  }

  void _addAreaField() {
    setState(() {
      _areas.add({
        'id': TextEditingController(),
        'name': TextEditingController(),
      });
    });
  }

  void _removeAreaField(int index) {
    if (_areas.length > 1) {
      setState(() {
        _areas[index]['id']!.dispose();
        _areas[index]['name']!.dispose();
        _areas.removeAt(index);
      });
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('A park must have at least one area.')),
      );
    }
  }

  void _submit() async {
    if (_formKey.currentState!.validate()) {
      final adminProvider = Provider.of<AdminProvider>(context, listen: false);
      
      final areas = _areas.map((e) => {
        'id': e['id']!.text.trim(),
        'name': e['name']!.text.trim(),
      }).toList();

      final success = await adminProvider.addPark(
        id: _idController.text.trim(),
        name: _nameController.text.trim(),
        timezone: _timezoneController.text.trim(),
        areas: areas,
      );

      if (success) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Park successfully added!', style: TextStyle(color: Colors.white)), backgroundColor: Colors.green),
        );
        Navigator.pop(context);
      } else {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(adminProvider.errorMessage ?? 'Failed to add park.'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final adminProvider = Provider.of<AdminProvider>(context);

    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9), // Light background
      appBar: AppBar(
        title: const Text('Add New Park'),
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
                  'Park Details',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: AppConstants.primaryGreen,
                  ),
                ),
                const SizedBox(height: 16),
                
                // Park ID
                TextFormField(
                  controller: _idController,
                  decoration: InputDecoration(
                    labelText: 'Park ID (e.g. park-yala)',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    prefixIcon: const Icon(Icons.badge_outlined, color: AppConstants.primaryGreen),
                    filled: true,
                    fillColor: Colors.white,
                  ),
                  validator: (value) => value == null || value.isEmpty ? 'Park ID is required' : null,
                ),
                const SizedBox(height: 16),

                // Park Name
                TextFormField(
                  controller: _nameController,
                  decoration: InputDecoration(
                    labelText: 'Park Name (e.g. Yala National Park)',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    prefixIcon: const Icon(Icons.park_outlined, color: AppConstants.primaryGreen),
                    filled: true,
                    fillColor: Colors.white,
                  ),
                  validator: (value) => value == null || value.isEmpty ? 'Park Name is required' : null,
                ),
                const SizedBox(height: 16),

                // Timezone
                TextFormField(
                  controller: _timezoneController,
                  decoration: InputDecoration(
                    labelText: 'Timezone (e.g. UTC, Asia/Colombo)',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    prefixIcon: const Icon(Icons.access_time, color: AppConstants.primaryGreen),
                    filled: true,
                    fillColor: Colors.white,
                  ),
                  validator: (value) => value == null || value.isEmpty ? 'Timezone is required' : null,
                ),
                
                const SizedBox(height: 32),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Park Areas',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: AppConstants.primaryGreen,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.add_circle),
                      color: AppConstants.primaryGreen,
                      onPressed: _addAreaField,
                      tooltip: 'Add Area',
                    ),
                  ],
                ),
                const SizedBox(height: 8),

                // Dynamic Area Fields
                ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: _areas.length,
                  itemBuilder: (context, index) {
                    return Card(
                      margin: const EdgeInsets.only(bottom: 16),
                      child: Padding(
                        padding: const EdgeInsets.all(12.0),
                        child: Column(
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text('Area ${index + 1}', style: const TextStyle(fontWeight: FontWeight.bold)),
                                IconButton(
                                  icon: const Icon(Icons.delete, color: Colors.red),
                                  onPressed: () => _removeAreaField(index),
                                ),
                              ],
                            ),
                            TextFormField(
                              controller: _areas[index]['id'],
                              decoration: InputDecoration(
                                labelText: 'Area ID (e.g. block-1)',
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                                isDense: true,
                                filled: true,
                                fillColor: Colors.white,
                              ),
                              validator: (value) => value == null || value.isEmpty ? 'Area ID required' : null,
                            ),
                            const SizedBox(height: 8),
                            TextFormField(
                              controller: _areas[index]['name'],
                              decoration: InputDecoration(
                                labelText: 'Area Name (e.g. Block 1)',
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                                isDense: true,
                                filled: true,
                                fillColor: Colors.white,
                              ),
                              validator: (value) => value == null || value.isEmpty ? 'Area Name required' : null,
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
                
                const SizedBox(height: 32),
                ElevatedButton(
                  onPressed: adminProvider.isLoading ? null : _submit,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppConstants.primaryGreen, // Green
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: adminProvider.isLoading
                      ? const SizedBox(
                          height: 24,
                          width: 24,
                          child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                        )
                      : const Text(
                          'CREATE PARK',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
