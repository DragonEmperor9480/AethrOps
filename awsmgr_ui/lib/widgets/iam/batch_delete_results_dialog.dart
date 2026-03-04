import 'package:flutter/material.dart';

/// Dialog displaying results of a batch IAM user deletion operation.
class BatchDeleteResultsDialog extends StatelessWidget {
  final int successCount;
  final int failureCount;
  final List results;

  const BatchDeleteResultsDialog({
    super.key,
    required this.successCount,
    required this.failureCount,
    required this.results,
  });

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Row(
        children: [
          Icon(
            failureCount == 0 ? Icons.check_circle : Icons.info,
            color: failureCount == 0 ? Colors.green : Colors.orange,
          ),
          const SizedBox(width: 8),
          const Text('Batch Deletion Results'),
        ],
      ),
      content: SizedBox(
        width: 500,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Summary
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildStat('Total', results.length, Colors.blue),
                  _buildStat('Deleted', successCount, Colors.green),
                  if (failureCount > 0)
                    _buildStat('Failed', failureCount, Colors.red),
                ],
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Details:',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            // Results list
            Flexible(
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: results.length,
                itemBuilder: (context, index) {
                  final result = results[index];
                  final success = result['Success'] ?? false;
                  final username = result['Username'] ?? '';
                  final error = result['Error'] ?? '';

                  return ListTile(
                    dense: true,
                    leading: Icon(
                      success ? Icons.check_circle : Icons.error,
                      color: success ? Colors.green : Colors.red,
                      size: 20,
                    ),
                    title: Text(username),
                    subtitle: !success
                        ? Text(error, style: const TextStyle(fontSize: 12))
                        : null,
                  );
                },
              ),
            ),
          ],
        ),
      ),
      actions: [
        ElevatedButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Close'),
        ),
      ],
    );
  }

  Widget _buildStat(String label, int value, Color color) {
    return Column(
      children: [
        Text(
          value.toString(),
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        Text(
          label,
          style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
        ),
      ],
    );
  }
}
