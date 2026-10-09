import 'dart:convert';
import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../utils/constants.dart';
import 'ranger_details_screen.dart';

class RangersListScreen extends StatefulWidget {
  const RangersListScreen({super.key});

  @override
  State<RangersListScreen> createState() => _RangersListScreenState();
}

class _RangersListScreenState extends State<RangersListScreen> {
  final ApiService _apiService = ApiService();
  bool _isLoading = true;
  List<dynamic> _rangers = [];
  final Set<String> _busyRangerIds = {};

  @override
  void initState() {
    super.initState();
    _fetchData();
  }

  Future<void> _fetchData() async {
    setState(() => _isLoading = true);
    try {
      // Fetch all rangers
      final rangersResponse = await _apiService.get('/users?role=RANGER&size=100');
      if (rangersResponse.statusCode == 200) {
        final data = jsonDecode(rangersResponse.body);
        _rangers = data['data']['items'] ?? [];
      }

      // Fetch pending assignments to determine who is on patrol
      final assignmentsResponse = await _apiService.get('/patrol-assignments?size=100');
      if (assignmentsResponse.statusCode == 200) {
        final data = jsonDecode(assignmentsResponse.body);
        final assignments = data['data']['items'] ?? [];
        for (var assignment in assignments) {
          if (assignment['isCompleted'] != true) {
            _busyRangerIds.add(assignment['rangerId']);
          }
        }
      }
    } catch (e) {
      debugPrint('Error fetching rangers list: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppConstants.background,
      appBar: AppBar(
        title: const Text('Track Rangers'),
        backgroundColor: AppConstants.primaryGreen,
        foregroundColor: Colors.white,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _rangers.isEmpty
              ? const Center(child: Text('No Rangers found.'))
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _rangers.length,
                  itemBuilder: (context, index) {
                    final ranger = _rangers[index];
                    final isBusy = _busyRangerIds.contains(ranger['id']);
                    
                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: isBusy ? Colors.orange : AppConstants.primaryGreen,
                          child: const Icon(Icons.person, color: Colors.white),
                        ),
                        title: Text(ranger['name'] ?? 'Unknown Ranger', style: const TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: Text((ranger['role'] ?? 'RANGER').toString().replaceAll('_', ' ')),
                        trailing: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: isBusy ? Colors.orange.withValues(alpha: 0.1) : AppConstants.primaryGreen.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            isBusy ? 'On Patrol' : 'Available',
                            style: TextStyle(
                              color: isBusy ? Colors.orange : AppConstants.primaryGreen,
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          ),
                        ),
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => RangerDetailsScreen(
                                rangerId: ranger['id'] ?? '',
                                rangerName: ranger['name'] ?? 'Unknown Ranger',
                              ),
                            ),
                          );
                        },
                      ),
                    );
                  },
                ),
    );
  }
}
