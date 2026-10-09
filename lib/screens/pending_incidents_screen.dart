import 'dart:io';
import 'package:flutter/material.dart';
import '../services/database_helper.dart';
import '../utils/constants.dart';

class PendingIncidentsScreen extends StatefulWidget {
  const PendingIncidentsScreen({super.key});

  @override
  State<PendingIncidentsScreen> createState() => _PendingIncidentsScreenState();
}

class _PendingIncidentsScreenState extends State<PendingIncidentsScreen> {
  List<Map<String, dynamic>> _pendingIncidents = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadPending();
  }

  Future<void> _loadPending() async {
    final dbHelper = DatabaseHelper();
    final incidents = await dbHelper.getPendingIncidents();
    setState(() {
      _pendingIncidents = incidents;
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppConstants.background,
      appBar: AppBar(
        title: const Text('Pending Incidents'),
        backgroundColor: AppConstants.primaryGreen,
        foregroundColor: Colors.white,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _pendingIncidents.isEmpty
              ? const Center(
                  child: Text(
                    'No pending incidents.',
                    style: TextStyle(fontSize: 16, color: Colors.grey),
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _pendingIncidents.length,
                  itemBuilder: (context, index) {
                    final incident = _pendingIncidents[index];
                    final imagePath = incident['imagePath'];
                    
                    return Card(
                      margin: const EdgeInsets.only(bottom: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: ListTile(
                        contentPadding: const EdgeInsets.all(12),
                        leading: imagePath != null && imagePath.isNotEmpty && File(imagePath).existsSync()
                            ? ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: Image.file(
                                  File(imagePath),
                                  width: 60,
                                  height: 60,
                                  fit: BoxFit.cover,
                                ),
                              )
                            : Container(
                                width: 60,
                                height: 60,
                                decoration: BoxDecoration(
                                  color: Colors.grey[200],
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const Icon(Icons.image_not_supported, color: Colors.grey),
                              ),
                        title: Text(
                          incident['type'] ?? 'Unknown Type',
                          style: const TextStyle(fontWeight: FontWeight.bold, color: AppConstants.textDark),
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const SizedBox(height: 4),
                            Text('Lat: ${incident['latitude']}, Lng: ${incident['longitude']}'),
                            const SizedBox(height: 4),
                            Text(
                              incident['timestamp'] != null 
                                  ? DateTime.parse(incident['timestamp']).toLocal().toString().split('.')[0]
                                  : '',
                              style: const TextStyle(fontSize: 12, color: Colors.orange),
                            ),
                          ],
                        ),
                        trailing: const Icon(Icons.cloud_off, color: Colors.orange),
                      ),
                    );
                  },
                ),
    );
  }
}
