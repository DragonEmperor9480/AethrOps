import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../screens/splash_screen.dart';

class AWSConfigDialog extends StatefulWidget {
  const AWSConfigDialog({super.key});

  @override
  State<AWSConfigDialog> createState() => _AWSConfigDialogState();
}

class _AWSConfigDialogState extends State<AWSConfigDialog> {
  final _accessKeyController = TextEditingController();
  final _secretKeyController = TextEditingController();
  final _regionController = TextEditingController(text: 'us-east-1');
  bool _loading = false;
  bool _obscureSecret = true;

  Future<void> _configureAWS() async {
    if (_accessKeyController.text.isEmpty ||
        _secretKeyController.text.isEmpty ||
        _regionController.text.isEmpty) {
      _showError('Please fill in all fields');
      return;
    }

    setState(() => _loading = true);
    try {
      await ApiService.configureAWS(
        _accessKeyController.text,
        _secretKeyController.text,
        _regionController.text,
      );

      if (mounted) {
        // Close dialog and navigate to splash screen to reload backend
        Navigator.of(context).pop(true);

        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (_) => SplashScreen(
              isReload: true,
              accessKey: _accessKeyController.text,
              secretKey: _secretKeyController.text,
              region: _regionController.text,
            ),
          ),
        );
      }
    } catch (e) {
      _showError('Failed to configure AWS: $e');
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Row(
        children: [
          Icon(Icons.cloud, color: Colors.orange),
          SizedBox(width: 8),
          Text('Configure AWS Credentials'),
        ],
      ),
      content: SizedBox(
        width: 400,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Enter your AWS credentials to access AWS services.',
              style: TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _accessKeyController,
              decoration: const InputDecoration(
                labelText: 'Access Key ID',
                hintText: 'AKIAIOSFODNN7EXAMPLE',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.key),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _secretKeyController,
              obscureText: _obscureSecret,
              decoration: InputDecoration(
                labelText: 'Secret Access Key',
                hintText: 'wJalrXUtnFEMI/K7MDENG/bPxRfiCYEXAMPLEKEY',
                border: const OutlineInputBorder(),
                prefixIcon: const Icon(Icons.lock),
                suffixIcon: IconButton(
                  icon: Icon(
                    _obscureSecret ? Icons.visibility : Icons.visibility_off,
                  ),
                  onPressed: () =>
                      setState(() => _obscureSecret = !_obscureSecret),
                ),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _regionController,
              decoration: const InputDecoration(
                labelText: 'Region',
                hintText: 'us-east-1',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.public),
              ),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.blue.shade200),
              ),
              child: const Row(
                children: [
                  Icon(Icons.info, color: Colors.blue, size: 20),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Your credentials are stored securely in ~/.awsmgr/credentials',
                      style: TextStyle(fontSize: 12, color: Colors.blue),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _loading ? null : () => Navigator.of(context).pop(false),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _loading ? null : _configureAWS,
          child: _loading
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Configure'),
        ),
      ],
    );
  }

  @override
  void dispose() {
    _accessKeyController.dispose();
    _secretKeyController.dispose();
    _regionController.dispose();
    super.dispose();
  }
}
