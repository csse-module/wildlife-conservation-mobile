import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../services/api_service.dart';
import '../services/db_helper.dart';
import '../utils/constants.dart';

class SyncScreen extends StatefulWidget {
  const SyncScreen({Key? key}) : super(key: key);

  @override
  State<SyncScreen> createState() => _SyncScreenState();
}

class _SyncScreenState extends State<SyncScreen> {
  final ApiService _apiService = ApiService();
  bool _isLoading = false;
  List<Map<String, dynamic>> _tasks = [];

  @override
  void initState() {
    super.initState();
    _loadTasks();
  }

  Future<void> _loadTasks() async {
    final tasks = await DBHelper.instance.getTasks();
    setState(() {
      _tasks = tasks;
    });
  }

  Future<void> _syncAll() async {
    setState(() => _isLoading = true);

    for (var task in List<Map<String, dynamic>>.from(_tasks)) {
      bool success = false;
      try {
        final id = task['id'];
        final method = task['method'];
        final url = task['url'];
        final String bodyString = task['body'];
        final String? imagePath = task['imagePath'];

        Map<String, dynamic> body = jsonDecode(bodyString);

        if (imagePath != null && imagePath.isNotEmpty) {
          // Upload Image first
          final String photoId = const Uuid().v4().toLowerCase();
          final streamRes = await _apiService.uploadFile('/media/$photoId', imagePath);
          if (streamRes.statusCode == 200 || streamRes.statusCode == 201) {
            body['photoId'] = photoId; // update request body
          } else {
            throw Exception('Image upload failed');
          }
        }

        if (method == 'PUT') {
          final res = await _apiService.put(url, body);
          if (res.statusCode == 200 || res.statusCode == 201) success = true;
        } else if (method == 'POST') {
          final res = await _apiService.post(url, body);
          if (res.statusCode == 200 || res.statusCode == 201) success = true;
        }
        
        if (success) {
          await DBHelper.instance.deleteTask(id);
        }
      } catch (e) {
        debugPrint('Sync failed for task ${task['id']}: $e');
      }
    }

    await _loadTasks();
    
    setState(() => _isLoading = false);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_tasks.isEmpty ? 'All data synchronized!' : 'Some tasks failed to sync.'),
          backgroundColor: _tasks.isEmpty ? AppConstants.primaryGreen : Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppConstants.background,
      appBar: AppBar(
        title: const Text('Offline Sync'),
        backgroundColor: AppConstants.primaryGreen,
        foregroundColor: Colors.white,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _tasks.isEmpty
              ? const Center(child: Text('No offline data to sync.', style: TextStyle(fontSize: 16)))
              : Column(
                  children: [
                    Expanded(
                      child: ListView.builder(
                        itemCount: _tasks.length,
                        itemBuilder: (context, index) {
                          final task = _tasks[index];
                          return Card(
                            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            child: ListTile(
                              leading: Icon(
                                task['type'] == 'PATROL' ? Icons.directions_walk : Icons.warning,
                                color: AppConstants.primaryGreen,
                              ),
                              title: Text('Pending ${task['type']}'),
                              subtitle: Text('Saved locally on ${DateTime.parse(task['created_at']).toLocal()}'),
                              trailing: const Icon(Icons.cloud_upload_outlined),
                            ),
                          );
                        },
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: SizedBox(
                        width: double.infinity,
                        height: 50,
                        child: ElevatedButton.icon(
                          onPressed: _syncAll,
                          icon: const Icon(Icons.sync),
                          label: const Text('Sync All to Server', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppConstants.primaryGreen,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                        ),
                      ),
                    )
                  ],
                ),
    );
  }
}
