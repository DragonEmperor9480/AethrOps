import 'package:flutter/material.dart';

/// Dialog for confirming batch deletion of IAM users, showing their dependencies.
class BatchDeleteConfirmationDialog extends StatelessWidget {
  final List<dynamic> dependencies;

  const BatchDeleteConfirmationDialog({super.key, required this.dependencies});

  @override
  Widget build(BuildContext context) {
    // Count users with dependencies
    int usersWithDeps = 0;
    for (var dep in dependencies) {
      final deps = dep['dependencies'];
      if (deps != null) {
        final hasDeps =
            (deps['groups'] as List?)?.isNotEmpty == true ||
            (deps['managed_policies'] as List?)?.isNotEmpty == true ||
            (deps['inline_policies'] as List?)?.isNotEmpty == true ||
            (deps['access_keys'] as List?)?.isNotEmpty == true ||
            deps['has_login_profile'] == true;
        if (hasDeps) usersWithDeps++;
      }
    }

    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Row(
        children: [
          Icon(
            usersWithDeps > 0 ? Icons.warning : Icons.delete,
            color: usersWithDeps > 0 ? Colors.orange : Colors.red,
          ),
          const SizedBox(width: 8),
          const Text('Confirm Batch Delete'),
        ],
      ),
      content: SizedBox(
        width: 600,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'You are about to delete ${dependencies.length} user(s).',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              if (usersWithDeps > 0) ...[
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.orange.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.orange.shade200),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(
                            Icons.info,
                            color: Colors.orange,
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            '$usersWithDeps user(s) have dependencies',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.orange,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'All dependencies will be automatically removed before deletion.',
                        style: TextStyle(fontSize: 12),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Users with dependencies:',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                ...dependencies
                    .where((dep) {
                      final deps = dep['dependencies'];
                      if (deps == null) return false;
                      return (deps['groups'] as List?)?.isNotEmpty == true ||
                          (deps['managed_policies'] as List?)?.isNotEmpty ==
                              true ||
                          (deps['inline_policies'] as List?)?.isNotEmpty ==
                              true ||
                          (deps['access_keys'] as List?)?.isNotEmpty == true ||
                          deps['has_login_profile'] == true;
                    })
                    .map((dep) {
                      final username = dep['username'];
                      final deps = dep['dependencies'];
                      return ExpansionTile(
                        dense: true,
                        title: Text(
                          username,
                          style: const TextStyle(fontSize: 14),
                        ),
                        children: [
                          Padding(
                            padding: const EdgeInsets.only(left: 16, bottom: 8),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                if ((deps['groups'] as List?)?.isNotEmpty ==
                                    true)
                                  _buildDepList('Groups', deps['groups']),
                                if ((deps['managed_policies'] as List?)
                                        ?.isNotEmpty ==
                                    true)
                                  _buildDepList(
                                    'Policies',
                                    deps['managed_policies'],
                                  ),
                                if ((deps['inline_policies'] as List?)
                                        ?.isNotEmpty ==
                                    true)
                                  _buildDepList(
                                    'Inline Policies',
                                    deps['inline_policies'],
                                  ),
                                if ((deps['access_keys'] as List?)
                                        ?.isNotEmpty ==
                                    true)
                                  _buildDepList(
                                    'Access Keys',
                                    deps['access_keys'],
                                  ),
                                if (deps['has_login_profile'] == true)
                                  const Text(
                                    '• Has login profile',
                                    style: TextStyle(fontSize: 12),
                                  ),
                              ],
                            ),
                          ),
                        ],
                      );
                    }),
              ],
              const SizedBox(height: 16),
              const Text(
                'This action cannot be undone.',
                style: TextStyle(
                  color: Colors.red,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('Cancel'),
        ),
        ElevatedButton.icon(
          onPressed: () => Navigator.pop(context, true),
          icon: const Icon(Icons.delete),
          label: const Text('Delete All'),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.red,
            foregroundColor: Colors.white,
          ),
        ),
      ],
    );
  }

  Widget _buildDepList(String title, List items) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '$title:',
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
          ),
          ...items.map(
            (item) => Text('  • $item', style: const TextStyle(fontSize: 11)),
          ),
        ],
      ),
    );
  }
}
