import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../utils/constants.dart';

class ServerConfigDialog extends StatefulWidget {
  const ServerConfigDialog({super.key});

  static Future<void> show(BuildContext context) {
    return showDialog(
      context: context,
      builder: (_) => const ServerConfigDialog(),
    );
  }

  @override
  State<ServerConfigDialog> createState() => _ServerConfigDialogState();
}

class _ServerConfigDialogState extends State<ServerConfigDialog> {
  late final TextEditingController _urlController;
  final ApiService _apiService = ApiService();
  bool _testing = false;
  String? _testResult;
  bool? _testSuccess;

  @override
  void initState() {
    super.initState();
    _urlController = TextEditingController(
      text: ApiService.customBaseUrl ?? AppConstants.baseUrl,
    );
  }

  @override
  void dispose() {
    _urlController.dispose();
    super.dispose();
  }

  Future<void> _testConnection() async {
    setState(() {
      _testing = true;
      _testResult = null;
      _testSuccess = null;
    });

    final target = _urlController.text.trim();
    final reachable = await _apiService.testConnection(target);

    if (!mounted) return;
    setState(() {
      _testing = false;
      _testSuccess = reachable;
      _testResult = reachable
          ? 'Connected! Backend is reachable.'
          : 'Cannot reach server. If using USB debugging, run "adb reverse tcp:8080 tcp:8080".';
    });
  }

  Future<void> _save() async {
    final target = _urlController.text.trim();
    if (target.isNotEmpty) {
      await ApiService.setCustomBaseUrl(target);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Server URL set to: $target'),
          backgroundColor: AppConstants.primaryGreen,
        ),
      );
      Navigator.pop(context);
    }
  }

  void _selectPreset(String presetUrl) {
    setState(() {
      _urlController.text = presetUrl;
      _testResult = null;
      _testSuccess = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Row(
        children: [
          Icon(Icons.settings_ethernet, color: AppConstants.primaryGreen),
          SizedBox(width: 8),
          Text('Server Connection'),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Select a preset or enter the backend URL:',
              style: TextStyle(fontSize: 13, color: AppConstants.textLight),
            ),
            const SizedBox(height: 12),

            // Presets
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                ActionChip(
                  avatar: const Icon(Icons.cloud_done, size: 16),
                  label: const Text('Render Cloud', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                  onPressed: () => _selectPreset(AppConstants.hostedRenderBaseUrl),
                ),
                ActionChip(
                  avatar: const Icon(Icons.usb, size: 16),
                  label: const Text('USB Debugging', style: TextStyle(fontSize: 12)),
                  onPressed: () => _selectPreset(AppConstants.usbDebugBaseUrl),
                ),
                ActionChip(
                  avatar: const Icon(Icons.wifi, size: 16),
                  label: const Text('Wi-Fi (192.168.8.100)', style: TextStyle(fontSize: 12)),
                  onPressed: () => _selectPreset(AppConstants.currentLanBaseUrl),
                ),
                ActionChip(
                  avatar: const Icon(Icons.dns, size: 16),
                  label: const Text('LAN (192.168.8.102)', style: TextStyle(fontSize: 12)),
                  onPressed: () => _selectPreset(AppConstants.lanDeployedBaseUrl),
                ),
                ActionChip(
                  avatar: const Icon(Icons.phone_android, size: 16),
                  label: const Text('Emulator (10.0.2.2)', style: TextStyle(fontSize: 12)),
                  onPressed: () => _selectPreset(AppConstants.localBaseUrl),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // URL Input
            TextField(
              controller: _urlController,
              decoration: const InputDecoration(
                labelText: 'Backend Base URL',
                hintText: 'https://wildlife-conservation-backend-5nkw.onrender.com',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.link, color: AppConstants.primaryGreen),
              ),
            ),
            const SizedBox(height: 12),

            // Test Connection Button
            OutlinedButton.icon(
              onPressed: _testing ? null : _testConnection,
              icon: _testing
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.network_check, size: 18),
              label: Text(_testing ? 'Testing connection…' : 'Test Connection'),
            ),

            if (_testResult != null) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: _testSuccess == true
                      ? Colors.green.shade50
                      : Colors.red.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: _testSuccess == true ? Colors.green : Colors.red,
                  ),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      _testSuccess == true ? Icons.check_circle : Icons.error,
                      size: 18,
                      color: _testSuccess == true ? Colors.green : Colors.red,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _testResult!,
                        style: TextStyle(
                          fontSize: 12,
                          color: _testSuccess == true
                              ? Colors.green.shade900
                              : Colors.red.shade900,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _save,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppConstants.primaryGreen,
            foregroundColor: Colors.white,
          ),
          child: const Text('Save & Apply'),
        ),
      ],
    );
  }
}
