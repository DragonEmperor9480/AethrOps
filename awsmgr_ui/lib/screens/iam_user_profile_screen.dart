import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../widgets/loading_animation.dart';
import '../theme/app_theme.dart';

class IAMUserProfileScreen extends StatefulWidget {
  final Map<String, dynamic> user;

  const IAMUserProfileScreen({super.key, required this.user});

  @override
  State<IAMUserProfileScreen> createState() => _IAMUserProfileScreenState();
}

class _IAMUserProfileScreenState extends State<IAMUserProfileScreen> {
  Map<String, dynamic>? _dependencies;
  List<dynamic> _groups = [];
  bool _loading = true;

  // Expansion states for collapsible sections
  bool _groupsExpanded = false;
  bool _accessKeysExpanded = false;
  bool _managedPoliciesExpanded = false;
  bool _inlinePoliciesExpanded = false;

  @override
  void initState() {
    super.initState();
    _loadUserDetails();
  }

  Future<void> _loadUserDetails() async {
    if (!mounted) return;
    setState(() => _loading = true);
    try {
      final username = widget.user['username'];
      final deps = await ApiService.checkUserDependencies(username);
      final groups = await ApiService.getUserGroups(username);

      if (!mounted) return;
      setState(() {
        _dependencies = deps;
        _groups = groups;
      });
    } catch (e) {
      if (mounted) {
        _showError('Failed to load user details: $e');
      }
    } finally {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.error, color: Colors.white),
            const SizedBox(width: 8),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _showSuccess(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle, color: Colors.white),
            const SizedBox(width: 8),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: Colors.green,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _showAttachPoliciesDialog() async {
    final username = widget.user['username'];

    // Get currently attached policy names (not ARNs)
    final currentPolicyNames =
        (_dependencies?['managed_policies'] as List?)
            ?.map((p) => p.toString())
            .toList() ??
        [];

    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => AttachPoliciesDialog(
        username: username,
        currentPolicyNames: currentPolicyNames,
      ),
    );

    if (result != null) {
      final selectedArns = result['selected_arns'] as List<String>;
      final currentArns = result['current_arns'] as List<String>;

      if (!mounted) return;
      setState(() => _loading = true);
      try {
        final response = await ApiService.syncUserPolicies(
          username,
          selectedArns,
          currentArns,
        );

        final attachedCount = response['attached_count'] ?? 0;
        final detachedCount = response['detached_count'] ?? 0;
        final success = response['success'] ?? false;

        if (mounted) {
          if (success) {
            if (attachedCount > 0 && detachedCount > 0) {
              _showSuccess(
                'Attached $attachedCount, detached $detachedCount ${attachedCount + detachedCount == 1 ? 'policy' : 'policies'}',
              );
            } else if (attachedCount > 0) {
              _showSuccess(
                'Attached $attachedCount ${attachedCount == 1 ? 'policy' : 'policies'}',
              );
            } else if (detachedCount > 0) {
              _showSuccess(
                'Detached $detachedCount ${detachedCount == 1 ? 'policy' : 'policies'}',
              );
            } else {
              _showSuccess('No changes needed');
            }
          } else {
            _showError('Some operations failed. Check details.');
          }
        }

        await _loadUserDetails();
      } catch (e) {
        if (mounted) {
          _showError('Failed to sync policies: $e');
        }
      } finally {
        if (!mounted) return;
        setState(() => _loading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final username = widget.user['username'] ?? '';
    final userId = widget.user['user_id'] ?? '';
    final createDate = widget.user['create_date'] ?? '';

    return Scaffold(
      appBar: AppBar(title: Text(username), elevation: 0),
      body: _loading
          ? const LoadingAnimation(message: 'Loading user details...')
          : SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // User Header
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Colors.blue.shade400, Colors.blue.shade600],
                      ),
                    ),
                    child: Column(
                      children: [
                        Container(
                          width: 80,
                          height: 80,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(40),
                          ),
                          child: Icon(
                            Icons.person,
                            size: 48,
                            color: Colors.blue.shade600,
                          ),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          username,
                          style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            'IAM User',
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.9),
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  // User Info Section
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildSectionTitle('User Information'),
                        const SizedBox(height: 12),
                        _buildInfoCard([
                          _buildInfoRow(Icons.fingerprint, 'User ID', userId),
                          _buildInfoRow(
                            Icons.calendar_today,
                            'Created',
                            createDate,
                          ),
                          _buildInfoRow(
                            Icons.login,
                            'Login Profile',
                            _dependencies?['has_login_profile'] == true
                                ? 'Enabled'
                                : 'Disabled',
                            valueColor:
                                _dependencies?['has_login_profile'] == true
                                ? Colors.green
                                : Colors.grey,
                          ),
                        ]),

                        const SizedBox(height: 24),

                        // Groups Section
                        _buildCollapsibleSection(
                          title: 'Groups',
                          count: _groups.length,
                          icon: Icons.group,
                          isExpanded: _groupsExpanded,
                          onToggle: () => setState(
                            () => _groupsExpanded = !_groupsExpanded,
                          ),
                          emptyIcon: Icons.group_outlined,
                          emptyMessage: 'Not a member of any groups',
                          isEmpty: _groups.isEmpty,
                          child: _groups.isEmpty
                              ? null
                              : Column(
                                  children: _groups.map<Widget>((group) {
                                    return _buildListItem(
                                      Icons.group,
                                      group.toString(),
                                    );
                                  }).toList(),
                                ),
                        ),

                        const SizedBox(height: 16),

                        // Access Keys Section
                        _buildCollapsibleSection(
                          title: 'Access Keys',
                          count:
                              (_dependencies?['access_keys'] as List?)
                                  ?.length ??
                              0,
                          icon: Icons.vpn_key,
                          isExpanded: _accessKeysExpanded,
                          onToggle: () => setState(
                            () => _accessKeysExpanded = !_accessKeysExpanded,
                          ),
                          emptyIcon: Icons.vpn_key_outlined,
                          emptyMessage: 'No access keys',
                          isEmpty:
                              (_dependencies?['access_keys'] as List?)
                                  ?.isEmpty ??
                              true,
                          child:
                              (_dependencies?['access_keys'] as List?)
                                      ?.isEmpty ??
                                  true
                              ? null
                              : Column(
                                  children:
                                      (_dependencies!['access_keys'] as List)
                                          .map<Widget>((key) {
                                            return _buildListItem(
                                              Icons.vpn_key,
                                              key.toString(),
                                            );
                                          })
                                          .toList(),
                                ),
                        ),

                        const SizedBox(height: 16),

                        // Managed Policies Section
                        _buildCollapsibleSection(
                          title: 'Managed Policies',
                          count:
                              (_dependencies?['managed_policies'] as List?)
                                  ?.length ??
                              0,
                          icon: Icons.policy,
                          isExpanded: _managedPoliciesExpanded,
                          onToggle: () => setState(
                            () => _managedPoliciesExpanded =
                                !_managedPoliciesExpanded,
                          ),
                          emptyIcon: Icons.policy_outlined,
                          emptyMessage: 'No managed policies attached',
                          isEmpty:
                              (_dependencies?['managed_policies'] as List?)
                                  ?.isEmpty ??
                              true,
                          hasAction: true,
                          actionIcon: Icons.add,
                          actionLabel: 'Attach',
                          onAction: _showAttachPoliciesDialog,
                          child:
                              (_dependencies?['managed_policies'] as List?)
                                      ?.isEmpty ??
                                  true
                              ? null
                              : Column(
                                  children:
                                      (_dependencies!['managed_policies']
                                              as List)
                                          .map<Widget>((policy) {
                                            return _buildListItem(
                                              Icons.policy,
                                              policy.toString(),
                                            );
                                          })
                                          .toList(),
                                ),
                        ),

                        const SizedBox(height: 16),

                        // Inline Policies Section
                        _buildCollapsibleSection(
                          title: 'Inline Policies',
                          count:
                              (_dependencies?['inline_policies'] as List?)
                                  ?.length ??
                              0,
                          icon: Icons.description,
                          isExpanded: _inlinePoliciesExpanded,
                          onToggle: () => setState(
                            () => _inlinePoliciesExpanded =
                                !_inlinePoliciesExpanded,
                          ),
                          emptyIcon: Icons.description_outlined,
                          emptyMessage: 'No inline policies',
                          isEmpty:
                              (_dependencies?['inline_policies'] as List?)
                                  ?.isEmpty ??
                              true,
                          child:
                              (_dependencies?['inline_policies'] as List?)
                                      ?.isEmpty ??
                                  true
                              ? null
                              : Column(
                                  children:
                                      (_dependencies!['inline_policies']
                                              as List)
                                          .map<Widget>((policy) {
                                            return _buildListItem(
                                              Icons.description,
                                              policy.toString(),
                                            );
                                          })
                                          .toList(),
                                ),
                        ),

                        const SizedBox(height: 24),
                      ],
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
    );
  }

  Widget _buildCollapsibleSection({
    required String title,
    required int count,
    required IconData icon,
    required bool isExpanded,
    required VoidCallback onToggle,
    required IconData emptyIcon,
    required String emptyMessage,
    required bool isEmpty,
    Widget? child,
    bool hasAction = false,
    IconData? actionIcon,
    String? actionLabel,
    VoidCallback? onAction,
  }) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Column(
        children: [
          InkWell(
            onTap: isEmpty ? null : onToggle,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: isDark
                          ? AppTheme.primaryBlue.withValues(alpha: 0.2)
                          : Colors.blue.shade50,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      icon,
                      size: 20,
                      color: isDark
                          ? AppTheme.primaryBlue
                          : Colors.blue.shade700,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        Text(
                          '$count ${count == 1 ? 'item' : 'items'}',
                          style: TextStyle(
                            fontSize: 12,
                            color: theme.textTheme.bodyMedium?.color,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (hasAction && onAction != null && !isEmpty)
                    IconButton(
                      icon: Icon(actionIcon ?? Icons.add, size: 18),
                      tooltip: actionLabel,
                      onPressed: onAction,
                      style: IconButton.styleFrom(
                        backgroundColor: isDark
                            ? AppTheme.primaryBlue.withValues(alpha: 0.2)
                            : Colors.blue.shade50,
                        foregroundColor: isDark
                            ? AppTheme.primaryBlue
                            : Colors.blue.shade700,
                      ),
                    ),
                  if (hasAction && onAction != null && !isEmpty)
                    const SizedBox(width: 8),
                  if (!isEmpty)
                    Icon(
                      isExpanded ? Icons.expand_less : Icons.expand_more,
                      color: theme.textTheme.bodyMedium?.color,
                    ),
                ],
              ),
            ),
          ),
          if (isEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: isDark
                      ? theme.cardColor.withValues(alpha: 0.5)
                      : Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  children: [
                    Icon(
                      emptyIcon,
                      size: 36,
                      color: theme.textTheme.bodyMedium?.color?.withValues(
                        alpha: 0.5,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      emptyMessage,
                      style: TextStyle(
                        color: theme.textTheme.bodyMedium?.color,
                        fontSize: 13,
                      ),
                    ),
                    if (hasAction && onAction != null)
                      const SizedBox(height: 12),
                    if (hasAction && onAction != null)
                      TextButton.icon(
                        onPressed: onAction,
                        icon: Icon(actionIcon ?? Icons.add, size: 16),
                        label: Text(actionLabel ?? 'Add'),
                        style: TextButton.styleFrom(
                          foregroundColor: Colors.blue,
                        ),
                      ),
                  ],
                ),
              ),
            )
          else if (isExpanded && child != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: child,
            ),
        ],
      ),
    );
  }

  Widget _buildInfoCard(List<Widget> children) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(children: children),
      ),
    );
  }

  Widget _buildInfoRow(
    IconData icon,
    String label,
    String value, {
    Color? valueColor,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Icon(icon, size: 20, color: Colors.grey[600]),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: valueColor,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildListItem(IconData icon, String title, {String? subtitle}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.blue.shade50,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, size: 20, color: Colors.blue.shade700),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(IconData icon, String message) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Center(
          child: Column(
            children: [
              Icon(icon, size: 48, color: Colors.grey[300]),
              const SizedBox(height: 12),
              Text(
                message,
                style: TextStyle(color: Colors.grey[600], fontSize: 14),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// Attach Policies Dialog
class AttachPoliciesDialog extends StatefulWidget {
  final String username;
  final List<String> currentPolicyNames;

  const AttachPoliciesDialog({
    super.key,
    required this.username,
    this.currentPolicyNames = const [],
  });

  @override
  State<AttachPoliciesDialog> createState() => _AttachPoliciesDialogState();
}

class _AttachPoliciesDialogState extends State<AttachPoliciesDialog> {
  List<dynamic> _policies = [];
  List<dynamic> _filteredPolicies = [];
  final Set<String> _selectedPolicyArns = {};
  final Set<String> _attachedPolicyNames = {};
  final List<String> _currentPolicyArns = [];
  bool _loading = true;
  String _searchQuery = '';
  String _scopeFilter = 'All';

  @override
  void initState() {
    super.initState();
    // Store currently attached policy names
    _attachedPolicyNames.addAll(widget.currentPolicyNames);
    _loadPolicies();
  }

  Future<void> _loadPolicies() async {
    setState(() => _loading = true);
    try {
      final policies = await ApiService.listIAMPolicies(scope: _scopeFilter);
      setState(() {
        _policies = policies;

        // Pre-select policies that are already attached (match by name)
        // Also build the current ARNs list
        _currentPolicyArns.clear();
        for (var policy in _policies) {
          final policyName = policy['policy_name']?.toString() ?? '';
          final policyArn = policy['policy_arn']?.toString() ?? '';
          if (_attachedPolicyNames.contains(policyName)) {
            _selectedPolicyArns.add(policyArn);
            _currentPolicyArns.add(policyArn);
          }
        }

        _filterPolicies();
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to load policies: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      setState(() => _loading = false);
    }
  }

  void _filterPolicies() {
    setState(() {
      _filteredPolicies = _policies.where((policy) {
        final policyName = (policy['policy_name'] ?? '')
            .toString()
            .toLowerCase();
        final policyArn = (policy['policy_arn'] ?? '').toString().toLowerCase();
        final query = _searchQuery.toLowerCase();
        return policyName.contains(query) || policyArn.contains(query);
      }).toList();

      // Sort: attached policies first, then by name
      _filteredPolicies.sort((a, b) {
        final aName = (a['policy_name'] ?? '').toString();
        final bName = (b['policy_name'] ?? '').toString();
        final aAttached = _attachedPolicyNames.contains(aName);
        final bAttached = _attachedPolicyNames.contains(bName);

        // If one is attached and the other isn't, attached comes first
        if (aAttached && !bAttached) return -1;
        if (!aAttached && bAttached) return 1;

        // Otherwise sort by policy name
        return aName.compareTo(bName);
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        width: 700,
        height: 600,
        child: Column(
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(16),
                  topRight: Radius.circular(16),
                ),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.blue,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.policy, color: Colors.white),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Attach Policies',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          'Select policies to attach to ${widget.username}',
                          style: const TextStyle(
                            fontSize: 12,
                            color: Colors.black54,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),

            // Search and Filter
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  TextField(
                    decoration: InputDecoration(
                      hintText: 'Search policies...',
                      prefixIcon: const Icon(Icons.search),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      isDense: true,
                    ),
                    onChanged: (value) {
                      _searchQuery = value;
                      _filterPolicies();
                    },
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      const Text(
                        'Scope: ',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(width: 8),
                      SegmentedButton<String>(
                        segments: const [
                          ButtonSegment(value: 'All', label: Text('All')),
                          ButtonSegment(value: 'AWS', label: Text('AWS')),
                          ButtonSegment(value: 'Local', label: Text('Custom')),
                        ],
                        selected: {_scopeFilter},
                        onSelectionChanged: (Set<String> selected) {
                          setState(() => _scopeFilter = selected.first);
                          _loadPolicies();
                        },
                      ),
                      const Spacer(),
                      Text(
                        '${_selectedPolicyArns.length} selected',
                        style: TextStyle(
                          color: Colors.grey[600],
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // Policies List
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : _filteredPolicies.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.policy_outlined,
                            size: 64,
                            color: Colors.grey[300],
                          ),
                          const SizedBox(height: 16),
                          Text(
                            _searchQuery.isEmpty
                                ? 'No policies found'
                                : 'No matching policies',
                            style: TextStyle(color: Colors.grey[600]),
                          ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      itemCount: _filteredPolicies.length,
                      itemBuilder: (context, index) {
                        final policy = _filteredPolicies[index];
                        final policyArn =
                            policy['policy_arn']?.toString() ?? '';
                        final policyName =
                            policy['policy_name']?.toString() ?? '';
                        final isAWSManaged = policy['is_aws_managed'] == true;
                        final isSelected = _selectedPolicyArns.contains(
                          policyArn,
                        );
                        final isAlreadyAttached = _attachedPolicyNames.contains(
                          policyName,
                        );

                        return Card(
                          margin: const EdgeInsets.only(bottom: 8),
                          color: isSelected ? Colors.blue.shade50 : null,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                            side: isSelected
                                ? BorderSide(color: Colors.blue, width: 2)
                                : BorderSide.none,
                          ),
                          child: CheckboxListTile(
                            value: isSelected,
                            onChanged: (value) {
                              setState(() {
                                if (value == true) {
                                  _selectedPolicyArns.add(policyArn);
                                } else {
                                  _selectedPolicyArns.remove(policyArn);
                                }
                              });
                            },
                            title: Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    policyName,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w500,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                if (isAlreadyAttached)
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 6,
                                      vertical: 2,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Colors.green.shade100,
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Text(
                                      'Attached',
                                      style: TextStyle(
                                        fontSize: 9,
                                        color: Colors.green.shade900,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                if (isAWSManaged) ...[
                                  const SizedBox(width: 4),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 6,
                                      vertical: 2,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Colors.orange.shade100,
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Text(
                                      'AWS',
                                      style: TextStyle(
                                        fontSize: 9,
                                        color: Colors.orange.shade900,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                            subtitle: Text(
                              policyArn,
                              style: TextStyle(
                                fontSize: 11,
                                color: Colors.grey[600],
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            dense: true,
                          ),
                        );
                      },
                    ),
            ),

            // Footer
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                border: Border(top: BorderSide(color: Colors.grey.shade200)),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Cancel'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    flex: 2,
                    child: ElevatedButton.icon(
                      onPressed: () {
                        Navigator.pop(context, {
                          'selected_arns': _selectedPolicyArns.toList(),
                          'current_arns': _currentPolicyArns,
                        });
                      },
                      icon: const Icon(Icons.sync, size: 18),
                      label: Text('Apply (${_selectedPolicyArns.length})'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue,
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
